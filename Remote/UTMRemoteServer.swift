//
// Copyright © 2023 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import Combine
import Network
import SwiftConnect
import UserNotifications

let service = "_utm_server._tcp"

actor UTMRemoteServer {
    fileprivate let data: UTMData
    private let keyManager = UTMRemoteKeyManager(forClient: false)
    private let center = UNUserNotificationCenter.current()
    let state: State

    private var cancellables = Set<AnyCancellable>()
    private var notificationDelegate: NotificationDelegate?
    private var listener: Task<Void, Error>?
    private var pendingConnections: [State.ClientFingerprint: Connection] = [:]
    private var establishedConnections: [State.ClientFingerprint: Remote] = [:]
    private var local: Local!

    private func _replaceCancellables(with set: Set<AnyCancellable>) {
        cancellables = set
    }

    @MainActor
    init(data: UTMData) {
        let _state = State()
        var _cancellables = Set<AnyCancellable>()
        self.data = data
        self.state = _state

        _cancellables.insert(_state.$approvedClients.sink { approved in
            Task {
                await self.approvedClientsHasChanged(approved)
            }
        })
        _cancellables.insert(_state.$blockedClients.sink { blocked in
            Task {
                await self.blockedClientsHasChanged(blocked)
            }
        })
        _cancellables.insert(_state.$connectedClients.sink { connected in
            Task {
                await self.connectedClientsHasChanged(connected)
            }
        })
        _cancellables.insert(_state.$serverAction.sink { action in
            guard action != .none else {
                return
            }
            Task {
                switch action {
                case .stop:
                    await self.stop()
                    break
                case .start:
                    await self.start()
                    break
                case .reset:
                    await self.resetServer()
                    break
                default:
                    break
                }
                self.state.requestServerAction(.none)
            }
        })
        // this is a really ugly way to make sure that we keep a reference to the AnyCancellables even though
        // we cannot access self._cancellables from init() due to it being associated with @MainActor.
        // it should be fine because we only need to make sure the references are not dropped, we will never
        // actually read from _cancellables
        Task {
            await self._replaceCancellables(with: _cancellables)
        }
    }

    private func withErrorNotification(_ body: () async throws -> Void) async {
        do {
            try await body()
        } catch {
            await notifyError(error)
        }
    }

    func start() async {
        do {
            try await center.requestAuthorization(options: .alert)
        } catch {
            logger.error("Failed to authorize notifications.")
        }
        await withErrorNotification {
            guard await !state.isServerActive else {
                return
            }
            try await keyManager.load()
            registerNotifications()
            local = Local(server: self)
            listener = Task {
                await withErrorNotification {
                    for try await connection in Connection.advertise(forServiceType: service, identity: keyManager.identity) {
                        if let connection = try? await Connection(connection: connection) {
                            await newRemoteConnection(connection)
                        }
                    }
                }
                await stop()
            }
            await state.setServerActive(true)
        }
    }

    func stop() async {
        await state.disconnectAll()
        unregisterNotifications()
        if let listener = listener {
            self.listener = nil
            listener.cancel()
            _ = await listener.result
        }
        local = nil
        await state.setServerActive(false)
    }

    private func newRemoteConnection(_ connection: Connection) async {
        let remoteAddress = connection.connection.endpoint.debugDescription
        guard let fingerprint = connection.peerCertificateChain.first?.fingerprint().hexString() else {
            connection.close()
            return
        }
        guard await !state.isBlocked(fingerprint) else {
            connection.close()
            return
        }
        await state.seen(fingerprint, name: remoteAddress)
        if await state.isApproved(fingerprint) {
            await notifyNewConnection(remoteAddress: remoteAddress, fingerprint: fingerprint)
            await establishConnection(connection)
        } else {
            pendingConnections[fingerprint] = connection
            await notifyNewConnection(remoteAddress: remoteAddress, fingerprint: fingerprint, isUnknown: true)
        }
    }

    private func approvedClientsHasChanged(_ approvedClients: Set<State.Client>) async {
        for approvedClient in approvedClients {
            if let connection = pendingConnections.removeValue(forKey: approvedClient.fingerprint) {
                await establishConnection(connection)
            }
        }
    }

    private func blockedClientsHasChanged(_ blockedClients: Set<State.Client>) {
        for blockedClient in blockedClients {
            if let connection = pendingConnections.removeValue(forKey: blockedClient.fingerprint) {
                connection.close()
            }
        }
    }

    private func connectedClientsHasChanged(_ connectedClients: Set<State.ClientFingerprint>) {
        for client in establishedConnections.keys {
            if !connectedClients.contains(client) {
                if let remote = establishedConnections.removeValue(forKey: client) {
                    remote.close()
                }
            }
        }
    }

    private func establishConnection(_ connection: Connection) async {
        guard let fingerprint = connection.peerCertificateChain.first?.fingerprint().hexString() else {
            connection.close()
            return
        }
        await withErrorNotification {
            let peer = Peer(connection: connection, localInterface: local)
            let remote = Remote(peer: peer)
            do {
                try await remote.handshake()
            } catch {
                peer.close()
                throw error
            }
            establishedConnections.updateValue(remote, forKey: fingerprint)
            await state.connect(fingerprint)
        }
    }

    private func resetServer() async {
        await withErrorNotification {
            try await keyManager.reset()
        }
    }
    
    /// Send message to every connected remote client.
    ///
    /// If any are disconnected, we will gracefully handle the disconnect.
    /// If every remote user is disconnected, then we throw an error.
    /// If `body` throws an error for any remote client (excluding NWError), then we throw an error.
    /// - Parameter body: <#body description#>
    func broadcast(_ body: @escaping (Remote) async throws -> Void) async rethrows {
        enum BroadcastError: Error {
            case connectionError(NWError, State.ClientFingerprint)
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (fingerprint, remote) in establishedConnections {
                if Task.isCancelled {
                    break
                }
                group.addTask {
                    do {
                        try await body(remote)
                    } catch {
                        if let error = error as? NWError {
                            throw BroadcastError.connectionError(error, fingerprint)
                        } else {
                            throw error
                        }
                    }
                }
            }
            var hasAnySuccess = false
            var lastError: Error?
            while !group.isEmpty {
                switch await group.nextResult() {
                case .failure(let error):
                    if case BroadcastError.connectionError(let error, let fingerprint) = error {
                        // disconnect any clients who failed to respond
                        await notifyError(error)
                        await state.disconnect(fingerprint)
                        lastError = error
                    } else {
                        // if any client returned an error, we fail the entire broadcast
                        throw error
                    }
                default:
                    hasAnySuccess = true
                    break
                }
            }
            // if we have all connection errors, then broadcast has failed
            if !hasAnySuccess, let error = lastError {
                throw error
            }
        }
    }
}

