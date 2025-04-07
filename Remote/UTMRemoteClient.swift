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
    private let connectionQueue = DispatchQueue(label: "UTM Remote Client Connection")
    private var local: Local

    private var scanTask: Task<Void, Error>?

    private(set) var server: Remote!

    nonisolated var fingerprint: [UInt8] {
        keyManager.fingerprint ?? []
    }

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
            await MainActor.run {
                state.isScanning = true
            }
            await withErrorAlert {
                defer {
                    Task { @MainActor in
                        state.isScanning = false
                    }
                }
                for try await results in Connection.browse(forServiceType: service) {
                    await self.didFindResults(results)
                }
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    func refresh() {
        stopScanning()
        startScanning()
    }

    func didFindResults(_ results: Set<NWBrowser.Result>) async {
        let servers = results.compactMap { result in
            let model: String?
            if case .bonjour(let txtRecord) = result.metadata,
                case .string(let value) = txtRecord.getEntry(for: "Model") {
                model = value
            } else {
                model = nil
            }
            switch result.endpoint {
            case .service(let name, _, _, _):
                return State.DiscoveredServer(hostname: result.endpoint.debugDescription, model: model, name: name, endpoint: result.endpoint)
            default:
                return nil
            }
        }
        await state.updateFoundServers(servers)
    }

    func connect(_ server: State.SavedServer) async throws {
        var isSuccessful = false
        let endpoint = server.endpoint ?? NWEndpoint.hostPort(host: .init(server.hostname), port: .init(integerLiteral: UInt16(server.port ?? 0)))
        try await keyManager.load()
        let connection = try await Connection(endpoint: endpoint, connectionQueue: connectionQueue, identity: keyManager.identity) { connection, error in
            Task {
                do {
                    try await self.local.data.reconnect(to: server)
                } catch {
                    // reconnect failed
                    await self.state.setConnected(false)
                    await self.state.showErrorAlert(error.localizedDescription)
                }
            }
        }
        defer {
            if !isSuccessful {
                connection.close()
            }
        }
        guard let host = connection.connection.currentPath?.remoteEndpoint?.hostname else {
            throw ConnectionError.cannotDetermineHost
        }
        guard let fingerprint = connection.peerCertificateChain.first?.fingerprint() else {
            throw ConnectionError.cannotFindFingerprint
        }
        if server.fingerprint.isEmpty {
            throw ConnectionError.fingerprintUntrusted(fingerprint)
        } else if server.fingerprint != fingerprint {
            throw ConnectionError.fingerprintMismatch(fingerprint)
        }
        try Task.checkCancellation()
        let peer = Peer(connection: connection, localInterface: local)
        let remote = Remote(peer: peer, host: host)
        let (isAuthenticated, device) = try await remote.handshake(password: server.password)
        if !isAuthenticated {
            if server.password == nil {
                throw ConnectionError.passwordRequired
            } else {
                throw ConnectionError.passwordInvalid
            }
        }
        self.server = remote
        var server = server
        await state.setConnected(true)
        if !server.shouldSavePassword {
            server.password = nil
        }
        if server.name.isEmpty {
            server.name = server.hostname
        }
        server.lastSeen = Date()
        server.model = device.model
        await state.save(server: server)
        isSuccessful = true
    }
}

extension UTMRemoteClient {
    @MainActor
    class State: ObservableObject {
        typealias ServerFingerprint = [UInt8]

        struct DiscoveredServer: Identifiable {
            let hostname: String
            var model: String?
            var name: String
            var endpoint: NWEndpoint

            var id: String {
                hostname
            }
        }

        struct SavedServer: Codable, Identifiable {
            var fingerprint: ServerFingerprint
            var hostname: String
            var port: Int?
            var model: String?
            var name: String
            var lastSeen: Date
            var password: String?
            var endpoint: NWEndpoint?
            var shouldSavePassword: Bool = false

            private enum CodingKeys: String, CodingKey {
                case fingerprint, hostname, port, model, name, lastSeen, password
            }

            var id: ServerFingerprint {
                fingerprint
            }

            var isAvailable: Bool {
                endpoint != nil || (port != nil && port != 0)
            }

