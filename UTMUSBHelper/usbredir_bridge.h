//
// C bridge between the privileged daemon (Swift) and libusbredirhost.
//
// Why C and not Swift: usbredirhost is a callback API over a
// `libusb_device_handle`, and the whole pump loop (poll on the socket +
// libusb_handle_events) has already been verified live in this shape —
// rewriting it in Swift would put risk back into the one part we know
// works.
//
// Vincolo verificato sul campo (§ memoria macos-usb-passthrough-constraints):
// serve root. Come utente normale libusb rifiuta la claim con
// "USB device capture requires either an entitlement
// (com.apple.vm.device-access) or root privilege". Questo bridge quindi
// gira SOLO dentro il LaunchDaemon.
//

#ifndef USBREDIR_BRIDGE_H
#define USBREDIR_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct usbredir_session usbredir_session;

/// Callback invocata quando la redirezione termina da sé — cioè quando il
/// lato guest (QEMU) chiude il socket: VM fermata, VM crashata, o QEMU
/// ucciso. NON viene invocata per una chiusura richiesta via
/// `usbredir_stop()`.
///
/// ATTENZIONE: viene chiamata DAL THREAD DI PUMP. Il chiamante non deve
/// invocare `usbredir_stop()` in modo sincrono da qui (si auto-attenderebbe):
/// va sempre rimandata su un'altra coda.
typedef void (*usbredir_closed_cb)(void *user_ctx);

/// Apre il device `vid:pid`, si connette al socket Unix dove QEMU è in
/// ascolto (`-chardev socket,server=on,wait=off`), fa la claim delle
/// interfacce ed esporta il device verso il guest. Ritorna immediatamente:
/// il traffico viene pompato su un thread dedicato.
///
/// IMPORTANTE: per i dispositivi di archiviazione il volume deve essere
/// GIÀ stato smontato con successo dal chiamante prima di invocare questa
/// funzione — mai in parallelo, mai dopo.
///
/// Ritorna NULL in caso di errore, scrivendo il messaggio in `err_buf`.
usbredir_session *usbredir_start(uint16_t vid,
                                 uint16_t pid,
                                 const char *socket_path,
                                 usbredir_closed_cb on_closed,
                                 void *user_ctx,
                                 char *err_buf,
                                 size_t err_len);

/// Ferma la redirezione e restituisce il device al sistema.
///
/// Non si limita a rilasciare le interfacce: forza anche una
/// re-enumerazione USB (`libusb_reset_device`). Senza quel reset macOS NON
/// ri-sonda il device e non riattacca il proprio driver — verificato dal
/// vivo: il disco resta enumerato via USB ma senza block device, con
/// `diskutil list` che si pianta, e l'unico rimedio sarebbe staccare il
/// cavo. È la differenza fra un distacco pulito e lasciare all'utente un
/// disco appeso.
///
/// Idempotente e sicura anche se la sessione è già terminata da sé.
void usbredir_stop(usbredir_session *session);

/// True (non-zero) se il thread di pump è ancora attivo.
int usbredir_is_active(usbredir_session *session);

#ifdef __cplusplus
}
#endif

#endif /* USBREDIR_BRIDGE_H */