extension UTMRemoteServer {
    private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        private let state: UTMRemoteServer.State

        init(state: UTMRemoteServer.State) {
            self.state = state
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            .banner
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            Task {
                let userInfo = response.notification.request.content.userInfo
                guard let fingerprint = userInfo["FINGERPRINT"] as? String else {
                    return
                }
                switch response.actionIdentifier {
                case "ALLOW_ACTION":
                    await state.approve(fingerprint)
                case "DENY_ACTION":
                    await state.block(fingerprint)
                case "DISCONNECT_ACTION":
                    await state.disconnect(fingerprint)
                default:
                    break
                }
                completionHandler()
            }
        }
    }

    private func registerNotifications() {
        let allowAction = UNNotificationAction(identifier: "ALLOW_ACTION",
                                               title: NSString.localizedUserNotificationString(forKey: "Allow", arguments: nil),
                                               options: [])
        let denyAction = UNNotificationAction(identifier: "DENY_ACTION",
                                              title: NSString.localizedUserNotificationString(forKey: "Deny", arguments: nil),
                                              options: [])
        let disconnectAction = UNNotificationAction(identifier: "DISCONNECT_ACTION",
                                                    title: NSString.localizedUserNotificationString(forKey: "Disconnect", arguments: nil),
                                                    options: [])
        let unknownRemoteCategory = UNNotificationCategory(identifier: "UNKNOWN_REMOTE_CLIENT",
                                                           actions: [denyAction, allowAction],
                                                           intentIdentifiers: [],
                                                           hiddenPreviewsBodyPlaceholder: NSString.localizedUserNotificationString(forKey: "New unknown remote client connection.", arguments: nil),
                                                           options: .customDismissAction)
        let trustedRemoteCategory = UNNotificationCategory(identifier: "TRUSTED_REMOTE_CLIENT",
                                                           actions: [disconnectAction],
                                                           intentIdentifiers: [],
                                                           hiddenPreviewsBodyPlaceholder: NSString.localizedUserNotificationString(forKey: "New trusted remote client connection.", arguments: nil),
                                                           options: [])
        center.setNotificationCategories([unknownRemoteCategory, trustedRemoteCategory])
        notificationDelegate = NotificationDelegate(state: state)
        center.delegate = notificationDelegate
    }

    private func unregisterNotifications() {
        center.setNotificationCategories([])
        notificationDelegate = nil
        center.delegate = nil
    }

    private func notifyNewConnection(remoteAddress: String, fingerprint: String, isUnknown: Bool = false) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            logger.info("Notifications disabled, ignoring connection request from '\(remoteAddress)' with fingerprint '\(fingerprint)'")
            return
        }
        let content = UNMutableNotificationContent()
        if isUnknown {
            content.title = NSString.localizedUserNotificationString(forKey: "Unknown Remote Client", arguments: nil)
            content.body = NSString.localizedUserNotificationString(forKey: "A client with fingerprint '%@' is attempting to connect.", arguments: [fingerprint])
            content.categoryIdentifier = "UNKNOWN_REMOTE_CLIENT"
        } else {
            content.title = NSString.localizedUserNotificationString(forKey: "Remote Client Connected", arguments: nil)
            content.body = NSString.localizedUserNotificationString(forKey: "Established connection from %@.", arguments: [remoteAddress])
            content.categoryIdentifier = "TRUSTED_REMOTE_CLIENT"
        }
        content.userInfo = ["FINGERPRINT": fingerprint]
        let request = UNNotificationRequest(identifier: fingerprint,
                                            content: content,
                                            trigger: nil)
        do {
            try await center.add(request)
            if !isUnknown {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) {
                    self.center.removeDeliveredNotifications(withIdentifiers: [fingerprint])
                }
            }
        } catch {
            logger.error("Error sending remote connection request: \(error.localizedDescription)")
        }
    }

    fileprivate func notifyError(_ error: Error) async {
        logger.error("UTM Remote Server error: '\(error)'")
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "UTM Remote Server Error", arguments: nil)
        content.body = error.localizedDescription
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        do {
            try await center.add(request)
        } catch {
            logger.error("Error sending error notification: \(error.localizedDescription)")
        }
    }
}

