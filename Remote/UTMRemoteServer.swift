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
import SwiftPortmap
import UserNotifications

let service = "_utm_server._tcp"

actor UTMRemoteServer {
    fileprivate let data: UTMData
    private let keyManager = UTMRemoteKeyManager(forClient: false)
    private let center = UNUserNotificationCenter.current()
    private let connectionQueue = DispatchQueue(label: "UTM Remote Server Connection")
    let state: State

    private var cancellables = Set<AnyCancellable>()
    private var notificationDelegate: NotificationDelegate?
    private var listener: Task<Void, Error>?
    private var pendingConnections: [State.ClientFingerprint: Connection] = [:]
    private var establishedConnections: [State.ClientFingerprint: Remote] = [:]
    private var natPort: SwiftPortmap.Port?

    private func _replaceCancellables(with set: Set<AnyCancellable>) {
        cancellables = set
    }

    @Setting("ServerAutostart") private var isServerAutostart: Bool = false
    @Setting("ServerExternal") private var isServerExternal: Bool = false
    @Setting("ServerAutoblock") private var isServerAutoblock: Bool = false
    @Setting("ServerPort") private var serverPort: Int = 0
    @Setting("ServerPasswordRequired") private var isServerPasswordRequired: Bool = false
    @Setting("ServerPassword") private var serverPassword: String = ""

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
            if case .silentError(let error) = error as? ServerError {
                logger.error("Error message inhibited: \(error)")
            } else {
                await notifyError(error)
            }
        }
    }

    private var metadata: NWTXTRecord {
        NWTXTRecord(["Model": MacDevice.current.model])
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
            await state.setServerFingerprint(keyManager.fingerprint!)
            registerNotifications()
            listener = Task {
                await withErrorNotification {
                    if isServerExternal && serverPort > 0 && serverPort <= UInt16.max {
                        natPort = Port.TCP(internalPort: UInt16(serverPort))
                        natPort!.mappingChangedHandler = { port in
                            Task {
                                let address = try? await port.externalIpv4Address
                                let port = try? await port.externalPort
                                await self.state.setExternalAddress(address, port: port)
                            }
                        }
                        await withErrorNotification {
                            guard try await natPort!.externalPort == serverPort else {
                                throw ServerError.natReservationMismatch(serverPort)
                            }
                        }
                    }
                    let port = serverPort > 0 && serverPort <= UInt16.max ? NWEndpoint.Port(integerLiteral: UInt16(serverPort)) : .any
                    for try await connection in Connection.advertise(on: port, forServiceType: service, txtRecord: metadata, connectionQueue: connectionQueue, identity: keyManager.identity) {
                        let connection = try? await Connection(connection: connection, connectionQueue: connectionQueue) { connection, error in
                            Task {
                                guard let fingerprint = connection.fingerprint else {
                                    return
                                }
                                if !(error is NWError) {
                                    // connection errors are too noisy
                                    await self.notifyError(error)
                                }
                                await self.state.disconnect(fingerprint)
                            }
                        }
                        if let connection = connection {
                            await newRemoteConnection(connection)
                        }
                    }
                }
                natPort = nil
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
        await state.setExternalAddress()
        await state.setServerActive(false)
    }

    private func newRemoteConnection(_ connection: Connection) async {
        let remoteAddress = connection.connection.endpoint.hostname ?? "\(connection.connection.endpoint)"
        guard let fingerprint = connection.fingerprint else {
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
        } else if isServerAutoblock {
            await state.block(fingerprint)
            connection.close()
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
                    Task { @MainActor in
                        await suspendSessions(for: remote)
                    }
                }
            }
        }
    }

    @MainActor
    private func suspendSessions(for remote: Remote) async {
        let sessions = data.vmWindows.compactMap {
            if let session = $0.value as? VMRemoteSessionState {
                return ($0.key, session)
            } else {
                return nil
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for (vm, session) in sessions {
                if session.client?.id == remote.id {
                    session.client = nil
                }
                group.addTask {
                    try? await vm.wrapped?.pause()
                }
            }
            await group.waitForAll()
        }
    }

    private func establishConnection(_ connection: Connection) async {
        guard let fingerprint = connection.fingerprint else {
            connection.close()
            return
        }
        await withErrorNotification {
            let remote = Remote()
            let local = Local(server: self, client: remote)
            let peer = Peer(connection: connection, localInterface: local)
            remote.peer = peer
            do {
                try await remote.handshake()
            } catch {
                if let error = error as? NWError, case .posix(let code) = error, code == .ECONNRESET {
                    // if the user canceled the connection, we don't do anything
                    throw ServerError.silentError(error)
                }
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
            await state.setServerFingerprint(keyManager.fingerprint!)
        }
    }
    
    /// Send message to every connected remote client.
    ///
    /// If any are disconnected, we will gracefully handle the disconnect.
    /// If `body` throws an error for any remote client (excluding NWError), then we ignore it.
    /// - Parameter body: What to broadcast
    func broadcast(_ body: @escaping (Remote) async throws -> Void) async {
        enum BroadcastError: Error {
            case connectionError(NWError, State.ClientFingerprint)
        }
        await withThrowingTaskGroup(of: Void.self) { group in
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
            while !group.isEmpty {
                switch await group.nextResult() {
                case .failure(let error):
                    if case BroadcastError.connectionError(_, let fingerprint) = error {
                        // disconnect any clients who failed to respond
                        await state.disconnect(fingerprint)
                    } else {
                        logger.error("client returned error on broadcast: \(error)")
                    }
                default:
                    break
                }
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
                guard let hexString = userInfo["FINGERPRINT"] as? String, let fingerprint = State.ClientFingerprint(hexString: hexString) else {
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

    private func notifyNewConnection(remoteAddress: String, fingerprint: State.ClientFingerprint, isUnknown: Bool = false) async {
        let settings = await center.notificationSettings()
        let combinedFingerprint = (fingerprint ^ keyManager.fingerprint!).hexString()
        guard settings.authorizationStatus == .authorized else {
            logger.info("Notifications disabled, ignoring connection request from '\(remoteAddress)' with fingerprint '\(combinedFingerprint)'")
            return
        }
        let content = UNMutableNotificationContent()
        if isUnknown {
            content.title = NSString.localizedUserNotificationString(forKey: "Unknown Remote Client", arguments: nil)
            content.body = NSString.localizedUserNotificationString(forKey: "A client with fingerprint '%@' is attempting to connect.", arguments: [combinedFingerprint])
            content.categoryIdentifier = "UNKNOWN_REMOTE_CLIENT"
        } else {
            content.title = NSString.localizedUserNotificationString(forKey: "Remote Client Connected", arguments: nil)
            content.body = NSString.localizedUserNotificationString(forKey: "Established connection from %@.", arguments: [remoteAddress])
            content.categoryIdentifier = "TRUSTED_REMOTE_CLIENT"
        }
        let clientFingerprint = fingerprint.hexString()
        content.userInfo = ["FINGERPRINT": clientFingerprint]
        let request = UNNotificationRequest(identifier: clientFingerprint,
                                            content: content,
                                            trigger: nil)
        do {
            try await center.add(request)
            if !isUnknown {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) {
                    self.center.removeDeliveredNotifications(withIdentifiers: [clientFingerprint])
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
        typealias ClientFingerprint = [UInt8]
        typealias ServerFingerprint = [UInt8]
        struct Client: Codable, Identifiable, Hashable {
            let fingerprint: ClientFingerprint
            var name: String
            var lastSeen: Date

            var id: ClientFingerprint {
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

        @Published private(set) var serverFingerprint: ServerFingerprint = [] {
            didSet {
                UserDefaults.standard.setValue(serverFingerprint.hexString(), forKey: "ServerFingerprint")
            }
        }

        @Published private(set) var externalIPAddress: String?

        @Published private(set) var externalPort: UInt16?

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
            if let value = UserDefaults.standard.string(forKey: "ServerFingerprint"), let serverFingerprint = ServerFingerprint(hexString: value) {
                self.serverFingerprint = serverFingerprint
            }
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

        fileprivate func setServerFingerprint(_ fingerprint: ServerFingerprint) {
            serverFingerprint = fingerprint
        }

        fileprivate func setExternalAddress(_ address: String? = nil, port: UInt16? = nil) {
            externalIPAddress = address
            externalPort = port
        }
    }
}

extension UTMRemoteServer {
    class Local: LocalInterface {
        typealias M = UTMRemoteMessageServer

        private let server: UTMRemoteServer
        private let client: UTMRemoteServer.Remote
        private var isAuthenticated: Bool = false

        private var data: UTMData {
            server.data
        }

        init(server: UTMRemoteServer, client: UTMRemoteServer.Remote) {
            self.server = server
            self.client = client
        }

        func handle(message: M, data: Data) async throws -> Data {
            guard isAuthenticated || message == .serverHandshake else {
                throw ServerError.notAuthenticated
            }
            switch message {
            case .serverHandshake:
                return try await _handshake(parameters: .decode(data)).encode()
            case .listVirtualMachines:
                return try await _listVirtualMachines(parameters: .decode(data)).encode()
            case .reorderVirtualMachines:
                return try await _reorderVirtualMachines(parameters: .decode(data)).encode()
            case .getVirtualMachineInformation:
                return try await _getVirtualMachineInformation(parameters: .decode(data)).encode()
            case .getQEMUConfiguration:
                return try await _getQEMUConfiguration(parameters: .decode(data)).encode()
            case .getPackageSize:
                return try await _getPackageSize(parameters: .decode(data)).encode()
            case .getPackageFile:
                return try await _getPackageFile(parameters: .decode(data)).encode()
            case .sendPackageFile:
                return try await _sendPackageFile(parameters: .decode(data)).encode()
            case .deletePackageFile:
                return try await _deletePackageFile(parameters: .decode(data)).encode()
            case .mountGuestToolsOnVirtualMachine:
                return try await _mountGuestToolsOnVirtualMachine(parameters: .decode(data)).encode()
            case .startVirtualMachine:
                return try await _startVirtualMachine(parameters: .decode(data)).encode()
            case .stopVirtualMachine:
                return try await _stopVirtualMachine(parameters: .decode(data)).encode()
            case .restartVirtualMachine:
                return try await _restartVirtualMachine(parameters: .decode(data)).encode()
            case .pauseVirtualMachine:
                return try await _pauseVirtualMachine(parameters: .decode(data)).encode()
            case .resumeVirtualMachine:
                return try await _resumeVirtualMachine(parameters: .decode(data)).encode()
            case .saveSnapshotVirtualMachine:
                return try await _saveSnapshotVirtualMachine(parameters: .decode(data)).encode()
            case .deleteSnapshotVirtualMachine:
                return try await _deleteSnapshotVirtualMachine(parameters: .decode(data)).encode()
            case .restoreSnapshotVirtualMachine:
                return try await _restoreSnapshotVirtualMachine(parameters: .decode(data)).encode()
            case .changePointerTypeVirtualMachine:
                return try await _changePointerTypeVirtualMachine(parameters: .decode(data)).encode()
            }
        }

        @MainActor
        private func findVM(withId id: UUID, allowNotLoaded: Bool = false) throws -> VMData {
            let vm = data.virtualMachines.first(where: { $0.id == id })
            if let vm = vm {
                if let _ = vm.wrapped {
                    return vm
                } else if allowNotLoaded {
                    return vm
                }
            }
            throw UTMRemoteServer.ServerError.notFound(id)
        }

        @MainActor
        private func packageFileHasChanged(for vm: VMData, relativePathComponents: [String]) throws {
            if relativePathComponents.count == 1 && relativePathComponents[0] == kUTMBundleScreenshotFilename {
                try vm.wrapped?.reloadScreenshotFromFile()
            }
        }

        private func _handshake(parameters: M.ServerHandshake.Request) async throws -> M.ServerHandshake.Reply {
            let serverPassword = await server.serverPassword
            if await server.isServerPasswordRequired && !serverPassword.isEmpty {
                if serverPassword == parameters.password {
                    isAuthenticated = true
                }
            } else {
                isAuthenticated = true
            }
            return .init(version: UTMRemoteMessageServer.version, isAuthenticated: isAuthenticated, capabilities: .current, model: MacDevice.current.model)
        }

        private func _listVirtualMachines(parameters: M.ListVirtualMachines.Request) async throws -> M.ListVirtualMachines.Reply {
            let ids = await Task { @MainActor in
                data.virtualMachines.map({ $0.id })
            }.value
            return .init(ids: ids)
        }

        private func _reorderVirtualMachines(parameters: M.ReorderVirtualMachines.Request) async throws -> M.ReorderVirtualMachines.Reply {
            await Task { @MainActor in
                let vms = data.virtualMachines
                let source = parameters.ids.reduce(into: IndexSet(), { indexSet, id in
                    if let index = vms.firstIndex(where: { $0.id == id }) {
                        indexSet.insert(index)
                    }
                })
                let destination = min(max(0, parameters.offset), vms.count)
                data.listMove(fromOffsets: source, toOffset: destination)
                return .init()
            }.value
        }

        private func _getVirtualMachineInformation(parameters: M.GetVirtualMachineInformation.Request) async throws -> M.GetVirtualMachineInformation.Reply {
            let informations = try await Task { @MainActor in
                try parameters.ids.map { id in
                    let vm = try findVM(withId: id, allowNotLoaded: true)
                    let mountedDrives = vm.registryEntry?.externalDrives.mapValues({ $0.path }) ?? [:]
                    let isTakeoverAllowed = data.vmWindows[vm] is VMRemoteSessionState && (vm.state == .started || vm.state == .paused)
                    return M.VirtualMachineInformation(id: vm.id,
                                                       name: vm.detailsTitleLabel,
                                                       path: vm.pathUrl.path,
                                                       isShortcut: vm.isShortcut,
                                                       isSuspended: vm.registryEntry?.isSuspended ?? false,
                                                       isTakeoverAllowed: isTakeoverAllowed,
                                                       backend: vm.wrapped is UTMQemuVirtualMachine ? .qemu : .unknown,
                                                       state: vm.wrapped?.state ?? .stopped,
                                                       mountedDrives: mountedDrives)
                }
            }.value
            return .init(informations: informations)
        }

        private func _getQEMUConfiguration(parameters: M.GetQEMUConfiguration.Request) async throws -> M.GetQEMUConfiguration.Reply {
            let vm = try await findVM(withId: parameters.id)
            if let config = await vm.config as? UTMQemuConfiguration {
                return .init(configuration: config)
            } else {
                throw ServerError.invalidBackend
            }
        }

        private func _getPackageSize(parameters: M.GetPackageSize.Request) async throws -> M.GetPackageSize.Reply {
            let vm = try await findVM(withId: parameters.id)
            let size = await data.computeSize(for: vm)
            return .init(size: size)
        }

        private func _getPackageFile(parameters: M.GetPackageFile.Request) async throws -> M.GetPackageFile.Reply {
            let vm = try await findVM(withId: parameters.id)
            let fm = FileManager.default
            let pathUrl = await vm.pathUrl
            let fileUrl = parameters.relativePathComponents.reduce(pathUrl, { $0.appendingPathComponent($1) })
            guard let lastModified = try fm.attributesOfItem(atPath: fileUrl.path)[.modificationDate] as? Date else {
                throw ServerError.failedToAccessFile
            }
            if let requestLastModified = parameters.lastModified {
                if lastModified.distance(to: requestLastModified).rounded(.towardZero) == 0 {
                    return .init(data: nil, lastModified: lastModified)
                }
            }
            guard let data = fm.contents(atPath: fileUrl.path) else {
                throw ServerError.failedToAccessFile
            }
            return .init(data: data, lastModified: lastModified)
        }

        private func _sendPackageFile(parameters: M.SendPackageFile.Request) async throws -> M.SendPackageFile.Reply {
            let vm = try await findVM(withId: parameters.id)
            let fm = FileManager.default
            let pathUrl = await vm.pathUrl
            let fileUrl = parameters.relativePathComponents.reduce(pathUrl, { $0.appendingPathComponent($1) })
            try? fm.removeItem(at: fileUrl)
            guard fm.createFile(atPath: fileUrl.path, contents: parameters.data, attributes: [.modificationDate: parameters.lastModified]) else {
                throw ServerError.failedToAccessFile
            }
            try await packageFileHasChanged(for: vm, relativePathComponents: parameters.relativePathComponents)
            return .init()
        }

        private func _deletePackageFile(parameters: M.DeletePackageFile.Request) async throws -> M.DeletePackageFile.Reply {
            let vm = try await findVM(withId: parameters.id)
            let fm = FileManager.default
            let pathUrl = await vm.pathUrl
            let fileUrl = parameters.relativePathComponents.reduce(pathUrl, { $0.appendingPathComponent($1) })
            try fm.removeItem(at: fileUrl)
            try await packageFileHasChanged(for: vm, relativePathComponents: parameters.relativePathComponents)
            return .init()
        }

        private func _mountGuestToolsOnVirtualMachine(parameters: M.MountGuestToolsOnVirtualMachine.Request) async throws -> M.MountGuestToolsOnVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            if let wrapped = await vm.wrapped {
                try await data.mountSupportTools(for: wrapped)
            }
            return .init()
        }

        private func _startVirtualMachine(parameters: M.StartVirtualMachine.Request) async throws -> M.StartVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            let serverInfo = try await data.startRemote(vm: vm, options: parameters.options, forClient: client)
            return .init(serverInfo: serverInfo)
        }

        private func _stopVirtualMachine(parameters: M.StopVirtualMachine.Request) async throws -> M.StopVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.stop(usingMethod: parameters.method)
            return .init()
        }

        private func _restartVirtualMachine(parameters: M.RestartVirtualMachine.Request) async throws -> M.RestartVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.restart()
            return .init()
        }

        private func _pauseVirtualMachine(parameters: M.PauseVirtualMachine.Request) async throws -> M.PauseVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.pause()
            return .init()
        }

        private func _resumeVirtualMachine(parameters: M.ResumeVirtualMachine.Request) async throws -> M.ResumeVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.resume()
            return .init()
        }

        private func _saveSnapshotVirtualMachine(parameters: M.SaveSnapshotVirtualMachine.Request) async throws -> M.SaveSnapshotVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.saveSnapshot(name: parameters.name)
            return .init()
        }

        private func _deleteSnapshotVirtualMachine(parameters: M.DeleteSnapshotVirtualMachine.Request) async throws -> M.DeleteSnapshotVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.deleteSnapshot(name: parameters.name)
            return .init()
        }

        private func _restoreSnapshotVirtualMachine(parameters: M.RestoreSnapshotVirtualMachine.Request) async throws -> M.RestoreSnapshotVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            try await vm.wrapped!.restoreSnapshot(name: parameters.name)
            return .init()
        }

        private func _changePointerTypeVirtualMachine(parameters: M.ChangePointerTypeVirtualMachine.Request) async throws -> M.ChangePointerTypeVirtualMachine.Reply {
            let vm = try await findVM(withId: parameters.id)
            guard let wrapped = await vm.wrapped as? UTMQemuVirtualMachine else {
                throw ServerError.invalidBackend
            }
            try await wrapped.changeInputTablet(parameters.isTabletMode)
            return .init()
        }
    }
}