            init() {
                self.hostname = ""
                self.name = ""
                self.lastSeen = Date()
                self.fingerprint = []
            }

            init(from discovered: DiscoveredServer) {
                self.hostname = discovered.hostname
                self.model = discovered.model
                self.name = discovered.name
                self.lastSeen = Date()
                self.endpoint = discovered.endpoint
                self.fingerprint = []
            }
        }

        struct AlertMessage: Identifiable {
            let id = UUID()
            let message: String
        }

        @Published var savedServers: [SavedServer] {
            didSet {
                UserDefaults.standard.setValue(try! savedServers.propertyList(), forKey: "TrustedServers")
            }
        }

        @Published var foundServers: [DiscoveredServer] = []

        @Published var isScanning: Bool = false

        @Published private(set) var isConnected: Bool = false

        @Published var alertMessage: AlertMessage?

        init() {
            var _savedServers = Array<SavedServer>()
            if let array = UserDefaults.standard.array(forKey: "TrustedServers") {
                if let servers = try? Array<SavedServer>(fromPropertyList: array) {
                    _savedServers = servers
                }
            }
            self.savedServers = _savedServers
        }

        func showErrorAlert(_ message: String) {
            alertMessage = AlertMessage(message: message)
        }

        func updateFoundServers(_ servers: [DiscoveredServer]) {
            for idx in savedServers.indices {
                savedServers[idx].endpoint = nil
            }
            foundServers = servers.filter { server in
                if let idx = savedServers.firstIndex(where: { $0.port == nil && $0.hostname == server.hostname }) {
                    savedServers[idx].endpoint = server.endpoint
                    return false
                } else {
                    return true
                }
            }
        }

        func save(server: SavedServer) {
            if let idx = savedServers.firstIndex(where: { $0.fingerprint == server.fingerprint }) {
                savedServers[idx] = server
            } else {
                savedServers.append(server)
            }
        }

        func delete(server: SavedServer) {
            savedServers.removeAll(where: { $0.fingerprint == server.fingerprint })
        }

        fileprivate func setConnected(_ connected: Bool) {
            isConnected = connected
        }
    }
}

extension UTMRemoteClient {
    class Local: LocalInterface {
        typealias M = UTMRemoteMessageClient

        fileprivate let data: UTMRemoteData

        init(data: UTMRemoteData) {
            self.data = data
        }

        func handle(message: M, data: Data) async throws -> Data {
            switch message {
            case .clientHandshake:
                return try await _handshake(parameters: .decode(data)).encode()
            case .listHasChanged:
                return try await _listHasChanged(parameters: .decode(data)).encode()
            case .qemuConfigurationHasChanged:
                return try await _qemuConfigurationHasChanged(parameters: .decode(data)).encode()
            case .mountedDrivesHasChanged:
                return try await _mountedDrivesHasChanged(parameters: .decode(data)).encode()
            case .virtualMachineDidTransition:
                return try await _virtualMachineDidTransition(parameters: .decode(data)).encode()
            case .virtualMachineDidError:
                return try await _virtualMachineDidError(parameters: .decode(data)).encode()
            }
        }

        private func _handshake(parameters: M.ClientHandshake.Request) async throws -> M.ClientHandshake.Reply {
            return .init(version: UTMRemoteMessageClient.version, capabilities: .current)
        }

        private func _listHasChanged(parameters: M.ListHasChanged.Request) async throws -> M.ListHasChanged.Reply {
            await data.remoteListHasChanged(ids: parameters.ids)
            return .init()
        }

        private func _qemuConfigurationHasChanged(parameters: M.QEMUConfigurationHasChanged.Request) async throws -> M.QEMUConfigurationHasChanged.Reply {
            await data.remoteQemuConfigurationHasChanged(id: parameters.id, configuration: parameters.configuration)
            return .init()
        }

        private func _mountedDrivesHasChanged(parameters: M.MountedDrivesHasChanged.Request) async throws -> M.MountedDrivesHasChanged.Reply {
            await data.remoteMountedDrivesHasChanged(id: parameters.id, mountedDrives: parameters.mountedDrives)
            return .init()
        }