extension UTMRemoteServer {
    @MainActor
    class State: ObservableObject {
        typealias ClientFingerprint = String
        struct Client: Codable, Identifiable, Hashable {
            let fingerprint: ClientFingerprint
            var name: String
            var lastSeen: Date

            var id: String {
                fingerprint
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(fingerprint)
            }

            static func == (lhs: Client, rhs: Client) -> Bool {
                lhs.hashValue == rhs.hashValue
            }
        }

        enum ServerAction {
            case none
            case stop
            case start
            case reset
        }

        @Published var allClients: [Client] {
            didSet {
                let all = Set(allClients)
                approvedClients.subtract(approvedClients.subtracting(all))
                blockedClients.subtract(blockedClients.subtracting(all))
                connectedClients.subtract(connectedClients.subtracting(all.map({ $0.fingerprint })))
            }
        }

        @Published var approvedClients: Set<Client> {
            didSet {
                UserDefaults.standard.setValue(try! approvedClients.propertyList(), forKey: "TrustedClients")
            }
        }

        @Published var blockedClients: Set<Client> {
            didSet {
                UserDefaults.standard.setValue(try! blockedClients.propertyList(), forKey: "BlockedClients")
            }
        }

        @Published var connectedClients = Set<ClientFingerprint>()

        @Published var serverAction: ServerAction = .none

        var isBusy: Bool {
            serverAction != .none
        }

