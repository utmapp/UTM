//
// Privileged worker: this is where all the work on the USB device happens —
// unmount, interface claim, traffic pump, release.
//
// It is started by the APP through Authorization Services, not by a daemon.
// The difference is not stylistic, and it cost a full session of diagnosis:
//
// claiming a USB interface on a storage device goes through the sandbox
// gate `iokit-open-service IOUSBHostInterface`, which consults TCC. For a
// root process TCC also asks the SYSTEM domain, and that domain can only
// answer if it can attribute the request to a RESPONSIBLE process that is a
// user-session app holding Full Disk Access: then the question becomes
// `AllFiles`, which it can answer by itself. Otherwise it becomes
// `RemovableVolumes`, which it must forward to a user agent it cannot reach
// from there — `bootstrap look-up: No such process` — and it denies.
//
// A LaunchDaemon has no such responsible process, whatever its uid. An app
// that spawns the worker itself does, and the prompt appears.
//

import Foundation

enum USBRedirWorker {
    static let pidPrefix = "PID "
    static let okLine = "OK"
    static let errPrefix = "ERR "

    /// Handle vivo della redirezione. Serve a `finish()`, raggiungibile da
    /// SIGTERM, dalla chiusura del peer o dalla morte dell'app.
    private static var handle: OpaquePointer?
    private static var mountedDisks: [String] = []
    private static let stateLock = NSLock()

    /// Tenuti vivi qui: un DispatchSource deallocato smette di scattare.
    private static var sources: [any DispatchSourceProtocol] = []

    static func run(vendorId: UInt16,
                    productId: UInt16,
                    socketPath: String,
                    watchPid: pid_t) -> Never {
        emit("\(pidPrefix)\(ProcessInfo.processInfo.processIdentifier)")

        // Installati PRIMA di toccare il device: qualunque cosa vada storta
        // da qui in poi, l'uscita deve passare per la via pulita.
        installSignalHandling()
        if watchPid > 0 { installAppWatch(watchPid) }

        // 1. Dischi ESPOSTI DA QUESTO device (vuoto se non è un'unità di
        //    archiviazione: dongle, seriali, schede…).
        let disks = USBDiskLocator.wholeDisks(forVendorId: Int(vendorId), productId: Int(productId))

        // 2. Smontaggio. DEVE riuscire prima di qualunque claim. Se fallisce
        //    a metà, si rimette a posto ciò che si era già smontato.
        var unmounted: [String] = []
        for disk in disks {
            if let failure = USBDiskUnmounter.unmountForClaim(disk) {
                USBDiskUnmounter.remount(unmounted)
                emit("\(errPrefix)\(failure)")
                exit(1)
            }
            unmounted.append(disk)
        }
        stateLock.lock(); mountedDisks = unmounted; stateLock.unlock()

        // 3. Claim e avvio della redirezione.
        var errBuf = [CChar](repeating: 0, count: 512)
        let started = usbredir_start(vendorId,
                                     productId,
                                     socketPath,
                                     { _ in USBRedirWorker.peerClosedFromPumpThread() },
                                     nil,
                                     &errBuf,
                                     errBuf.count)

        guard let started else {
            let message = String(cString: errBuf)
            // Avevamo smontato noi: rimettiamo il disco com'era, altrimenti
            // l'utente si ritrova un volume sparito per un'operazione che
            // non è nemmeno riuscita.
            USBDiskUnmounter.remount(unmounted)
            emit("\(errPrefix)\(message.isEmpty ? "avvio della redirezione fallito" : message)")
            exit(1)
        }

        stateLock.lock(); handle = started; stateLock.unlock()
        emit(okLine)

        while true { RunLoop.main.run(until: .distantFuture) }
    }

    // MARK: - Percorsi di uscita

    private static func installSignalHandling() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)
        for signalNumber in [SIGTERM, SIGINT] {
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { finish(0) }
            source.resume()
            sources.append(source)
        }
    }

    /// Sorveglia il processo dell'app. È la rete che sostituisce
    /// l'invalidazione XPC del vecchio demone: se UTM **crasha** —
    /// non si limita a chiudersi — nessuno ci direbbe di mollare il device,
    /// e l'utente resterebbe con un disco reclamato da un processo orfano,
    /// invisibile a macOS finché non stacca il cavo.
    ///
    /// kqueue e non il controllo del genitore: il nostro genitore è il
    /// trampolino di Authorization Services, che esce subito, quindi
    /// `getppid()` non dice nulla di utile sull'app.
    private static func installAppWatch(_ pid: pid_t) {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler {
            FileHandle.standardError.write(Data("l'app è terminata, rilascio il device\n".utf8))
            finish(0)
        }
        source.resume()
        sources.append(source)
    }

    /// Il guest ha chiuso il socket: VM fermata, VM crashata o QEMU ucciso.
    /// Arriva DAL THREAD DI PUMP, dove `usbredir_stop()` si auto-attenderebbe
    /// (§ usbredir_bridge.h), quindi si rimbalza altrove prima di chiudere.
    private static func peerClosedFromPumpThread() {
        DispatchQueue.global().async { finish(0) }
    }

    /// Unica uscita. `usbredir_stop` rilascia le interfacce E forza la
    /// re-enumerazione, che è ciò che restituisce davvero il disco a macOS;
    /// solo dopo ha senso rimontare, perché prima del reset il block device
    /// non esiste ancora.
    private static func finish(_ code: Int32) -> Never {
        stateLock.lock()
        let liveHandle = handle
        let disks = mountedDisks
        handle = nil
        mountedDisks = []
        stateLock.unlock()

        if let liveHandle { usbredir_stop(liveHandle) }
        USBDiskUnmounter.remount(disks)
        exit(code)
    }

    /// Scrittura non bufferizzata: l'app legge queste righe in tempo reale
    /// per decidere se l'attach è riuscito.
    private static func emit(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}
