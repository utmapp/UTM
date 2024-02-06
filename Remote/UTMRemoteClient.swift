//
// Copyright © 2024 osy. All rights reserved.
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
import Network
import SwiftConnect

let service = "_utm_server._tcp"

actor UTMRemoteClient {
    let state: State
    private let keyManager = UTMRemoteKeyManager(forClient: true)
    private var local: Local

    private var scanTask: Task<Void, Error>?
    private var endpoints: [String: NWEndpoint] = [:]

    private(set) var server: Remote!

    @MainActor
    init(data: UTMRemoteData) {
        self.state = State()
        self.local = Local(data: data)
    }

    private func withErrorAlert(_ body: () async throws -> Void) async {
        do {
            try await body()
        } catch {
            await state.showErrorAlert(error.localizedDescription)
        }
    }

    func startScanning() {
        scanTask = Task {
            await withErrorAlert {
                for try await endpoints in Connection.endpoints(forServiceType: service) {
                    await self.didFindEndpoints(endpoints)
                }
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    func didFindEndpoints(_ endpoints: [NWEndpoint]) async {
        self.endpoints = endpoints.reduce(into: [String: NWEndpoint]()) { map, endpoint in
            map[endpoint.debugDescription] = endpoint
        }
        let servers = endpoints.compactMap { endpoint in
            switch endpoint {
            case .hostPort(let host, _):
                return State.Server(hostname: host.debugDescription, name: host.debugDescription, lastSeen: Date())
            case .service(let name, _, _, _):
                return State.Server(hostname: endpoint.debugDescription, name: name, lastSeen: Date())
            default:
                return nil
            }
        }
        await state.updateFoundServers(servers)
    }

    func connect(_ server: State.Server, shouldSaveDetails: Bool = false) async throws {
        guard let endpoint = endpoints[server.hostname] else {
            throw ConnectionError.cannotFindEndpoint
        }
        try await keyManager.load()
        let connection = try await Connection.init(endpoint: endpoint, identity: keyManager.identity) { certs in
            return true
        }
        guard let host = connection.connection.currentPath?.remoteEndpoint?.hostname else {
            throw ConnectionError.cannotDetermineHost
        }
        try Task.checkCancellation()
        let peer = Peer(connection: connection, localInterface: local)
        let remote = Remote(peer: peer, host: host)
        do {
            try await remote.handshake()
        } catch {
            peer.close()
            throw error
        }
        self.server = remote
        await state.setConnected(true)
    }
}

extension UTMRemoteClient {
    @MainActor
    class State: ObservableObject {
        typealias ServerFingerprint = String
        struct Server: Codable, Identifiable, Hashable {
            let hostname: String
            var fingerprint: ServerFingerprint?
            var name: String
            var lastSeen: Date
            var password: String?

            var id: String {
                hostname
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(hostname)
            }

            static func == (lhs: Server, rhs: Server) -> Bool {
                lhs.hashValue == rhs.hashValue
            }
        }

        struct AlertMessage: Identifiable {
            let id = UUID()
            let message: String
        }

        @Published var savedServers: [Server] {
            didSet {
                UserDefaults.standard.setValue(try! savedServers.propertyList(), forKey: "TrustedServers")
            }
        }

        @Published var foundServers: [Server] = []

        @Published var isScanning: Bool = false

        @Published private(set) var isConnected: Bool = false

        @Published var alertMessage: AlertMessage?

        init() {
            var _savedServers = Array<Server>()
            if let array = UserDefaults.standard.array(forKey: "TrustedServers") {
                if let servers = try? Array<Server>(fromPropertyList: array) {
                    _savedServers = servers
                }
            }
            self.savedServers = _savedServers
        }

        func showErrorAlert(_ message: String) {
            alertMessage = AlertMessage(message: message)
        }

        func updateFoundServers(_ servers: [Server]) {
            foundServers = servers
        }

        fileprivate func setConnected(_ connected: Bool) {
            isConnected = connected
        }
    }
}

extension UTMRemoteClient {
    class Local: LocalInterface {
        typealias M = UTMRemoteMessageClient

        private let data: UTMRemoteData

        init(data: UTMRemoteData) {
            self.data = data
        }

        func handle(message: M, data: Data) async throws -> Data {
            switch message {
            case .clientHandshake:
                return try await _handshake(parameters: .decode(data)).encode()
            case .listHasChangedOrder:
                return .init()
            case .QEMUConfigurationHasChanged:
                return .init()
            case .packageFileHasChanged:
                return .init()
            case .virtualMachineDidTransition:
                return try await _virtualMachineDidTransition(parameters: .decode(data)).encode()
            case .virtualMachineDidError:
                return try await _virtualMachineDidError(parameters: .decode(data)).encode()
            }
        }

        func handle(error: Error) {
            Task {
                await data.showErrorAlert(message: error.localizedDescription)
            }
        }

        private func _handshake(parameters: M.ClientHandshake.Request) async throws -> M.ClientHandshake.Reply {
            return .init(version: UTMRemoteMessageClient.version, capabilities: .current)
        }

        private func _virtualMachineDidTransition(parameters: M.VirtualMachineDidTransition.Request) async throws -> M.VirtualMachineDidTransition.Reply {
            await data.remoteVirtualMachineDidTransition(id: parameters.id, state: parameters.state)
            return .init()
        }

        private func _virtualMachineDidError(parameters: M.VirtualMachineDidError.Request) async throws -> M.VirtualMachineDidError.Reply {
            await data.remoteVirtualMachineDidError(id: parameters.id, message: parameters.errorMessage)
            return .init()
        }
    }
}

extension UTMRemoteClient {
    class Remote {
        typealias M = UTMRemoteMessageServer
        private let peer: Peer<UTMRemoteMessageClient>
        let host: String
        private(set) var capabilities: UTMCapabilities?

        init(peer: Peer<UTMRemoteMessageClient>, host: String) {
            self.peer = peer
            self.host = host
        }

        func close() {
            peer.close()
        }

        func handshake() async throws {
            let reply = try await _handshake(parameters: .init(version: UTMRemoteMessageServer.version))
            guard reply.version == UTMRemoteMessageServer.version else {
                throw ClientError.versionMismatch
            }
            capabilities = reply.capabilities
        }

        func listVirtualMachines() async throws -> [M.ListVirtualMachines.Information] {
            try await _listVirtualMachines(parameters: .init()).items
        }

        func getQEMUConfiguration(for id: UUID) async throws -> UTMQemuConfiguration {
            try await _getQEMUConfiguration(parameters: .init(id: id)).configuration
        }

        func startVirtualMachine(id: UUID, options: UTMVirtualMachineStartOptions) async throws -> UInt16 {
            try await _startVirtualMachine(parameters: .init(id: id, options: options)).spiceServerPort
        }

        func stopVirtualMachine(id: UUID, method: UTMVirtualMachineStopMethod) async throws {
            try await _stopVirtualMachine(parameters: .init(id: id, method: method))
        }

        func restartVirtualMachine(id: UUID) async throws {
            try await _restartVirtualMachine(parameters: .init(id: id))
        }

        func pauseVirtualMachine(id: UUID) async throws {
            try await _pauseVirtualMachine(parameters: .init(id: id))
        }

        func resumeVirtualMachine(id: UUID) async throws {
            try await _resumeVirtualMachine(parameters: .init(id: id))
        }

        func saveSnapshotVirtualMachine(id: UUID, name: String?) async throws {
            try await _saveSnapshotVirtualMachine(parameters: .init(id: id, name: name))
        }

        func deleteSnapshotVirtualMachine(id: UUID, name: String?) async throws {
            try await _deleteSnapshotVirtualMachine(parameters: .init(id: id, name: name))
        }

        func restoreSnapshotVirtualMachine(id: UUID, name: String?) async throws {
            try await _restoreSnapshotVirtualMachine(parameters: .init(id: id, name: name))
        }

        func changePointerTypeVirtualMachine(id: UUID, toTabletMode tablet: Bool) async throws {
            try await _changePointerTypeVirtualMachine(parameters: .init(id: id, isTabletMode: tablet))
        }

        private func _handshake(parameters: M.ServerHandshake.Request) async throws -> M.ServerHandshake.Reply {
            try await M.ServerHandshake.send(parameters, to: peer)
        }

        private func _listVirtualMachines(parameters: M.ListVirtualMachines.Request) async throws -> M.ListVirtualMachines.Reply {
            try await M.ListVirtualMachines.send(parameters, to: peer)
        }

        private func _getQEMUConfiguration(parameters: M.GetQEMUConfiguration.Request) async throws -> M.GetQEMUConfiguration.Reply {
            try await M.GetQEMUConfiguration.send(parameters, to: peer)
        }

        private func _startVirtualMachine(parameters: M.StartVirtualMachine.Request) async throws -> M.StartVirtualMachine.Reply {
            try await M.StartVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _stopVirtualMachine(parameters: M.StopVirtualMachine.Request) async throws -> M.StopVirtualMachine.Reply {
            try await M.StopVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _restartVirtualMachine(parameters: M.RestartVirtualMachine.Request) async throws -> M.RestartVirtualMachine.Reply {
            try await M.RestartVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _pauseVirtualMachine(parameters: M.PauseVirtualMachine.Request) async throws -> M.PauseVirtualMachine.Reply {
            try await M.PauseVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _resumeVirtualMachine(parameters: M.ResumeVirtualMachine.Request) async throws -> M.ResumeVirtualMachine.Reply {
            try await M.ResumeVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _saveSnapshotVirtualMachine(parameters: M.SaveSnapshotVirtualMachine.Request) async throws -> M.SaveSnapshotVirtualMachine.Reply {
            try await M.SaveSnapshotVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _deleteSnapshotVirtualMachine(parameters: M.DeleteSnapshotVirtualMachine.Request) async throws -> M.DeleteSnapshotVirtualMachine.Reply {
            try await M.DeleteSnapshotVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _restoreSnapshotVirtualMachine(parameters: M.RestoreSnapshotVirtualMachine.Request) async throws -> M.RestoreSnapshotVirtualMachine.Reply {
            try await M.RestoreSnapshotVirtualMachine.send(parameters, to: peer)
        }

        @discardableResult
        private func _changePointerTypeVirtualMachine(parameters: M.ChangePointerTypeVirtualMachine.Request) async throws -> M.ChangePointerTypeVirtualMachine.Reply {
            try await M.ChangePointerTypeVirtualMachine.send(parameters, to: peer)
        }
    }
}

extension UTMRemoteClient {
    enum ConnectionError: LocalizedError {
        case cannotFindEndpoint
        case cannotDetermineHost
        case passwordRequired
        case passwordInvalid

        var errorDescription: String? {
            switch self {
            case .cannotFindEndpoint:
                return NSLocalizedString("The server has disappeared.", comment: "UTMRemoteClient")
            case .cannotDetermineHost:
                return NSLocalizedString("Failed to determine host name.", comment: "UTMRemoteClient")
            case .passwordRequired:
                return NSLocalizedString("Password is required.", comment: "UTMRemoteClient")
            case .passwordInvalid:
                return NSLocalizedString("Password is incorrect.", comment: "UTMRemoteClient")
            }
        }
    }

    enum ClientError: LocalizedError {
        case versionMismatch

        var errorDescription: String? {
            switch self {
            case .versionMismatch:
                return NSLocalizedString("The server interface version does not match the client.", comment: "UTMRemoteClient")
            }
        }
    }
}