        @Published private(set) var isServerActive = false

        init() {
            var _approvedClients = Set<Client>()
            if let array = UserDefaults.standard.array(forKey: "TrustedClients") {
                if let clients = try? Set<Client>(fromPropertyList: array) {
                    _approvedClients = clients
                }
            }
            self.approvedClients = _approvedClients
            var _blockedClients = Set<Client>()
            if let array = UserDefaults.standard.array(forKey: "BlockedClients") {
                if let clients = try? Set<Client>(fromPropertyList: array) {
                    _blockedClients = clients
                }
            }
            self.blockedClients = _blockedClients
            self.allClients = Array(_approvedClients) + Array(_blockedClients)
        }

        func isConnected(_ fingerprint: ClientFingerprint) -> Bool {
            connectedClients.contains(fingerprint)
        }

        func isApproved(_ fingerprint: ClientFingerprint) -> Bool {
            approvedClients.contains(where: { $0.fingerprint == fingerprint }) && !isBlocked(fingerprint)
        }

        func isBlocked(_ fingerprint: ClientFingerprint) -> Bool {
            blockedClients.contains(where: { $0.fingerprint == fingerprint })
        }

        fileprivate func setServerActive(_ isActive: Bool) {
            isServerActive = isActive
        }

        func requestServerAction(_ action: ServerAction) {
            serverAction = action
        }

        private func client(forFingerprint fingerprint: ClientFingerprint, name: String? = nil) -> (Int?, Client) {
            if let idx = allClients.firstIndex(where: { $0.fingerprint == fingerprint }) {
                if let name = name {
                    allClients[idx].name = name
                }
                return (idx, allClients[idx])
            } else {
                return (nil, Client(fingerprint: fingerprint, name: name ?? "", lastSeen: Date()))
            }
        }

        func seen(_ fingerprint: ClientFingerprint, name: String? = nil) {
            var (idx, client) = client(forFingerprint: fingerprint, name: name)
            client.lastSeen = Date()
            if let idx = idx {
                allClients[idx] = client
            } else {
                allClients.append(client)
            }
        }

        fileprivate func connect(_ fingerprint: ClientFingerprint, name: String? = nil) {
            connectedClients.insert(fingerprint)
        }

        func disconnect(_ fingerprint: ClientFingerprint) {
            connectedClients.remove(fingerprint)
        }

        func disconnectAll() {
            connectedClients.removeAll()
        }

        func approve(_ fingerprint: ClientFingerprint) {
            let (_, client) = client(forFingerprint: fingerprint)
            approvedClients.insert(client)
            blockedClients.remove(client)
        }

        func block(_ fingerprint: ClientFingerprint) {
            let (_, client) = client(forFingerprint: fingerprint)
            approvedClients.remove(client)
            blockedClients.insert(client)
        }
    }
}

extension UTMRemoteServer {
    class Local: LocalInterface {
        typealias M = UTMRemoteMessageServer

        private let server: UTMRemoteServer

        private var data: UTMData {
            server.data
        }

        init(server: UTMRemoteServer) {
            self.server = server
        }

        func handle(message: M, data: Data) async throws -> Data {
            switch message {
            case .serverHandshake:
                return try await _handshake(parameters: .decode(data)).encode()
            case .listVirtualMachines:
                return try await _listVirtualMachines(parameters: .decode(data)).encode()
            case .getQEMUConfiguration:
                return try await _getQEMUConfiguration(parameters: .decode(data)).encode()
            case .updateQEMUConfiguration:
                return try await _updateQEMUConfiguration(parameters: .decode(data)).encode()
            case .getPackageFile:
                return try await _getPackageFile(parameters: .decode(data)).encode()
            case .startVirtualMachine:
                return try await _startVirtualMachine(parameters: .decode(data)).encode()
            }
        }

        func handle(error: Error) {
            Task {
                await server.notifyError(error)
            }
        }

        @MainActor
        private func findVM(withId id: UUID) async throws -> VMData {
            let vm = data.virtualMachines.first(where: { $0.id == id })
            if let vm = vm {
                return vm
            } else {
                throw UTMRemoteServer.ServerError.notFound(id)
            }
        }

