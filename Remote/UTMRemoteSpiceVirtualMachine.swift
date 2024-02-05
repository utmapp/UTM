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

final class UTMRemoteSpiceVirtualMachine: UTMSpiceVirtualMachine {
    struct Capabilities: UTMVirtualMachineCapabilities {
        var supportsProcessKill: Bool {
            true
        }

        var supportsSnapshots: Bool {
            true
        }

        var supportsScreenshots: Bool {
            true
        }

        var supportsDisposibleMode: Bool {
            true
        }

        var supportsRecoveryMode: Bool {
            false
        }

        var supportsRemoteSession: Bool {
            false
        }
    }

    static let capabilities = Capabilities()

    actor State {
        let vm: UTMRemoteSpiceVirtualMachine
        private(set) var state: UTMVirtualMachineState = .stopped {
            didSet {
                vm.state = state
            }
        }

        init(vm: UTMRemoteSpiceVirtualMachine) {
            self.vm = vm
        }

        func operation(before: UTMVirtualMachineState, during: UTMVirtualMachineState, after: UTMVirtualMachineState, body: () async throws -> Void) async throws {
            try await operation(before: [before], during: during, after: after, body: body)
        }

        func operation(before: Set<UTMVirtualMachineState>, during: UTMVirtualMachineState, after: UTMVirtualMachineState, body: () async throws -> Void) async throws {
            guard before.contains(state) else {
                throw VMError.operationInProgress
            }
            let previous = state
            state = during
            do {
                try await body()
            } catch {
                state = previous
                throw error
            }
            state = after
        }
    }

    private let server: UTMRemoteClient.Remote

    init(packageUrl: URL, configuration: UTMQemuConfiguration, isShortcut: Bool) throws {
        throw UTMVirtualMachineError.notImplemented
    }

    init(forRemoteServer server: UTMRemoteClient.Remote, remotePath: String, entry: UTMRegistryEntry, config: UTMQemuConfiguration) {
        self.pathUrl = URL(fileURLWithPath: remotePath)
        self.config = config
        self.registryEntry = entry
        self.server = server
        _state = State(vm: self)
    }

    private(set) var pathUrl: URL

    private(set) var isShortcut: Bool = false

    private(set) var isRunningAsDisposible: Bool = false

    weak var delegate: (UTMVirtualMachineDelegate)?

    var onConfigurationChange: (() -> Void)?
    
    var onStateChange: (() -> Void)?

    private(set) var config: UTMQemuConfiguration {
        willSet {
            onConfigurationChange?()
        }
    }

    private(set) var registryEntry: UTMRegistryEntry {
        willSet {
            onConfigurationChange?()
        }
    }

    private var _state: State!

    private(set) var state: UTMVirtualMachineState = .stopped {
        willSet {
            onStateChange?()
        }

        didSet {
            delegate?.virtualMachine(self, didTransitionToState: state)
        }
    }

    var screenshot: PlatformImage? {
        willSet {
            onStateChange?()
        }
    }

    private(set) var snapshotUnsupportedError: Error?

    weak var ioServiceDelegate: UTMSpiceIODelegate? {
        didSet {
            if let ioService = ioService {
                ioService.delegate = ioServiceDelegate
            }
        }
    }

    private(set) var ioService: UTMSpiceIO? {
        didSet {
            oldValue?.delegate = nil
            ioService?.delegate = ioServiceDelegate
        }
    }

    var changeCursorRequestInProgress: Bool = false

    func reload(from packageUrl: URL?) throws {

    }
    
    func updateConfigFromRegistry() {

    }
    
    func changeUuid(to uuid: UUID, name: String?, copyingEntry entry: UTMRegistryEntry?) {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    private class ConnectCoordinator: NSObject, UTMRemoteConnectDelegate {
        var continuation: CheckedContinuation<Void, Error>?

        func remoteInterface(_ remoteInterface: UTMRemoteConnectInterface, didErrorWithMessage message: String) {
            remoteInterface.connectDelegate = nil
            continuation?.resume(throwing: VMError.spiceConnectError(message))
            continuation = nil
        }

        func remoteInterfaceDidConnect(_ remoteInterface: UTMRemoteConnectInterface) {
            remoteInterface.connectDelegate = nil
            continuation?.resume()
            continuation = nil
        }
    }
}

extension UTMRemoteSpiceVirtualMachine {
    func start(options: UTMVirtualMachineStartOptions) async throws {
        try await _state.operation(before: .stopped, during: .starting, after: .started) {
            let port = try await server.startVirtualMachine(id: id, options: options)
            var options = UTMSpiceIOOptions()
            if await !config.sound.isEmpty {
                options.insert(.hasAudio)
            }
            if await config.sharing.hasClipboardSharing {
                options.insert(.hasClipboardSharing)
            }
            if await config.sharing.isDirectoryShareReadOnly {
                options.insert(.isShareReadOnly)
            }
            #if false // FIXME: verbose logging is broken on iOS
            if hasDebugLog {
                options.insert(.hasDebugLog)
            }
            #endif
            let ioService = UTMSpiceIO(host: server.host, port: Int(port), options: options)
            ioService.logHandler = { (line: String) -> Void in
                guard !line.contains("spice_make_scancode") else {
                    return // do not log key presses for privacy reasons
                }
                NSLog("%@", line) // FIXME: log to file
            }
            try ioService.start()
            let coordinator = ConnectCoordinator()
            try await withCheckedThrowingContinuation { continuation in
                coordinator.continuation = continuation
                ioService.connectDelegate = coordinator
                do {
                    try ioService.connect()
                } catch {
                    ioService.connectDelegate = nil
                    continuation.resume(throwing: error)
                }
            }
            self.ioService = ioService
        }
    }

    func stop(usingMethod method: UTMVirtualMachineStopMethod) async throws {

    }

    func restart() async throws {

    }

    func pause() async throws {

    }

    func resume() async throws {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    static func isSupported(systemArchitecture: QEMUArchitecture) -> Bool {
        true // FIXME: somehow determine which architectures are supported
    }
}

extension UTMRemoteSpiceVirtualMachine {
    func requestInputTablet(_ tablet: Bool) {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    func eject(_ drive: UTMQemuConfigurationDrive) async throws {

    }

    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {

    }

}

extension UTMRemoteSpiceVirtualMachine {
    func stopAccessingPath(_ path: String) async {

    }

    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    enum VMError: LocalizedError {
        case spiceConnectError(String)
        case operationInProgress

        var errorDescription: String? {
            switch self {
            case .spiceConnectError(let message):
                return String.localizedStringWithFormat(NSLocalizedString("Failed to connect to SPICE: %@", comment: "UTMRemoteSpiceVirtualMachine"), message)
            case .operationInProgress:
                return NSLocalizedString("An operation is already in progress.", comment: "UTMRemoteSpiceVirtualMachine")
            }
        }
    }
}
