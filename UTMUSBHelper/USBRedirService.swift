//
// The real implementation of the XPC protocol (§ Services/
// UTMUSBHelperProtocol.swift).
//
// The daemon no longer claims the device itself. It delegates that to a
// worker (§ USBRedirWorker.swift) started with `launchctl asuser` inside
// the user's graphical session: still root, but with a real `auid`, which
// is the only way for TCC to show the removable-volume access prompt
// instead of denying in silence. What stays here is XPC ownership, the
// unmount/remount, and the lifetime of the workers.
//
// Order of operations (not negotiable, § the invariant in the protocol):
//   attach:  locate disks -> UNMOUNT (must succeed) -> start worker
//   detach:  stop the worker (release + reset) -> remount
//
// The reset on release is mandatory even when the claim FAILED: verified
// live that a failed kernel-driver detach still leaves the device crippled
// (enumerated on the USB bus but with no block device, `diskutil` hanging,
// cable to be pulled by hand). That reset lives inside usbredir_bridge.c,
// on every exit path.
//

import Foundation
import MachO

/// Una redirezione attiva. `disks` sono i dischi INTERI che abbiamo smontato
/// noi e che dobbiamo rimontare al rilascio — memorizzati all'attach perché
/// dopo il reset gli identificatori BSD possono cambiare e non sarebbero più
/// ricavabili.
private final class RedirectSession {
    let vendorId: Int
    let productId: Int
    let disks: [String]
    /// Il processo `launchctl asuser` che fa da tramite.
    let task: Process
    /// Pid del worker VERO, comunicato da lui stesso all'avvio: è questo che
    /// va segnalato, non `task.processIdentifier`.
    let workerPid: pid_t
    /// Alzato quando siamo NOI a smontare la sessione, così il
    /// terminationHandler non rimonta una seconda volta.
    var didTeardown = false

    init(vendorId: Int, productId: Int, disks: [String], task: Process, workerPid: pid_t) {
        self.vendorId = vendorId
        self.productId = productId
        self.disks = disks
        self.task = task
        self.workerPid = workerPid
    }

    var key: String { USBRedirService.key(vendorId, productId) }
}

/// Esito della stretta di mano iniziale col worker.
private final class HandshakeBox {
    var workerPid: pid_t = 0
    var ok = false
    var message: String?
    var timedOut = false
    let lock = NSLock()
}

final class USBRedirService: NSObject, UTMUSBHelperProtocol {
    /// Chiave = "vvvv:pppp". Protetto da `lock`: le chiamate XPC arrivano su
    /// code diverse e i terminationHandler dei worker su code di sistema.
    private var sessions: [String: RedirectSession] = [:]
    private let lock = NSLock()

    /// Coda per il lavoro di chiusura asincrono (il rimontaggio può
    /// richiedere secondi e non deve trattenere chi ci ha notificati).
    private let teardownQueue = DispatchQueue(label: "com.utmapp.UTMUSBHelper.teardown")

    /// Generoso di proposito: se è la PRIMA volta, dentro questa finestra
    /// c'è l'utente che legge la richiesta di accesso di macOS e decide.
    private static let handshakeTimeout: TimeInterval = 120

    static func key(_ vid: Int, _ pid: Int) -> String {
        String(format: "%04x:%04x", vid, pid)
    }

    // MARK: - Protocollo

    func ping(reply: @escaping (String) -> Void) {
        lock.lock(); let n = sessions.count; lock.unlock()
        reply("UTMUSBHelper v1, pid \(ProcessInfo.processInfo.processIdentifier), \(n) device rediretti")
    }