        private func _handshake(parameters: M.ServerHandshake.Request) async throws -> M.ServerHandshake.Reply {
            return .init(version: UTMRemoteMessageServer.version)
        }

        private func _listVirtualMachines(parameters: M.ListVirtualMachines.Request) async throws -> M.ListVirtualMachines.Reply {
            let vms = await data.virtualMachines
            let items = await Task { @MainActor in
                vms.map { vmdata in
                    M.ListVirtualMachines.Information(id: vmdata.id,
                                                      name: vmdata.detailsTitleLabel,
                                                      path: vmdata.pathUrl.path,
                                                      isShortcut: vmdata.isShortcut,
                                                      isSuspended: vmdata.registryEntry?.isSuspended ?? false,
                                                      backend: vmdata.wrapped is UTMQemuVirtualMachine ? .qemu : .unknown)
                }
            }.value
            return .init(items: items)
        }

        private func _getQEMUConfiguration(parameters: M.GetQEMUConfiguration.Request) async throws -> M.GetQEMUConfiguration.Reply {
            let vm = try await findVM(withId: parameters.id)
            if let config = await vm.config as? UTMQemuConfiguration {
                return .init(configuration: config)
            } else {
                throw ServerError.invalidBackend
            }
        }

        private func _updateQEMUConfiguration(parameters: M.UpdateQEMUConfiguration.Request) async throws -> M.UpdateQEMUConfiguration.Reply {
            return .init()
        }

        private func _getPackageFile(parameters: M.GetPackageFile.Request) async throws -> M.GetPackageFile.Reply {
            return .init(data: nil)
        }

        private func _startVirtualMachine(parameters: M.StartVirtualMachine.Request) async throws -> M.StartVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            let port = try await data.startRemote(vm: vm, options: parameters.options, forServer: server)
            return .init(spiceServerPort: port)
        }
    }
}

extension UTMRemoteServer {
    class Remote {
        typealias M = UTMRemoteMessageClient
        private let peer: Peer<UTMRemoteMessageServer>

        init(peer: Peer<UTMRemoteMessageServer>) {
            self.peer = peer
        }

        func close() {
            peer.close()
        }

        func handshake() async throws {
            guard try await _handshake(parameters: .init(version: UTMRemoteMessageClient.version)).version == UTMRemoteMessageClient.version else {
                throw ServerError.versionMismatch
            }
        }

        private func _handshake(parameters: M.ClientHandshake.Request) async throws -> M.ClientHandshake.Reply {
            try await M.ClientHandshake.send(parameters, to: peer)
        }

        func virtualMachine(id: UUID, didTransitionToState state: UTMVirtualMachineState) async throws {
            try await _virtualMachineDidTransition(parameters: .init(id: id, state: state))
        }

        @discardableResult
        private func _virtualMachineDidTransition(parameters: M.VirtualMachineDidTransition.Request) async throws -> M.VirtualMachineDidTransition.Reply {
            try await M.VirtualMachineDidTransition.send(parameters, to: peer)
        }

        func virtualMachine(id: UUID, didErrorWithMessage message: String) async throws {
            try await _virtualMachineDidError(parameters: .init(id: id, errorMessage: message))
        }

        @discardableResult
        private func _virtualMachineDidError(parameters: M.VirtualMachineDidError.Request) async throws -> M.VirtualMachineDidError.Reply {
            try await M.VirtualMachineDidError.send(parameters, to: peer)
        }
    }
}

extension UTMRemoteServer {
    enum ServerError: LocalizedError {
        case versionMismatch
        case notFound(UUID)
        case invalidBackend

        var errorDescription: String? {
            switch self {
            case .versionMismatch:
                return NSLocalizedString("The client interface version does not match the server.", comment: "UTMRemoteServer")
            case .notFound(let id):
                return String.localizedStringWithFormat(NSLocalizedString("Cannot find VM with ID: %@", comment: "UTMRemoteServer"), id.uuidString)
            case .invalidBackend:
                return NSLocalizedString("Invalid backend.", comment: "UTMRemoteServer")
            }
        }
    }
}
