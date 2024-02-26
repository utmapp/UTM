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

    private var server: UTMRemoteClient.Remote

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
            if state == .stopped {
                virtualMachineDidStop()
            }
            delegate?.virtualMachine(self, didTransitionToState: state)
        }
    }

    var screenshot: UTMVirtualMachineScreenshot? {
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

    private weak var screenshotTimer: Timer?

    func reload(from packageUrl: URL?) throws {
        throw UTMVirtualMachineError.notImplemented
    }

    @MainActor
    func reload(usingConfiguration config: UTMQemuConfiguration) {
        self.config = config
        updateConfigFromRegistry()
    }

    @MainActor
    func updateRegistry(_ entry: UTMRegistryEntry) {
        self.registryEntry = entry
    }

    func updateConfigFromRegistry() {
        // not needed
    }
    
    func changeUuid(to uuid: UUID, name: String?, copyingEntry entry: UTMRegistryEntry?) {
        // not needed
    }

    func reconnectServer(_ body: () async throws -> UTMRemoteClient.Remote) async throws {
        try await _state.operation(during: .resuming) {
            self.server = try await body()
        }
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
    private func connect(_ serverInfo: UTMRemoteMessageServer.StartVirtualMachine.ServerInformation, options: UTMSpiceIOOptions, remoteConnection: Bool) async throws -> UTMSpiceIO {
        let ioService = UTMSpiceIO(host: remoteConnection ? serverInfo.spiceHostExternal! : server.host,
                                   tlsPort: Int(remoteConnection ? serverInfo.spicePortExternal! : serverInfo.spicePortInternal),
                                   serverPublicKey: serverInfo.spicePublicKey,
                                   password: serverInfo.spicePassword,
                                   options: options)
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
        return ioService
    }

    func start(options: UTMVirtualMachineStartOptions) async throws {
        try await _state.operation(before: [.stopped, .started, .paused], during: .starting, after: .started) {
            let spiceServer = try await server.startVirtualMachine(id: id, options: options)
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
            do {
                self.ioService = try await connect(spiceServer, options: options, remoteConnection: false)
            } catch {
                if spiceServer.spiceHostExternal != nil && spiceServer.spicePortExternal != nil {
                    // retry with external port
                    self.ioService = try await connect(spiceServer, options: options, remoteConnection: true)
                } else {
                    throw error
                }
            }
            if screenshotTimer == nil {
                screenshotTimer = startScreenshotTimer()
            }
        }
    }

    func stop(usingMethod method: UTMVirtualMachineStopMethod) async throws {
        try await _state.operation(before: [.started, .paused], during: .stopping, after: .stopped) {
            await saveScreenshot()
            try await server.stopVirtualMachine(id: id, method: method)
        }
    }

    func restart() async throws {
        try await _state.operation(before: [.started, .paused], during: .stopping, after: .started) {
            try await server.restartVirtualMachine(id: id)
        }
    }

    func pause() async throws {
        try await _state.operation(before: .started, during: .pausing, after: .paused) {
            try await server.pauseVirtualMachine(id: id)
        }
    }

    func resume() async throws {
        if ioService == nil {
            return try await start(options: [])
        } else {
            try await _state.operation(before: .paused, during: .resuming, after: .started) {
                try await server.resumeVirtualMachine(id: id)
            }
        }
    }

    func saveSnapshot(name: String?) async throws {
        try await _state.operation(before: [.started, .paused], during: .saving) {
            await saveScreenshot()
            try await server.saveSnapshotVirtualMachine(id: id, name: name)
        }
    }

    func deleteSnapshot(name: String?) async throws {
        try await server.deleteSnapshotVirtualMachine(id: id, name: name)
    }

    func restoreSnapshot(name: String?) async throws {
        try await _state.operation(before: [.started, .paused], during: .saving) {
            try await server.restoreSnapshotVirtualMachine(id: id, name: name)
        }
    }

    func loadScreenshotFromServer() async {
        if let url = try? await server.getPackageFile(for: id, relativePathComponents: [kUTMBundleScreenshotFilename]) {
            loadScreenshot(from: url)
        }
    }

    func loadScreenshot(from url: URL) {
        screenshot = UTMVirtualMachineScreenshot(contentsOfURL: url)
    }

    func saveScreenshot() async {
        if let data = screenshot?.pngData {
            try? await server.sendPackageFile(for: id, relativePathComponents: [kUTMBundleScreenshotFilename], data: data)
        }
    }

    private func virtualMachineDidStop() {
        ioService = nil
    }
}

extension UTMRemoteSpiceVirtualMachine {
    actor State {
        private weak var vm: UTMRemoteSpiceVirtualMachine?
        private var isInOperation: Bool = false
        private(set) var state: UTMVirtualMachineState = .stopped {
            didSet {
                vm?.state = state
            }
        }
        private var remoteState: UTMVirtualMachineState?

        init(vm: UTMRemoteSpiceVirtualMachine) {
            self.vm = vm
        }

        func operation(before: UTMVirtualMachineState, during: UTMVirtualMachineState, after: UTMVirtualMachineState? = nil, body: () async throws -> Void) async throws {
            try await operation(before: [before], during: during, after: after, body: body)
        }

        func operation(before: Set<UTMVirtualMachineState>? = nil, during: UTMVirtualMachineState, after: UTMVirtualMachineState? = nil, body: () async throws -> Void) async throws {
            while isInOperation {
                await Task.yield()
            }
            if let before = before {
                guard before.contains(state) else {
                    throw VMError.operationInProgress
                }
            }
            isInOperation = true
            remoteState = nil
            defer {
                isInOperation = false
                if let remoteState = remoteState {
                    state = remoteState
                }
            }
            let previous = state
            state = during
            do {
                try await body()
            } catch {
                state = previous
                throw error
            }
            state = after ?? previous
        }

        func updateRemoteState(_ state: UTMVirtualMachineState) {
            self.remoteState = state
            if !isInOperation && self.state != state {
                self.state = state
            }
        }
    }

    func updateRemoteState(_ state: UTMVirtualMachineState) async {
        await _state.updateRemoteState(state)
    }
}

extension UTMRemoteSpiceVirtualMachine {
    static func isSupported(systemArchitecture: QEMUArchitecture) -> Bool {
        true // FIXME: somehow determine which architectures are supported
    }
}

extension UTMRemoteSpiceVirtualMachine {
    func requestInputTablet(_ tablet: Bool) {
        guard !changeCursorRequestInProgress else {
            return
        }
        changeCursorRequestInProgress = true
        Task {
            defer {
                changeCursorRequestInProgress = false
            }
            try await server.changePointerTypeVirtualMachine(id: id, toTabletMode: tablet)
            ioService?.primaryInput?.requestMouseMode(!tablet)
        }
    }
}

extension UTMRemoteSpiceVirtualMachine {
    func eject(_ drive: UTMQemuConfigurationDrive) async throws {
        // FIXME: implement remote feature
        throw UTMVirtualMachineError.notImplemented
    }

    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {
        // FIXME: implement remote feature
        throw UTMVirtualMachineError.notImplemented
    }

}

extension UTMRemoteSpiceVirtualMachine {
    func stopAccessingPath(_ path: String) async {
        // not needed
    }

    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        throw UTMVirtualMachineError.notImplemented
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