        private func _virtualMachineDidTransition(parameters: M.VirtualMachineDidTransition.Request) async throws -> M.VirtualMachineDidTransition.Reply {
            await data.remoteVirtualMachineDidTransition(id: parameters.id, state: parameters.state, isTakeoverAllowed: parameters.isTakeoverAllowed)
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

        func handshake(password: String?) async throws -> (isAuthenticated: Bool, device: MacDevice) {
            let reply = try await _handshake(parameters: .init(version: UTMRemoteMessageServer.version, password: password))
            guard reply.version == UTMRemoteMessageServer.version else {
                throw ClientError.versionMismatch
            }
            capabilities = reply.capabilities
            return (isAuthenticated: reply.isAuthenticated, device: MacDevice(model: reply.model))
        }

        func listVirtualMachines() async throws -> [UUID] {
            try await _listVirtualMachines(parameters: .init()).ids
        }

        func reorderVirtualMachines(fromIds ids: [UUID], toOffset offset: Int) async throws {
            try await _reorderVirtualMachines(parameters: .init(ids: ids, offset: offset))
        }

        func getVirtualMachineInformation(for ids: [UUID]) async throws -> [M.VirtualMachineInformation] {
            try await _getVirtualMachineInformation(parameters: .init(ids: ids)).informations
        }

        func getQEMUConfiguration(for id: UUID) async throws -> UTMQemuConfiguration {
            try await _getQEMUConfiguration(parameters: .init(id: id)).configuration
        }

        func getPackageSize(for id: UUID) async throws -> Int64 {
            try await _getPackageSize(parameters: .init(id: id)).size
        }

        func getPackageFile(for id: UUID, relativePathComponents: [String]) async throws -> URL {
            let fm = FileManager.default
            let packageUrl = try packageUrl(for: id)
            let fileUrl = packageUrl.appendingPathComponent(relativePathComponents.joined(separator: "_"))
            var lastModified: Date?
            if fm.fileExists(atPath: fileUrl.path) {
                lastModified = try? fm.attributesOfItem(atPath: fileUrl.path)[.modificationDate] as? Date
            }
            let reply = try await _getPackageFile(parameters: .init(id: id, relativePathComponents: relativePathComponents, lastModified: lastModified))
            if let data = reply.data {
                fm.createFile(atPath: fileUrl.path, contents: data, attributes: [.modificationDate: reply.lastModified])
            }
            return fileUrl
        }

        func sendPackageFile(for id: UUID, relativePathComponents: [String], data: Data) async throws {
            let fm = FileManager.default
            let packageUrl = try packageUrl(for: id)
            let fileUrl = packageUrl.appendingPathComponent(relativePathComponents.joined(separator: "_"))
            guard fm.createFile(atPath: fileUrl.path, contents: data) else {
                throw ConnectionError.failedToAccessFile
            }
            guard let lastModified = try fm.attributesOfItem(atPath: fileUrl.path)[.modificationDate] as? Date else {
                throw ConnectionError.failedToAccessFile
            }
            try await _sendPackageFile(parameters: .init(id: id, relativePathComponents: relativePathComponents, lastModified: lastModified, data: data))
        }

        func deletePackageFile(for id: UUID, relativePathComponents: [String]) async throws {
            let fm = FileManager.default
            let packageUrl = try packageUrl(for: id)
            let fileUrl = packageUrl.appendingPathComponent(relativePathComponents.joined(separator: "_"))
            try fm.removeItem(at: fileUrl)
            try await _deletePackageFile(parameters: .init(id: id, relativePathComponents: relativePathComponents))
        }

        func mountGuestToolsOnVirtualMachine(id: UUID) async throws {
            try await _mountGuestToolsOnVirtualMachine(parameters: .init(id: id))
        }

        func startVirtualMachine(id: UUID, options: UTMVirtualMachineStartOptions) async throws -> UTMRemoteMessageServer.StartVirtualMachine.ServerInformation {
            return try await _startVirtualMachine(parameters: .init(id: id, options: options)).serverInfo
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

        private func packageUrl(for id: UUID) throws -> URL {
            let fm = FileManager.default
            let cacheUrl = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let packageUrl = cacheUrl.appendingPathComponent(id.uuidString)
            if !fm.fileExists(atPath: packageUrl.path) {
                try fm.createDirectory(at: packageUrl, withIntermediateDirectories: false)
            }
            return packageUrl
        }

        private func _handshake(parameters: M.ServerHandshake.Request) async throws -> M.ServerHandshake.Reply {
            try await M.ServerHandshake.send(parameters, to: peer)
        }

        private func _listVirtualMachines(parameters: M.ListVirtualMachines.Request) async throws -> M.ListVirtualMachines.Reply {
            try await M.ListVirtualMachines.send(parameters, to: peer)
        }

        @discardableResult
        private func _reorderVirtualMachines(parameters: M.ReorderVirtualMachines.Request) async throws -> M.ReorderVirtualMachines.Reply {
            try await M.ReorderVirtualMachines.send(parameters, to: peer)
        }

        private func _getVirtualMachineInformation(parameters: M.GetVirtualMachineInformation.Request) async throws -> M.GetVirtualMachineInformation.Reply {
            try await M.GetVirtualMachineInformation.send(parameters, to: peer)
        }

        private func _getQEMUConfiguration(parameters: M.GetQEMUConfiguration.Request) async throws -> M.GetQEMUConfiguration.Reply {
            try await M.GetQEMUConfiguration.send(parameters, to: peer)
        }

        private func _getPackageSize(parameters: M.GetPackageSize.Request) async throws -> M.GetPackageSize.Reply {
            try await M.GetPackageSize.send(parameters, to: peer)
        }

        private func _getPackageFile(parameters: M.GetPackageFile.Request) async throws -> M.GetPackageFile.Reply {
            try await M.GetPackageFile.send(parameters, to: peer)
        }

        @discardableResult
        private func _sendPackageFile(parameters: M.SendPackageFile.Request) async throws -> M.SendPackageFile.Reply {
            try await M.SendPackageFile.send(parameters, to: peer)
        }

        @discardableResult
        private func _deletePackageFile(parameters: M.DeletePackageFile.Request) async throws -> M.DeletePackageFile.Reply {
            try await M.DeletePackageFile.send(parameters, to: peer)
        }

        @discardableResult
        private func _mountGuestToolsOnVirtualMachine(parameters: M.MountGuestToolsOnVirtualMachine.Request) async throws -> M.MountGuestToolsOnVirtualMachine.Reply {
            try await M.MountGuestToolsOnVirtualMachine.send(parameters, to: peer)
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
        case cannotDetermineHost
        case cannotFindFingerprint
        case passwordRequired
        case passwordInvalid
        case fingerprintUntrusted(State.ServerFingerprint)
        case fingerprintMismatch(State.ServerFingerprint)
        case failedToAccessFile

        var errorDescription: String? {
            switch self {
            case .cannotDetermineHost:
                return NSLocalizedString("Failed to determine host name.", comment: "UTMRemoteClient")
            case .cannotFindFingerprint:
                return NSLocalizedString("Failed to get host fingerprint.", comment: "UTMRemoteClient")
            case .passwordRequired:
                return NSLocalizedString("Password is required.", comment: "UTMRemoteClient")
            case .passwordInvalid:
                return NSLocalizedString("Password is incorrect.", comment: "UTMRemoteClient")
            case .fingerprintUntrusted(_):
                return NSLocalizedString("This host is not yet trusted. You should verify that the fingerprints match what is displayed on the host and then select Trust to continue.", comment: "UTMRemoteClient")
            case .fingerprintMismatch(_):
                return String.localizedStringWithFormat(NSLocalizedString("The host fingerprint does not match the saved value. This means that UTM Server was reset, a different host is using the same name, or an attacker is pretending to be the host. For your protection, you need to delete this saved host to continue.", comment: "UTMRemoteClient"))
            case .failedToAccessFile:
                return NSLocalizedString("Failed to access file.", comment: "UTMRemoteClient")
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

extension Connection.ConnectionError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .localNetworkDenied:
            return NSLocalizedString("Please allow this app to access your local network when prompted or in Settings.", comment: "UTMRemoteClient")
        }
    }
}
