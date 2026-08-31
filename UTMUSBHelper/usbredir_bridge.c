//
// Implementazione del bridge usbredir (§ usbredir_bridge.h).
//
// Struttura derivata direttamente dal prototipo verificato dal vivo: la
// sequenza open -> connect -> usbredirhost_open -> pump -> release+reset è
// quella che ha superato la prova sul campo, qui riorganizzata attorno a un
// thread dedicato per non bloccare il demone.
//
// Disciplina di threading: TUTTE le chiamate a usbredirhost avvengono sul
// thread di pump, inclusa la chiusura. `usbredir_stop()` si limita ad
// alzare un flag e ad attendere il thread. Così non serve alcun lock su
// usbredirhost (che è solo parzialmente thread-safe) e non esistono
// chiamate concorrenti su di esso.
//

#include "usbredir_bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/un.h>

#include <libusb.h>
#include <usbredirhost.h>

// Causa REALE del fallimento più comune, verificata dal log di sistema — e
// NON è "manca root", come diceva questo messaggio in origine.
//
// Prendere possesso di un'interfaccia USB di un dispositivo di archiviazione
// passa dal gate sandbox `iokit-open-service IOUSBHostInterface`, che a sua
// volta consulta TCC sul servizio kTCCServiceSystemPolicyRemovableVolumes.
// Con il demone (root, non sandboxato) il kernel logga:
//
//     System Policy: UTMUSBHelper(N) deny(1)
//                    iokit-open-service IOUSBHostInterface
//
// e tccd, nella stessa finestra temporale:
//
//     CREDENTIAL_AUDIT_TOKEN={pid:N, auid:-1, euid:0}
//     REPLY: XPCErrorDescription="Connection invalid"
//
// `auid:-1` è la chiave: un LaunchDaemon non appartiene ad alcuna sessione
// utente, quindi tccd non ha un agente a cui inoltrare la richiesta, la
// valutazione fallisce in partenza e la sandbox nega. Il prototipo CLI
// riusciva perché lanciato con sudo DA UN TERMINALE: lì il processo
// responsabile era Terminal.app (auid=501, già autorizzato e con
// com.apple.private.tcc.allow-prompting), e TCC rispondeva authValue=2.
//
// Conseguenza pratica: root è necessario ma NON sufficiente. Serve una
// concessione TCC registrata per QUESTO binario, che essendo senza sessione
// non può essere richiesta con un prompt — va concessa a mano una volta.
//
// Nota sul sintomo: negato il gate, libusb non riesce nemmeno a costruire il
// plugin IOKit del device, che quindi sparisce dalla sua enumerazione. Il
// fallimento si manifesta perciò come LIBUSB_ERROR_NO_DEVICE ("No such
// device") su un dispositivo perfettamente collegato e visibile in Finder —
// sintomo fuorviante che ha senso solo conoscendo la catena qui sopra.
// Il worker gira nella sessione dell'utente proprio perché questa
// autorizzazione possa essere chiesta con la normale finestra di sistema
// (§ USBRedirWorker.swift); il ripiego manuale resta indicato per il caso
// in cui il prompt non compaia o sia stato rifiutato in passato.
static const char *const kTccHint =
    "autorizzazione ai volumi rimovibili negata. Consenti l'accesso quando "
    "macOS lo chiede; se la richiesta non compare o l'hai già rifiutata, "
    "aggiungi UTM.app/Contents/Library/LaunchDaemons/UTMUSBHelper "
    "in Impostazioni di Sistema > Privacy e sicurezza > Accesso completo al "
    "disco (root da solo non basta)";

struct usbredir_session {
    libusb_context *ctx;
    struct usbredirhost *host;
    int sock_fd;
    uint16_t vid;
    uint16_t pid;

    pthread_t thread;
    volatile int stop_requested;   // alzato da usbredir_stop()
    volatile int running;          // 0 quando il thread è uscito
    int peer_closed;               // il guest ha chiuso -> notifica

    usbredir_closed_cb on_closed;
    void *user_ctx;
};

// ---------------------------------------------------------------- callbacks

static void log_cb(void *priv, int level, const char *msg) {
    (void)priv;
    // Solo errori e warning: il resto è troppo verboso per il log di sistema.
    if (level <= usbredirparser_warning) {
        fprintf(stderr, "usbredir: %s\n", msg);
    }
}

static int read_cb(void *priv, uint8_t *data, int count) {
    usbredir_session *s = (usbredir_session *)priv;
    ssize_t r = read(s->sock_fd, data, (size_t)count);
    if (r < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) return 0;
        return -1;
    }
    if (r == 0) {          // EOF: QEMU ha chiuso (VM fermata o crashata)
        s->peer_closed = 1;
        return -1;
    }
    return (int)r;
}

static int write_cb(void *priv, uint8_t *data, int count) {
    usbredir_session *s = (usbredir_session *)priv;
    ssize_t r = write(s->sock_fd, data, (size_t)count);
    if (r < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) return 0;
        return -1;
    }
    return (int)r;
}

// ------------------------------------------------------------- pump thread

/// Forza una re-enumerazione USB del device, così macOS lo ri-sonda e
/// riattacca il proprio driver.
///
/// Va invocata SEMPRE che si sia toccato il device, **anche quando la claim
/// è FALLITA**: verificato dal vivo che un tentativo di detach del driver
/// kernel andato male lascia comunque il device in uno stato monco —
/// enumerato via USB ma senza block device, con `diskutil` che si pianta e
/// l'utente costretto a staccare il cavo. Il costo di un reset di troppo è
/// nullo; il costo di uno mancante è un disco appeso.
static void reenumerate_device(libusb_context *ctx, uint16_t vid, uint16_t pid) {
    if (!ctx) return;
    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, vid, pid);
    if (h) {
        libusb_reset_device(h);   // LIBUSB_ERROR_NOT_FOUND qui è normale
        libusb_close(h);
    }
}

