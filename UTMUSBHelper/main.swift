//
// Entry point of the privileged LaunchDaemon.
//
// Central safety net: when the LAST client disconnects — whether the app
// quit politely or crashed, XPC reports the same event — we detach
// everything ourselves. The daemon owns the devices and outlives the
// client: without this, an app crash would leave the user with a disk
// claimed by nobody and invisible to macOS until they unplug the cable.
//

import Foundation

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = USBRedirService()
    private var activeConnections = 0
    private let lock = NSLock()

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: UTMUSBHelperProtocol.self)
        connection.exportedObject = service

        let onGone: () -> Void = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.activeConnections -= 1
            let none = self.activeConnections <= 0
            self.lock.unlock()
            guard none else { return }
            NSLog("UTMUSBHelper: nessun client collegato, rilascio tutti i device")
            self.service.detachAll { _ in }
        }
        // invalidation E interruption: la prima per una chiusura pulita,
        // la seconda per un crash del client.
        connection.invalidationHandler = onGone
        connection.interruptionHandler = onGone

        lock.lock(); activeConnections += 1; lock.unlock()
        connection.resume()
        return true
    }
}

// Lo stesso binario ha due vite. Senza argomenti è il LaunchDaemon; con
// `--worker` è il processo che fa la claim, lanciato dal demone dentro la
// sessione grafica dell'utente perché TCC possa mostrargli il prompt
// (§ USBRedirWorker.swift per il perché disteso).
//
// Un solo binario e non due target distinti di proposito: così l'identità
// di firma è la stessa, e quindi la concessione TCC che l'utente dà al
// worker vale anche per il demone, senza doverla dare due volte.
// Modalità worker: `--worker <vid> <pid> <socket> [pid-app]`.
//
// L'ultimo argomento è il processo dell'app da sorvegliare, così un crash di
// UTM non lascia il device reclamato da un orfano (§ installAppWatch).
let arguments = CommandLine.arguments
if arguments.count >= 5, arguments[1] == "--worker" {
    guard let vid = UInt16(arguments[2]), let pid = UInt16(arguments[3]) else {
        FileHandle.standardError.write(Data("vendor/product id non validi\n".utf8))
        exit(2)
    }
    let watchPid: pid_t = arguments.count >= 6 ? (pid_t(arguments[5]) ?? 0) : 0
    USBRedirWorker.run(vendorId: vid, productId: pid, socketPath: arguments[4], watchPid: watchPid)
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: kUTMUSBHelperMachServiceName)
listener.delegate = delegate
listener.resume()
NSLog("UTMUSBHelper avviato (pid %d)", ProcessInfo.processInfo.processIdentifier)
RunLoop.main.run()