extension UTMRemoteServer {
    class Remote: Identifiable {
        typealias M = UTMRemoteMessageClient
        fileprivate(set) var peer: Peer<UTMRemoteMessageServer>!
        let id = UUID()

        func close() {
            peer.close()
        }

        func handshake() async throws {
            guard try await _handshake(parameters: .init(version: UTMRemoteMessageClient.version)).version == UTMRemoteMessageClient.version else {
                throw ServerError.versionMismatch
            }
        }

        func listHasChanged(ids: [UUID]) async throws {
            try await _listHasChanged(parameters: .init(ids: ids))
        }

        func qemuConfigurationHasChanged(id: UUID, configuration: UTMQemuConfiguration) async throws {
            try await _qemuConfigurationHasChanged(parameters: .init(id: id, configuration: configuration))
        }

        func mountedDrivesHasChanged(id: UUID, mountedDrives: [String: String]) async throws {
            try await _mountedDrivesHasChanged(parameters: .init(id: id, mountedDrives: mountedDrives))
        }

        func virtualMachine(id: UUID, didTransitionToState state: UTMVirtualMachineState, isTakeoverAllowed: Bool) async throws {
            try await _virtualMachineDidTransition(parameters: .init(id: id, state: state, isTakeoverAllowed: isTakeoverAllowed))
        }