/// Restituisce il device al sistema: rilascio interfacce + re-enumerazione.
/// Eseguito SEMPRE sul thread di pump, sia in uscita normale sia su stop.
static void release_device(usbredir_session *s) {
    if (s->host) {
        usbredirhost_close(s->host);   // rilascia le interfacce e chiude l'handle
        s->host = NULL;
    }
    reenumerate_device(s->ctx, s->vid, s->pid);
}

static void *pump_thread(void *arg) {
    usbredir_session *s = (usbredir_session *)arg;

    while (!s->stop_requested) {
        struct pollfd pfd;
        pfd.fd = s->sock_fd;
        pfd.events = POLLIN;
        if (usbredirhost_has_data_to_write(s->host) > 0) pfd.events |= POLLOUT;
        pfd.revents = 0;

        int pr = poll(&pfd, 1, 50);
        if (pr < 0 && errno != EINTR) break;

        if (pfd.revents & (POLLERR | POLLHUP)) { s->peer_closed = 1; break; }
        if (pfd.revents & POLLIN) {
            if (usbredirhost_read_guest_data(s->host) != 0) break;
        }
        if (pfd.revents & POLLOUT) {
            if (usbredirhost_write_guest_data(s->host) < 0) break;
        }

        // usbredirhost richiede che qualcuno pompi gli eventi libusb
        // (§ nota 2 in usbredirhost.h).
        struct timeval tv = {0, 0};
        libusb_handle_events_timeout(s->ctx, &tv);
    }

    release_device(s);
    if (s->sock_fd >= 0) { close(s->sock_fd); s->sock_fd = -1; }

    int notify = (!s->stop_requested && s->peer_closed && s->on_closed);
    s->running = 0;
    // La notifica va emessa per ULTIMA: da qui in poi la sessione può
    // essere considerata conclusa dal chiamante.
    if (notify) s->on_closed(s->user_ctx);
    return NULL;
}

// -------------------------------------------------------------- public API

usbredir_session *usbredir_start(uint16_t vid,
                                 uint16_t pid,
                                 const char *socket_path,
                                 usbredir_closed_cb on_closed,
                                 void *user_ctx,
                                 char *err_buf,
                                 size_t err_len) {
#define FAIL(...) do { if (err_buf && err_len) snprintf(err_buf, err_len, __VA_ARGS__); goto fail; } while (0)

    usbredir_session *s = calloc(1, sizeof(*s));
    if (!s) { if (err_buf && err_len) snprintf(err_buf, err_len, "memoria esaurita"); return NULL; }
    s->sock_fd = -1;
    s->vid = vid;
    s->pid = pid;
    s->on_closed = on_closed;
    s->user_ctx = user_ctx;

    int rc = libusb_init(&s->ctx);
    if (rc < 0) FAIL("libusb_init: %s", libusb_error_name(rc));

    libusb_device_handle *handle = libusb_open_device_with_vid_pid(s->ctx, vid, pid);
    if (!handle) FAIL("device %04x:%04x non apribile: %s", vid, pid, kTccHint);

    s->sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s->sock_fd < 0) { libusb_close(handle); FAIL("socket(): %s", strerror(errno)); }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(socket_path) >= sizeof(addr.sun_path)) {
        libusb_close(handle);
        FAIL("percorso socket troppo lungo (max %zu byte)", sizeof(addr.sun_path) - 1);
    }
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    if (connect(s->sock_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        libusb_close(handle);
        FAIL("connessione a %s fallita: %s", socket_path, strerror(errno));
    }
    fcntl(s->sock_fd, F_SETFL, O_NONBLOCK);

    // Qui avviene la claim delle interfacce. usbredirhost_open prende
    // possesso di `handle` e lo chiude da sé in caso di errore.
    s->host = usbredirhost_open(s->ctx, handle, log_cb, read_cb, write_cb,
                                s, "UTM", usbredirparser_warning, 0);
    if (!s->host) FAIL("claim delle interfacce negata: %s", kTccHint);

    s->running = 1;
    if (pthread_create(&s->thread, NULL, pump_thread, s) != 0) {
        s->running = 0;
        FAIL("creazione del thread di pump fallita");
    }
    return s;

fail:
    if (s) {
        if (s->host) usbredirhost_close(s->host);
        if (s->sock_fd >= 0) close(s->sock_fd);
        // ANCHE sul fallimento: se siamo arrivati fin qui abbiamo aperto il
        // device e, molto probabilmente, tentato (invano) il detach del
        // driver kernel — che basta a lasciarlo monco. Senza questo reset
        // l'utente si ritrova un disco appeso dopo un attach *fallito*.
        reenumerate_device(s->ctx, vid, pid);
        if (s->ctx) libusb_exit(s->ctx);
        free(s);
    }
    return NULL;
#undef FAIL
}

void usbredir_stop(usbredir_session *s) {
    if (!s) return;
    s->stop_requested = 1;
    pthread_join(s->thread, NULL);   // il rilascio avviene sul thread di pump
    if (s->ctx) { libusb_exit(s->ctx); s->ctx = NULL; }
    free(s);
}

int usbredir_is_active(usbredir_session *s) {
    return s && s->running;
}
