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
        try Task.checkCancellation()
        let peer = Peer(connection: connection, localInterface: local)
        let remote = Remote(peer: peer)
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
                return .init()
            case .virtualMachineDidError:
                return .init()
            }
        }

        func handle(error: Error) {
            Task {
                await data.showErrorAlert(message: error.localizedDescription)
            }
        }

        private func _handshake(parameters: M.ClientHandshake.Request) async throws -> M.ClientHandshake.Reply {
            return .init(version: UTMRemoteMessageClient.version)
        }
    }
}

extension UTMRemoteClient {
    class Remote {
        typealias M = UTMRemoteMessageServer
        private let peer: Peer<UTMRemoteMessageClient>

        init(peer: Peer<UTMRemoteMessageClient>) {
            self.peer = peer
        }

        func close() {
            peer.close()
        }

        func handshake() async throws {
            guard try await _handshake(parameters: .init(version: UTMRemoteMessageServer.version)).version == UTMRemoteMessageServer.version else {
                throw ClientError.versionMismatch
            }
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
    }
}

extension UTMRemoteClient {
    enum ConnectionError: LocalizedError {
        case cannotFindEndpoint
        case passwordRequired
        case passwordInvalid

        var errorDescription: String? {
            switch self {
            case .cannotFindEndpoint:
                return NSLocalizedString("The server has disappeared.", comment: "UTMRemoteClient")
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