        func virtualMachine(id: UUID, didErrorWithMessage message: String) async throws {
            try await _virtualMachineDidError(parameters: .init(id: id, errorMessage: message))
        }

        private func _handshake(parameters: M.ClientHandshake.Request) async throws -> M.ClientHandshake.Reply {
            try await M.ClientHandshake.send(parameters, to: peer)
        }

        @discardableResult
        private func _listHasChanged(parameters: M.ListHasChanged.Request) async throws -> M.ListHasChanged.Reply {
            try await M.ListHasChanged.send(parameters, to: peer)
        }

        @discardableResult
        private func _qemuConfigurationHasChanged(parameters: M.QEMUConfigurationHasChanged.Request) async throws -> M.QEMUConfigurationHasChanged.Reply {
            try await M.QEMUConfigurationHasChanged.send(parameters, to: peer)
        }

        @discardableResult
        private func _mountedDrivesHasChanged(parameters: M.MountedDrivesHasChanged.Request) async throws -> M.MountedDrivesHasChanged.Reply {
            try await M.MountedDrivesHasChanged.send(parameters, to: peer)
        }

        @discardableResult
        private func _virtualMachineDidTransition(parameters: M.VirtualMachineDidTransition.Request) async throws -> M.VirtualMachineDidTransition.Reply {
            try await M.VirtualMachineDidTransition.send(parameters, to: peer)
        }