    func attachDevice(vendorId: Int,
                      productId: Int,
                      socketPath: String,
                      reply: @escaping (Bool, String?) -> Void) {
        let k = Self.key(vendorId, productId)

        lock.lock()
        if sessions[k] != nil {
            lock.unlock()
            reply(false, "Il dispositivo \(k) è già collegato a una VM.")
            return
        }
        lock.unlock()

        guard let consoleUid = Self.consoleUserID() else {
            reply(false, "Nessun utente collegato alla sessione grafica: "
                       + "la redirezione USB non può chiedere l'autorizzazione necessaria.")
            return
        }

        // 1. Individua i dischi ESPOSTI DA QUESTO device (vuoto se non è
        //    un'unità di archiviazione: tastiere, dongle, webcam…).
        let disks = USBDiskLocator.wholeDisks(forVendorId: vendorId, productId: productId)

        // 2. Smonta. DEVE riuscire prima di qualunque claim.
        for disk in disks {
            if let failure = Self.unmountForClaim(disk) {
                reply(false, failure)
                return
            }
        }

        // 3. Avvia il worker nella sessione dell'utente e attendi il suo
        //    verdetto (qui dentro può comparire il prompt di sistema).
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["asuser", "\(consoleUid)",
                          Self.selfExecutablePath,
                          "--worker", "\(vendorId)", "\(productId)", socketPath]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            Self.remount(disks)
            reply(false, "Avvio del processo di redirezione fallito: \(error.localizedDescription)")
            return
        }

        let shake = Self.waitForHandshake(pipe.fileHandleForReading, timeout: Self.handshakeTimeout)

        guard shake.ok else {
            // Fallita: fermiamo il worker e rimettiamo il disco com'era,
            // altrimenti l'utente si ritrova un volume sparito per
            // un'operazione che non è nemmeno riuscita.
            if shake.workerPid > 0 { kill(shake.workerPid, SIGTERM) }
            if task.isRunning { task.terminate() }
            Self.remount(disks)
            let msg: String
            if shake.timedOut {
                msg = "Nessuna risposta dal processo di redirezione entro "
                    + "\(Int(Self.handshakeTimeout)) secondi. Se è comparsa una richiesta "
                    + "di autorizzazione di macOS e non è stata accettata, riprova."
            } else {
                msg = shake.message ?? "Avvio della redirezione fallito."
            }
            reply(false, msg)
            return
        }

        let session = RedirectSession(vendorId: vendorId, productId: productId,
                                      disks: disks, task: task, workerPid: shake.workerPid)
        lock.lock()
        sessions[k] = session
        lock.unlock()

