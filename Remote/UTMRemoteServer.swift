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
import SwiftConnect
import UserNotifications

let service = "_utm_server._tcp"

actor UTMRemoteServer {
    private let data: UTMData
    private let keyManager = UTMRemoteKeyManager(forClient: false)
    private let center = UNUserNotificationCenter.current()
    let state: State

    private var cancellables = Set<AnyCancellable>()
    private var notificationDelegate: NotificationDelegate?
    private var listener: Task<Void, Error>?
    private var pendingConnections: [State.ClientFingerprint: Connection] = [:]
    private var establishedConnections: [State.ClientFingerprint: Connection] = [:]

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
            listener = Task {
                await withErrorNotification {
                    for try await connection in Connection.advertise(forServiceType: service, identity: keyManager.identity) {
                        await withErrorNotification {
                            let connection = try await Connection(connection: connection)
                            await newRemoteConnection(connection)
                        }
                    }
                }
                await state.setServerActive(false)
            }
            await state.setServerActive(true)
        }
    }

    func stop() async {
        unregisterNotifications()
        listener?.cancel()
        listener = nil
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
        pendingConnections[fingerprint] = connection
        if await state.isApproved(fingerprint) {
            await notifyNewConnection(remoteAddress: remoteAddress, fingerprint: fingerprint)
            await establishConnection(connection)
        } else {
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
        for connectedClient in connectedClients {
            if let connection = establishedConnections.removeValue(forKey: connectedClient) {
                connection.close()
            }
        }
    }

    private func establishConnection(_ connection: Connection) async {
        guard let fingerprint = connection.peerCertificateChain.first?.fingerprint().hexString() else {
            connection.close()
            return
        }
        await withErrorNotification {
            await state.connect(fingerprint)
        }
    }

    private func resetServer() async {
        await withErrorNotification {
            try await keyManager.reset()
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
        } catch {
            logger.error("Error sending remote connection request: \(error.localizedDescription)")
        }
    }

    private func notifyError(_ error: Error) async {
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