        @discardableResult
        private func _virtualMachineDidError(parameters: M.VirtualMachineDidError.Request) async throws -> M.VirtualMachineDidError.Reply {
            try await M.VirtualMachineDidError.send(parameters, to: peer)
        }
    }
}

extension UTMRemoteServer {
    enum ServerError: LocalizedError {
        case silentError(Error)
        case natReservationMismatch(Int)
        case notAuthenticated
        case versionMismatch
        case notFound(UUID)
        case invalidBackend
        case failedToAccessFile

        var errorDescription: String? {
            switch self {
            case .silentError(let error):
                return error.localizedDescription
            case .natReservationMismatch(let port):
                return String.localizedStringWithFormat(NSLocalizedString("Cannot reserve port %d for external access from NAT. Make sure no other device on the network has reserved it.", comment: "UTMRemoteServer"), port)
            case .notAuthenticated:
                return NSLocalizedString("Not authenticated.", comment: "UTMRemoteServer")
            case .versionMismatch:
                return NSLocalizedString("The client interface version does not match the server.", comment: "UTMRemoteServer")
            case .notFound(let id):
                return String.localizedStringWithFormat(NSLocalizedString("Cannot find VM with ID: %@", comment: "UTMRemoteServer"), id.uuidString)
            case .invalidBackend:
                return NSLocalizedString("Invalid backend.", comment: "UTMRemoteServer")
            case .failedToAccessFile:
                return NSLocalizedString("Failed to access file.", comment: "UTMRemoteServer")
            }
        }
    }
}

extension Connection {
    var fingerprint: [UInt8]? {
        return peerCertificateChain.first?.fingerprint()
    }
}
