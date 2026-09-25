//
// App side of the XPC protocol to UTMUSBHelper (§ Services/
// UTMUSBHelperProtocol.swift). Handles registering the daemon through
// SMAppService (macOS 13+, the replacement for the deprecated SMJobBless):
// no Apple-approved entitlement, just the ordinary administrator
// authorization prompt, shown ONCE at install time.
//

import Foundation
#if os(macOS)
import ServiceManagement
#endif

enum UTMUSBHelperError: LocalizedError {
    case unavailable
    case requiresApproval
    case registrationFailed(String)
    case xpcFailed(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return NSLocalizedString("Richiede macOS 13 o successivo.", comment: "UTMUSBHelperError")
        case .requiresApproval:
            return NSLocalizedString("Approva UTMUSBHelper in Impostazioni di Sistema → Generale → Elementi login ed estensioni, poi riprova.", comment: "UTMUSBHelperError")
        case .registrationFailed(let m):
            return String.localizedStringWithFormat(NSLocalizedString("Impossibile installare l'helper USB: %@", comment: "UTMUSBHelperError"), m)
        case .xpcFailed(let m):
            return String.localizedStringWithFormat(NSLocalizedString("Comunicazione con l'helper USB fallita: %@", comment: "UTMUSBHelperError"), m)
        case .operationFailed(let m):
            return m
        }
    }
}

#if os(macOS)
@available(macOS 13.0, *)
final class UTMUSBHelperController {
    static let shared = UTMUSBHelperController()

    private let plistName = "com.utmapp.UTMUSBHelper.plist"
    private var service: SMAppService { SMAppService.daemon(plistName: plistName) }

    var isRegistered: Bool { service.status == .enabled }

    /// Registra il demone se serve — il prompt di autorizzazione di sistema
    /// compare SOLO la prima volta in assoluto.
    func registerIfNeeded() throws {
        switch service.status {
        case .enabled:
            return

        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
            throw UTMUSBHelperError.requiresApproval

        // `.notFound` NON va trattato come errore fatale, malgrado il nome
        // e la documentazione ("il servizio non è nel bundle").
        //
        // Verificato dal log di sistema su macOS 26: prima della prima
        // registrazione lo stato è .notFound (3), non .notRegistered (0).
        // `smd` il plist lo legge correttamente — stampa Label e
        // BundleProgram giusti — e fallisce solo nel recuperare la
        // "disposition" da backgroundtaskmanagementd, che di quel servizio
        // non ha ancora alcun record: ovvio per un demone mai registrato.
        // Nello stesso log altre app di sistema mostrano lo stesso stato 3
        // nelle stesse condizioni.
        //
        // Trattarlo come fatale impediva la registrazione per sempre, con
        // un messaggio fuorviante su un file che nel bundle c'era eccome.
        // Si tenta quindi comunque, e si segnala errore solo se a fallire
        // è register().
        case .notRegistered, .notFound:
            fallthrough

        @unknown default:
            do {
                try service.register()
            } catch {
                throw UTMUSBHelperError.registrationFailed(error.localizedDescription)
            }
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                throw UTMUSBHelperError.requiresApproval
            }
        }
    }

    private func makeConnection() -> NSXPCConnection {
        let c = NSXPCConnection(machServiceName: kUTMUSBHelperMachServiceName, options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: UTMUSBHelperProtocol.self)
        c.resume()
        return c
    }

    /// Wrapper comune per una chiamata XPC one-shot: risolve UNA sola volta
    /// fra errorHandler, interruption e reply (qualunque arrivi prima), e
    /// invalida sempre la connessione.
    private func callHelper<T>(_ body: @escaping (UTMUSBHelperProtocol, @escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let connection = self.makeConnection()
            var didResume = false
            let resumeOnce: (Result<T, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                connection.invalidate()
                continuation.resume(with: result)
            }
            connection.interruptionHandler = {
                resumeOnce(.failure(UTMUSBHelperError.xpcFailed(
                    NSLocalizedString("Connessione interrotta.", comment: "UTMUSBHelperError"))))
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                resumeOnce(.failure(UTMUSBHelperError.xpcFailed(error.localizedDescription)))
            }) as? UTMUSBHelperProtocol else {
                resumeOnce(.failure(UTMUSBHelperError.xpcFailed(
                    NSLocalizedString("Proxy XPC non valido.", comment: "UTMUSBHelperError"))))
                return
            }
            body(proxy) { resumeOnce($0) }
        }
    }

    func ping() async throws -> String {
        try await callHelper { proxy, done in
            proxy.ping { done(.success($0)) }
        }
    }

    /// Collega il device alla VM in ascolto su `socketPath`. Il demone
    /// smonta da sé gli eventuali volumi PRIMA della claim.
    func attachDevice(vendorId: Int, productId: Int, socketPath: String) async throws {
        try await callHelper { proxy, done in
            proxy.attachDevice(vendorId: vendorId, productId: productId, socketPath: socketPath) { ok, err in
                if ok { done(.success(())) }
                else { done(.failure(UTMUSBHelperError.operationFailed(
                    err ?? NSLocalizedString("Errore sconosciuto.", comment: "UTMUSBHelperError")))) }
            }
        }
    }

    func detachDevice(vendorId: Int, productId: Int) async throws {
        try await callHelper { proxy, done in
            proxy.detachDevice(vendorId: vendorId, productId: productId) { ok, err in
                if ok { done(.success(())) }
                else { done(.failure(UTMUSBHelperError.operationFailed(
                    err ?? NSLocalizedString("Errore sconosciuto.", comment: "UTMUSBHelperError")))) }
            }
        }
    }

    func listAttached() async -> [String] {
        (try? await callHelper { (proxy: UTMUSBHelperProtocol, done: @escaping (Result<[String], Error>) -> Void) in
            proxy.listAttached { done(.success($0)) }
        }) ?? []
    }

    /// Rete di sicurezza per la chiusura dell'app. No-op se il demone non è
    /// mai stato installato: non ha senso mostrare il prompt di
    /// installazione mentre si sta uscendo.
    ///
    /// Nota: il demone stacca tutto anche da sé quando l'ultima connessione
    /// XPC cade (§ main.swift), quindi questa è una cintura in più oltre
    /// alle bretelle — copre il caso di uscita pulita senza attendere il
    /// timeout di invalidazione.
    func detachAllIfRegistered() async {
        guard isRegistered else { return }
        _ = try? await callHelper { (proxy: UTMUSBHelperProtocol, done: @escaping (Result<Void, Error>) -> Void) in
            proxy.detachAll { _ in done(.success(())) }
        }
    }
}
#endif