        // Da qui in poi il pipe va tenuto drenato, altrimenti il worker si
        // bloccherebbe a buffer pieno; ne approfittiamo per far confluire il
        // suo output nel log del demone.
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") where !line.isEmpty {
                NSLog("UTMUSBHelper[worker %d]: %@", shake.workerPid, String(line))
            }
        }

        // Uscita spontanea del worker = il guest ha chiuso il socket (VM
        // fermata, VM crashata, QEMU ucciso). È il percorso che garantisce il
        // rimontaggio anche quando nessuno ce lo chiede.
        task.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            guard let self else { return }
            self.lock.lock()
            let known = self.sessions[k]
            let wasOurs = known?.didTeardown ?? true
            if !wasOurs { self.sessions.removeValue(forKey: k) }
            self.lock.unlock()
            guard !wasOurs else { return }
            NSLog("UTMUSBHelper: worker di %@ terminato da sé, rimonto", k)
            self.teardownQueue.async { Self.remount(disks) }
        }

        reply(true, nil)
    }

    func detachDevice(vendorId: Int, productId: Int, reply: @escaping (Bool, String?) -> Void) {
        let k = Self.key(vendorId, productId)
        lock.lock()
        let session = sessions.removeValue(forKey: k)
        session?.didTeardown = true
        lock.unlock()

        guard let session else {
            reply(false, "Il dispositivo \(k) non risulta collegato.")
            return
        }
        Self.teardown(session)
        reply(true, nil)
    }

    func detachAll(reply: @escaping (Bool) -> Void) {
        lock.lock()
        let all = Array(sessions.values)
        all.forEach { $0.didTeardown = true }
        sessions.removeAll()
        lock.unlock()

        for session in all { Self.teardown(session) }
        reply(true)
    }

    func listAttached(reply: @escaping ([String]) -> Void) {
        lock.lock(); let keys = Array(sessions.keys); lock.unlock()
        reply(keys.sorted())
    }

    // MARK: - Chiusura

    /// Rilascio effettivo. SIGTERM fa uscire il worker per la sua via pulita
    /// (rilascio interfacce + re-enumerazione); solo dopo ha senso rimontare,
    /// perché prima del reset il block device non esiste ancora.
    private static func teardown(_ session: RedirectSession) {
        if session.workerPid > 0 { kill(session.workerPid, SIGTERM) }

        var waited = 0.0
        while session.task.isRunning && waited < 15.0 {
            Thread.sleep(forTimeInterval: 0.1)
            waited += 0.1
        }
        if session.task.isRunning {
            // Ultima risorsa: un worker ucciso a freddo NON ha fatto il
            // reset, quindi il device può restare monco fino a che l'utente
            // non stacca il cavo. Va detto nel log, non nascosto.
            NSLog("UTMUSBHelper: worker di %@ non uscito in 15s, lo uccido: "
                  + "il dispositivo potrebbe richiedere il ricollegamento manuale", session.key)
            if session.workerPid > 0 { kill(session.workerPid, SIGKILL) }
            session.task.terminate()
        }
        remount(session.disks)
    }

    // MARK: - Smontaggio

    /// Smonta un disco intero preparandolo alla claim. Ritorna `nil` se ci è
    /// riuscito, altrimenti il messaggio da mostrare all'utente.
    ///
    /// `diskutil unmountDisk` chiede il permesso ai processi che tengono
    /// aperto il volume e accetta il loro veto. Sui dischi grandi il vetante
    /// abituale è l'indicizzazione Spotlight (`mdsync`/`mds_stores`), che da
    /// sé non molla in tempi utili: senza questa gestione il collegamento
    /// resta bloccato per sempre con "Unmount was dissented by…".
    ///
    /// La distinzione che conta, ed è il motivo per cui non si forza e
    /// basta: un vetante di SISTEMA (indicizzatori, fseventsd) non ha dati
    /// dell'utente in bilico, quindi dopo qualche tentativo educato lo si
    /// scavalca; un vetante che è un'APPLICAZIONE dell'utente può avere
    /// scritture non ancora sul disco — lì forzare significherebbe perdere
    /// dati, quindi ci si ferma e si dice quale programma chiudere.
    private static func unmountForClaim(_ disk: String) -> String? {
        let device = "/dev/\(disk)"
        var lastOutput = ""

        for attempt in 0..<3 {
            let result = runProcess("/usr/sbin/diskutil", ["unmountDisk", device])
            if result.status == 0 { return nil }
            lastOutput = result.output

            let dissenters = parseDissenters(result.output)
            if let userApp = dissenters.first(where: { !isSystemProcess($0.path) }) {
                let name = (userApp.path as NSString).lastPathComponent
                return "Smontaggio di \(device) rifiutato da \(name) (PID \(userApp.pid)), "
                     + "che sta usando il disco. Non forzo lo smontaggio per non rischiare "
                     + "la perdita di dati non ancora scritti: chiudi quel programma e riprova."
            }
            if dissenters.isEmpty && attempt == 0 {
                // Fallimento non dovuto a un veto: insistere non serve.
                break
            }
            Thread.sleep(forTimeInterval: 2.0)
        }

        // Restano solo vetanti di sistema (o un fallimento senza veto):
        // ultima risorsa, tracciata nel log perché non sia una decisione
        // invisibile.
        NSLog("UTMUSBHelper: smontaggio educato di %@ non riuscito (%@), forzo",
              device, lastOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        let forced = runProcess("/usr/sbin/diskutil", ["unmountDisk", "force", device])
        if forced.status == 0 { return nil }

        return "Smontaggio di \(device) fallito, non procedo: \(forced.output)"
    }

    /// Estrae i vetanti dall'output di `diskutil`, che li elenca come
    /// "Unmount was dissented by PID 123 (/percorso/del/binario)".
    private static func parseDissenters(_ output: String) -> [(pid: Int, path: String)] {
        let pattern = #"dissented by PID (\d+) \(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return regex.matches(in: output, range: range).compactMap { match in
            guard let pidRange = Range(match.range(at: 1), in: output),
                  let pathRange = Range(match.range(at: 2), in: output),
                  let pid = Int(output[pidRange]) else { return nil }
            return (pid, String(output[pathRange]))
        }
    }

    private static func isSystemProcess(_ path: String) -> Bool {
        ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/bin/"]
            .contains { path.hasPrefix($0) }
    }

    /// Rimontaggio best-effort: dopo il reset macOS ri-sonda il device e
    /// spesso monta da sé, ma l'identificatore BSD può essere cambiato.
    /// Si concede qualche secondo perché la re-enumerazione non è istantanea.
    private static func remount(_ disks: [String]) {
        guard !disks.isEmpty else { return }
        for disk in disks {
            var mounted = false
            for _ in 0..<10 {
                if runProcess("/usr/sbin/diskutil", ["mountDisk", "/dev/\(disk)"]).status == 0 {
                    mounted = true
                    break
                }
                Thread.sleep(forTimeInterval: 1.0)
            }
            if !mounted {
                NSLog("UTMUSBHelper: /dev/%@ non rimontato; macOS potrebbe farlo da sé", disk)
            }
        }
    }

    // MARK: - Avvio del worker

    /// Utente della sessione grafica corrente. `/dev/console` appartiene a
    /// chi ha la console; se è ancora di root non c'è nessuno collegato, e
    /// senza una sessione utente il worker non avrebbe alcun vantaggio
    /// rispetto al demone (§ USBRedirWorker.swift).
    private static func consoleUserID() -> uid_t? {
        var info = stat()
        guard stat("/dev/console", &info) == 0, info.st_uid != 0 else { return nil }
        return info.st_uid
    }

    /// Percorso assoluto di QUESTO binario, da rilanciare in modalità
    /// worker. `CommandLine.arguments[0]` non basta: launchd ci avvia con un
    /// BundleProgram relativo al bundle dell'app.
    private static var selfExecutablePath: String = {
        var size = UInt32(PATH_MAX)
        var buffer = [CChar](repeating: 0, count: Int(size))
        if _NSGetExecutablePath(&buffer, &size) == 0 {
            let path = String(cString: buffer)
            if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
                return resolved
            }
            return (path as NSString).resolvingSymlinksInPath
        }
        return Bundle.main.executablePath ?? CommandLine.arguments[0]
    }()

    /// Legge le righe di protocollo del worker fino a "OK"/"ERR" o alla
    /// scadenza. Tutto ciò che non è protocollo finisce nel log.
    private static func waitForHandshake(_ fh: FileHandle, timeout: TimeInterval) -> HandshakeBox {
        let box = HandshakeBox()
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            var buffer = Data()
            var finished = false
            while !finished {
                let chunk = fh.availableData
                if chunk.isEmpty { break }   // EOF: il worker è morto
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)
                    guard let line = String(data: lineData, encoding: .utf8) else { continue }

                    if line.hasPrefix(USBRedirWorker.pidPrefix) {
                        let digits = line.dropFirst(USBRedirWorker.pidPrefix.count)
                        box.lock.lock()
                        box.workerPid = pid_t(digits) ?? 0
                        box.lock.unlock()
                    } else if line == USBRedirWorker.okLine {
                        box.lock.lock(); box.ok = true; box.lock.unlock()
                        finished = true
                        break
                    } else if line.hasPrefix(USBRedirWorker.errPrefix) {
                        box.lock.lock()
                        box.message = String(line.dropFirst(USBRedirWorker.errPrefix.count))
                        box.lock.unlock()
                        finished = true
                        break
                    } else if !line.isEmpty {
                        NSLog("UTMUSBHelper[worker]: %@", line)
                    }
                }
            }
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            box.lock.lock(); box.timedOut = true; box.lock.unlock()
        }
        return box
    }

    // MARK: - Utilità

    @discardableResult
    private static func runProcess(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
