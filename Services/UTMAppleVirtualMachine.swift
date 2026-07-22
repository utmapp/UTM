//
// Copyright © 2021 osy. All rights reserved.
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

import Combine
import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
final class UTMAppleVirtualMachine: UTMVirtualMachine {
    struct Capabilities: UTMVirtualMachineCapabilities {
        var supportsProcessKill: Bool {
            false
        }
        
        var supportsSnapshots: Bool {
            false
        }
        
        var supportsScreenshots: Bool {
            true
        }
        
        var supportsDisposibleMode: Bool {
            false
        }
        
        var supportsRecoveryMode: Bool {
            true
        }

        var supportsRemoteSession: Bool {
            false
        }
    }
    
    static let capabilities = Capabilities()
    
    private(set) var pathUrl: URL {
        didSet {
            if isScopedAccess {
                oldValue.stopAccessingSecurityScopedResource()
            }
            isScopedAccess = pathUrl.startAccessingSecurityScopedResource()
        }
    }
    
    private(set) var isShortcut: Bool = false
    
    let isRunningAsDisposible: Bool = false
    
    weak var delegate: (any UTMVirtualMachineDelegate)?
    
    var onConfigurationChange: (() -> Void)?
    
    var onStateChange: (() -> Void)?
    
    private(set) var config: UTMAppleConfiguration {
        willSet {
            onConfigurationChange?()
        }
    }
    
    private(set) var registryEntry: UTMRegistryEntry {
        willSet {
            onConfigurationChange?()
        }
    }
    
    private(set) var state: UTMVirtualMachineState = .stopped {
        willSet {
            onStateChange?()
        }
        
        didSet {
            delegate?.virtualMachine(self, didTransitionToState: state)
        }
    }
    
    private(set) var screenshot: UTMVirtualMachineScreenshot? {
        willSet {
            onStateChange?()
        }
    }
    
    private(set) var snapshotUnsupportedError: Error?
    
    private var isScopedAccess: Bool = false
    
    private weak var screenshotTimer: Timer?
    
    private let vmQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)
    
    /// This variable MUST be synchronized by `vmQueue`
    private(set) var apple: VZVirtualMachine?
    
    private var installProgress: Progress?
    
    private var progressObserver: NSKeyValueObservation?
    
    private var sharedDirectoriesChanged: AnyCancellable?
    
    weak var screenshotDelegate: UTMScreenshotProvider?
    
    private var activeResourceUrls: [String: URL] = [:]

    private var removableDrives: [String: Any] = [:]

    private(set) var usbManager: UTMAppleUSBManager?

    private var snapshotUsbDevices: [UTMRegistryEntry.AppleUSBDevice]?

    @MainActor var isHeadless: Bool {
        config.displays.isEmpty && config.serials.filter({ $0.mode == .builtin }).isEmpty
    }

    @MainActor required init(packageUrl: URL, configuration: UTMAppleConfiguration, isShortcut: Bool = false) throws {
        self.isScopedAccess = packageUrl.startAccessingSecurityScopedResource()
        // load configuration
        self.config = configuration
        self.pathUrl = packageUrl
        self.isShortcut = isShortcut
        self.registryEntry = UTMRegistryEntry.empty
        self.registryEntry = loadRegistry()
        self.screenshot = loadScreenshot()
        #if arch(arm64)
        if configuration.system.boot.operatingSystem == .macOS {
            let usbManager = UTMAppleUSBManager(virtualMachineQueue: vmQueue)
            self.usbManager = usbManager
            usbManager.onConnectedDevicesChange = { [weak self] devices in
                self?.registryEntry.connectedAppleUsbDevices = devices.isEmpty ? nil : devices
                if self?.snapshotUsbDevices != nil {
                    self?.snapshotUsbDevices = devices
                }
            }
        }
        #endif
    }
    
    deinit {
        if isScopedAccess {
            pathUrl.stopAccessingSecurityScopedResource()
        }
    }
    
    @MainActor func reload(from packageUrl: URL?) throws {
        let packageUrl = packageUrl ?? pathUrl
        guard let newConfig = try UTMAppleConfiguration.load(from: packageUrl) as? UTMAppleConfiguration else {
            throw UTMConfigurationError.invalidBackend
        }
        config = newConfig
        pathUrl = packageUrl
        updateConfigFromRegistry()
    }
    
    private func _start(options: UTMVirtualMachineStartOptions) async throws {
        let boot = await config.system.boot
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                #if os(macOS) && arch(arm64)
                if #available(macOS 13, *), boot.operatingSystem == .macOS {
                    let vzoptions = VZMacOSVirtualMachineStartOptions()
                    vzoptions.startUpFromMacOSRecovery = options.contains(.bootRecovery)
                    apple.start(options: vzoptions) { result in
                        if let result = result {
                            continuation.resume(with: .failure(result))
                        } else {
                            continuation.resume()
                        }
                    }
                    return
                }
                #endif
                apple.start { result in
                    continuation.resume(with: result)
                }
            }
        }
        try? updateLastModified()
    }
    
    func start(options: UTMVirtualMachineStartOptions = []) async throws {
        guard state == .stopped else {
            return
        }
        state = .starting
        do {
            let isSuspended = await registryEntry.isSuspended
            try await beginAccessingResources()
            try await createAppleVM()
            guard let virtualMachine = await currentVirtualMachine() else {
                return
            }
            if isSuspended && !options.contains(.bootRecovery) {
                try await restoreSnapshot()
            } else {
                try await _start(options: options)
            }
            if #available(macOS 15, *) {
                try await attachExternalDrives()
            }
            await startUsbPassthrough(with: virtualMachine)
            if #available(macOS 12, *) {
                Task { @MainActor in
                    let tag = config.shareDirectoryTag
                    sharedDirectoriesChanged = config.sharedDirectoriesPublisher.sink { [weak self] newShares in
                        guard let self = self else {
                            return
                        }
                        self.vmQueue.async {
                            self.updateSharedDirectories(with: newShares, tag: tag)
                        }
                    }
                }
            }
            guard await transitionToStarted(ifRunning: virtualMachine) else {
                return
            }
            if screenshotTimer == nil {
                screenshotTimer = startScreenshotTimer()
            }
        } catch {
            await stopAccesingResources()
            state = .stopped
            try? await deleteSnapshot()
            throw error
        }
    }
    
    @available(macOS 12, *)
    private func _forceStop(_ virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                virtualMachine.stop { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private func _requestStop() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume() // already stopped
                    return
                }
                do {
                    try apple.requestStop()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func stop(usingMethod method: UTMVirtualMachineStopMethod = .request) async throws {
        if let installProgress = installProgress {
            installProgress.cancel()
            return
        }
        guard state == .started || state == .paused else {
            return
        }
        guard method != .request else {
            return try await _requestStop()
        }
        guard #available(macOS 12, *) else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        let initialState = state
        guard let virtualMachine = await currentVirtualMachine(), state == initialState else {
            return
        }
        state = .stopping
        do {
            try await _forceStop(virtualMachine)
            _ = await transitionToStopped(ifCurrent: virtualMachine)
        } catch {
            if await transitionToStarted(ifRunning: virtualMachine) {
                // The stop failed while the VM was still running.
            } else if await transitionToPaused(ifPaused: virtualMachine) {
                // The stop failed while the VM was still paused.
            } else {
                _ = await transitionToStopped(ifCurrent: virtualMachine)
            }
            throw error
        }
    }
    
    private func _restart(_ virtualMachine: VZVirtualMachine) async throws {
        guard #available(macOS 12, *) else {
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .running || virtualMachine.state == .paused else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                virtualMachine.stop { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        virtualMachine.start { result in
                            continuation.resume(with: result)
                        }
                    }
                }
            }
        }
    }
    
    func restart() async throws {
        guard state == .started || state == .paused else {
            return
        }
        let initialState = state
        guard let virtualMachine = await currentVirtualMachine(), state == initialState else {
            return
        }
        guard await prepareForRestart(virtualMachine, from: initialState) else {
            return
        }
        let connectedUsbDevices: [UTMRegistryEntry.AppleUSBDevice]
        do {
            if initialState == .paused {
                connectedUsbDevices = snapshotUsbDevices ?? []
            } else {
                snapshotUsbDevices = []
                let usbPassthroughIsAvailable = await isUsbPassthroughAvailable
                if let usbManager = usbManager, usbPassthroughIsAvailable {
                    connectedUsbDevices = try await usbManager.detachAllForSnapshot(with: virtualMachine)
                } else {
                    connectedUsbDevices = []
                }
            }
        } catch {
            if initialState != .paused {
                snapshotUsbDevices = nil
            }
            if initialState == .paused {
                _ = await transitionToPaused(ifPaused: virtualMachine)
            } else {
                _ = await transitionToStarted(ifRunning: virtualMachine)
            }
            throw error
        }
        do {
            try await _restart(virtualMachine)
            let usbDevicesToRestore = snapshotUsbDevices ?? connectedUsbDevices
            if await restoreUsbConnections(from: usbDevicesToRestore, with: virtualMachine) {
                snapshotUsbDevices = nil
            }
            guard await transitionToStarted(ifRunning: virtualMachine) else {
                return
            }
        } catch {
            if await transitionToPaused(ifPaused: virtualMachine) {
                // The stop failed before the paused VM changed state.
            } else if await isCurrentVirtualMachineRunning(virtualMachine) {
                let usbDevicesToRestore = snapshotUsbDevices ?? connectedUsbDevices
                if await restoreUsbConnections(from: usbDevicesToRestore, with: virtualMachine) {
                    snapshotUsbDevices = nil
                }
                _ = await transitionToStarted(ifRunning: virtualMachine)
            } else if await isCurrentVirtualMachine(virtualMachine) {
                await usbManager?.releaseSnapshotReservations(for: virtualMachine)
                _ = await transitionToStopped(ifCurrent: virtualMachine)
            }
            throw error
        }
    }
    
    private func _pause(_ virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .running else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                if self.isScreenshotEnabled {
                    Task { @MainActor in
                        await self.takeScreenshot()
                        try? self.saveScreenshot()
                    }
                }
                virtualMachine.pause { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    func pause() async throws {
        guard state == .started else {
            return
        }
        state = .pausing
        guard let virtualMachine = await currentVirtualMachine() else {
            return
        }
        snapshotUsbDevices = []
        let connectedUsbDevices: [UTMRegistryEntry.AppleUSBDevice]
        let usbPassthroughIsAvailable = await isUsbPassthroughAvailable
        do {
            if let usbManager = usbManager, usbPassthroughIsAvailable {
                connectedUsbDevices = try await usbManager.detachAllForSnapshot(with: virtualMachine)
            } else {
                connectedUsbDevices = []
            }
        } catch {
            snapshotUsbDevices = nil
            _ = await transitionToStarted(ifRunning: virtualMachine)
            throw error
        }
        do {
            try await _pause(virtualMachine)
            guard await transitionToPaused(ifPaused: virtualMachine) else {
                return
            }
        } catch {
            if !(await transitionToPaused(ifPaused: virtualMachine)) {
                let usbDevicesToRestore = snapshotUsbDevices ?? connectedUsbDevices
                snapshotUsbDevices = nil
                _ = await restoreUsbConnections(from: usbDevicesToRestore, with: virtualMachine)
                if !(await transitionToStarted(ifRunning: virtualMachine)) {
                    _ = await transitionToStopped(ifCurrent: virtualMachine)
                }
            }
            throw error
        }
    }
    
    #if arch(arm64)
    @available(macOS 14, *)
    private func _saveSnapshot(url: URL, virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .paused else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                virtualMachine.saveMachineStateTo(url: url) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        try? updateLastModified()
    }
    #endif
    
    func saveSnapshot(name: String? = nil) async throws {
        guard #available(macOS 14, *) else {
            return
        }
        #if arch(arm64)
        guard let vmSavedStateURL = await config.system.boot.vmSavedStateURL else {
            return
        }
        if let snapshotUnsupportedError = snapshotUnsupportedError {
            throw snapshotUnsupportedError
        }
        if state == .started {
            try await pause()
        }
        guard state == .paused else {
            return
        }
        guard let virtualMachine = await currentVirtualMachine(), state == .paused else {
            return
        }
        state = .saving
        do {
            try await _saveSnapshot(url: vmSavedStateURL, virtualMachine: virtualMachine)
            await registryEntry.setIsSuspended(true)
            await usbManager?.releaseSnapshotReservations(for: virtualMachine)
            _ = await transitionToPaused(ifPaused: virtualMachine)
        } catch {
            _ = await transitionToPaused(ifPaused: virtualMachine)
            throw error
        }
        #endif
    }
    
    func deleteSnapshot(name: String? = nil) async throws {
        guard let vmSavedStateURL = await config.system.boot.vmSavedStateURL else {
            return
        }
        await registryEntry.setIsSuspended(false)
        try FileManager.default.removeItem(at: vmSavedStateURL)
        try? updateLastModified()
    }
    
    #if arch(arm64)
    @available(macOS 14, *)
    private func _restoreSnapshot(url: URL, virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine, virtualMachine.state == .stopped else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                virtualMachine.restoreMachineStateFrom(url: url) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    #endif
    
    func restoreSnapshot(name: String? = nil) async throws {
        guard #available(macOS 14, *) else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        #if arch(arm64)
        guard let vmSavedStateURL = await config.system.boot.vmSavedStateURL else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        if state == .started {
            try await stop(usingMethod: .force)
        }
        guard state == .stopped || state == .starting else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        guard let virtualMachine = await currentVirtualMachine() else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        state = .restoring
        do {
            try await _restoreSnapshot(url: vmSavedStateURL, virtualMachine: virtualMachine)
            try await _resume(virtualMachine)
        } catch {
            if !(await transitionToPaused(ifPaused: virtualMachine)) {
                _ = await transitionToStopped(ifCurrent: virtualMachine)
            }
            throw error
        }
        guard await transitionToStarted(ifRunning: virtualMachine) else {
            return
        }
        try await deleteSnapshot(name: name)
        #else
        throw UTMAppleVirtualMachineError.operationNotAvailable
        #endif
    }
    
    private func _resume(_ virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .paused else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                virtualMachine.resume { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    func resume() async throws {
        guard state == .paused else {
            return
        }
        state = .resuming
        guard let virtualMachine = await currentVirtualMachine() else {
            return
        }
        do {
            try await _resume(virtualMachine)
            if let snapshotUsbDevices = snapshotUsbDevices {
                if await restoreUsbConnections(from: snapshotUsbDevices, with: virtualMachine) {
                    self.snapshotUsbDevices = nil
                }
            }
            guard await transitionToStarted(ifRunning: virtualMachine) else {
                return
            }
        } catch {
            if !(await transitionToPaused(ifPaused: virtualMachine)) {
                _ = await transitionToStopped(ifCurrent: virtualMachine)
            }
            throw error
        }
    }
    
    @discardableResult @MainActor
    func takeScreenshot() async -> Bool {
        screenshot = screenshotDelegate?.screenshot
        return true
    }

    func reloadScreenshotFromFile() {
        screenshot = loadScreenshot()
    }

    @MainActor private func createAppleVM() throws {
        for i in config.serials.indices {
            let (fd, sfd, name) = try createPty()
            let terminalTtyHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            let slaveTtyHandle = FileHandle(fileDescriptor: sfd, closeOnDealloc: false)
            config.serials[i].fileHandleForReading = terminalTtyHandle
            config.serials[i].fileHandleForWriting = terminalTtyHandle
            let serialPort = UTMSerialPort(portNamed: name, readFileHandle: slaveTtyHandle, writeFileHandle: slaveTtyHandle, terminalFileHandle: terminalTtyHandle)
            config.serials[i].interface = serialPort
        }
        let vzConfig = try config.appleVZConfiguration()
        vmQueue.async { [self] in
            apple = VZVirtualMachine(configuration: vzConfig, queue: vmQueue)
            apple!.delegate = self
            snapshotUnsupportedError = UTMAppleVirtualMachineError.operationNotAvailable
            #if arch(arm64)
            if #available(macOS 14, *) {
                do {
                    try vzConfig.validateSaveRestoreSupport()
                    snapshotUnsupportedError = nil
                } catch {
                    // save this for later when we want to use snapshots
                    snapshotUnsupportedError = error
                }
            }
            #endif
        }
    }

    private func currentVirtualMachine() async -> VZVirtualMachine? {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                continuation.resume(returning: self.apple)
            }
        }
    }

    private func prepareForRestart(_ virtualMachine: VZVirtualMachine,
                                   from initialState: UTMVirtualMachineState) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .running || virtualMachine.state == .paused else {
                    continuation.resume(returning: false)
                    return
                }
                DispatchQueue.main.async {
                    let isCurrent = self.vmQueue.sync {
                        self.apple === virtualMachine &&
                            (virtualMachine.state == .running || virtualMachine.state == .paused)
                    }
                    guard isCurrent, self.state == initialState else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.state = .stopping
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func transitionToStarted(ifRunning virtualMachine: VZVirtualMachine) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                guard self.apple === virtualMachine, virtualMachine.state == .running else {
                    continuation.resume(returning: false)
                    return
                }
                DispatchQueue.main.async {
                    guard self.vmQueue.sync(execute: {
                        self.apple === virtualMachine && virtualMachine.state == .running
                    }) else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.state = .started
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func transitionToPaused(ifPaused virtualMachine: VZVirtualMachine) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                guard self.apple === virtualMachine, virtualMachine.state == .paused else {
                    continuation.resume(returning: false)
                    return
                }
                DispatchQueue.main.async {
                    guard self.vmQueue.sync(execute: {
                        self.apple === virtualMachine && virtualMachine.state == .paused
                    }) else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.state = .paused
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func transitionToStopped(ifCurrent virtualMachine: VZVirtualMachine,
                                     error: Error? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                guard self.apple === virtualMachine,
                      virtualMachine.state == .stopped || virtualMachine.state == .error else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                    return
                }
                self.apple = nil
                self.snapshotUnsupportedError = nil
                self.usbManager?.stop(with: virtualMachine)
                DispatchQueue.main.async {
                    self.removableDrives.removeAll()
                    self.sharedDirectoriesChanged = nil
                    self.stopAccesingResources()
                    for i in self.config.serials.indices {
                        if let serialPort = self.config.serials[i].interface {
                            serialPort.close()
                            self.config.serials[i].interface = nil
                            self.config.serials[i].fileHandleForReading = nil
                            self.config.serials[i].fileHandleForWriting = nil
                        }
                    }
                    try? self.saveScreenshot()
                    self.state = .stopped
                    if let error = error {
                        self.delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
                    }
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func isCurrentVirtualMachine(_ virtualMachine: VZVirtualMachine) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                continuation.resume(returning: self.apple === virtualMachine)
            }
        }
    }

    private func isCurrentVirtualMachineRunning(_ virtualMachine: VZVirtualMachine) async -> Bool {
        await withCheckedContinuation { continuation in
            vmQueue.async {
                continuation.resume(returning: self.apple === virtualMachine && virtualMachine.state == .running)
            }
        }
    }

    private func startUsbPassthrough(with virtualMachine: VZVirtualMachine) async {
        let usbPassthroughIsAvailable = await isUsbPassthroughAvailable
        guard let usbManager = usbManager, usbPassthroughIsAvailable else {
            return
        }
        do {
            let connectedUsbDevices = await usbDevicesForRestore()
            try await usbManager.start(with: virtualMachine, restoring: connectedUsbDevices)
            snapshotUsbDevices = nil
        } catch {
            logger.debug("Failed to initialize USB passthrough: \(error.localizedDescription)")
        }
    }

    private func restoreUsbConnections(from devices: [UTMRegistryEntry.AppleUSBDevice],
                                       with virtualMachine: VZVirtualMachine) async -> Bool {
        let usbPassthroughIsAvailable = await isUsbPassthroughAvailable
        guard let usbManager = usbManager, usbPassthroughIsAvailable else {
            return devices.isEmpty
        }
        do {
            try await usbManager.restoreConnections(from: devices, with: virtualMachine)
            return true
        } catch {
            logger.debug("Failed to restore USB passthrough devices: \(error.localizedDescription)")
            return false
        }
    }

    private func usbDevicesForRestore() async -> [UTMRegistryEntry.AppleUSBDevice] {
        if let snapshotUsbDevices = snapshotUsbDevices {
            return snapshotUsbDevices
        }
        return await registryEntry.connectedAppleUsbDevices ?? []
    }

    private var isUsbPassthroughAvailable: Bool {
        get async {
            guard let usbManager = usbManager else {
                return false
            }
            return await usbManager.isAvailable
        }
    }
    
    @available(macOS 12, *)
    private func updateSharedDirectories(with newShares: [UTMAppleConfigurationSharedDirectory], tag: String) {
        guard let fsConfig = apple?.directorySharingDevices.first(where: { device in
            if let device = device as? VZVirtioFileSystemDevice {
                return device.tag == tag
            } else {
                return false
            }
        }) as? VZVirtioFileSystemDevice else {
            return
        }
        fsConfig.share = UTMAppleConfigurationSharedDirectory.makeDirectoryShare(from: newShares)
    }
    
    @available(macOS 12, *)
    func installVM(with ipswUrl: URL) async throws {
        guard state == .stopped else {
            return
        }
        state = .starting
        do {
            _ = ipswUrl.startAccessingSecurityScopedResource()
            defer {
                ipswUrl.stopAccessingSecurityScopedResource()
            }
            guard FileManager.default.isReadableFile(atPath: ipswUrl.path) else {
                throw UTMAppleVirtualMachineError.ipswNotReadable
            }
            try await beginAccessingResources()
            try await createAppleVM()
            #if os(macOS) && arch(arm64)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                vmQueue.async {
                    guard let apple = self.apple else {
                        continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                        return
                    }
                    let installer = VZMacOSInstaller(virtualMachine: apple, restoringFromImageAt: ipswUrl)
                    self.progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
                        self.delegate?.virtualMachine(self, didUpdateInstallationProgress: progress.fractionCompleted)
                    }
                    self.installProgress = installer.progress
                    installer.install { result in
                        continuation.resume(with: result)
                    }
                }
            }
            state = .started
            progressObserver = nil
            installProgress = nil
            delegate?.virtualMachine(self, didCompleteInstallation: true)
            #else
            throw UTMAppleVirtualMachineError.operatingSystemInstallNotSupported
            #endif
        } catch {
            await stopAccesingResources()
            delegate?.virtualMachine(self, didCompleteInstallation: false)
            state = .stopped
            let error = error as NSError
            if error.domain == "VZErrorDomain" && error.code == 10006 {
                throw UTMAppleVirtualMachineError.deviceSupportOutdated
            }
            throw error
        }
    }
    
    // taken from https://github.com/evansm7/vftool/blob/main/vftool/main.m
    private func createPty() throws -> (Int32, Int32, String) {
        let errMsg = NSLocalizedString("Cannot create virtual terminal.", comment: "UTMAppleVirtualMachine")
        var mfd: Int32 = -1
        var sfd: Int32 = -1
        var cname = [CChar](repeating: 0, count: Int(PATH_MAX))
        var tos = termios()
        guard openpty(&mfd, &sfd, &cname, nil, nil) >= 0 else {
            logger.error("openpty failed: \(errno)")
            throw errMsg
        }
        
        guard tcgetattr(mfd, &tos) >= 0 else {
            logger.error("tcgetattr failed: \(errno)")
            throw errMsg
        }
        
        cfmakeraw(&tos)
        guard tcsetattr(mfd, TCSAFLUSH, &tos) >= 0 else {
            logger.error("tcsetattr failed: \(errno)")
            throw errMsg
        }
        
        let f = fcntl(mfd, F_GETFL)
        guard fcntl(mfd, F_SETFL, f | O_NONBLOCK) >= 0 else {
            logger.error("fnctl failed: \(errno)")
            throw errMsg
        }
        
        let name = String(cString: cname)
        logger.info("fd \(mfd) connected to \(name)")
        
        return (mfd, sfd, name)
    }
    
    @MainActor private func beginAccessingResources() throws {
        for i in config.drives.indices {
            let drive = config.drives[i]
            if let url = drive.imageURL, drive.isExternal {
                if url.startAccessingSecurityScopedResource() {
                    activeResourceUrls[drive.id] = url
                } else {
                    config.drives[i].imageURL = nil
                    throw UTMAppleVirtualMachineError.cannotAccessResource(url)
                }
            }
        }
        for i in config.sharedDirectories.indices {
            let share = config.sharedDirectories[i]
            if let url = share.directoryURL {
                if url.startAccessingSecurityScopedResource() {
                    activeResourceUrls[share.id.uuidString] = url
                } else {
                    config.sharedDirectories[i].directoryURL = nil
                    throw UTMAppleVirtualMachineError.cannotAccessResource(url)
                }
            }
        }
    }
    
    @MainActor private func stopAccesingResources() {
        for url in activeResourceUrls.values {
            url.stopAccessingSecurityScopedResource()
        }
        activeResourceUrls.removeAll()
    }
}

@available(macOS 11, *)
extension UTMAppleVirtualMachine: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Task { [weak self] in
            _ = await self?.transitionToStopped(ifCurrent: virtualMachine)
        }
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Task { [weak self] in
            _ = await self?.transitionToStopped(ifCurrent: virtualMachine, error: error)
        }
    }
    
    // fake methods to adhere to NSObjectProtocol
    
    func isEqual(_ object: Any?) -> Bool {
        self === object as? UTMAppleVirtualMachine
    }
    
    var hash: Int {
        0
    }
    
    var superclass: AnyClass? {
        nil
    }
    
    func `self`() -> Self {
        self
    }
    
    func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
        nil
    }
    
    func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
        nil
    }
    
    func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
        nil
    }
    
    func isProxy() -> Bool {
        false
    }
    
    func isKind(of aClass: AnyClass) -> Bool {
        false
    }
    
    func isMember(of aClass: AnyClass) -> Bool {
        false
    }
    
    func conforms(to aProtocol: Protocol) -> Bool {
        aProtocol is VZVirtualMachineDelegate
    }
    
    func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(VZVirtualMachineDelegate.guestDidStop(_:)) {
            return true
        }
        if aSelector == #selector(VZVirtualMachineDelegate.virtualMachine(_:didStopWithError:)) {
            return true
        }
        return false
    }
    
    var description: String {
        ""
    }
}

@available(macOS 15, *)
extension UTMAppleVirtualMachine {
    private func detachDrive(id: String) async throws {
        if let oldUrl = activeResourceUrls.removeValue(forKey: id) {
            oldUrl.stopAccessingSecurityScopedResource()
        }
        if let device = removableDrives.removeValue(forKey: id) as? any VZUSBDevice {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                vmQueue.async {
                    guard let apple = self.apple, let usbController = apple.usbControllers.first else {
                        continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                        return
                    }
                    usbController.detach(device: device) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    /// Eject a removable drive
    /// - Parameter drive: Removable drive
    func eject(_ drive: UTMAppleConfigurationDrive) async throws {
        if state == .started {
            try await detachDrive(id: drive.id)
        }
        await registryEntry.removeExternalDrive(forId: drive.id)
    }

    private func attachDrive(_ drive: VZDiskImageStorageDeviceAttachment, imageURL: URL, id: String) async throws {
        if imageURL.startAccessingSecurityScopedResource() {
            activeResourceUrls[id] = imageURL
        }
        let configuration = VZUSBMassStorageDeviceConfiguration(attachment: drive)
        let device = VZUSBMassStorageDevice(configuration: configuration)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            vmQueue.async {
                guard let apple = self.apple, let usbController = apple.usbControllers.first else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                usbController.attach(device: device) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        removableDrives[id] = device
    }

    /// Change mount image of a removable drive
    /// - Parameters:
    ///   - drive: Removable drive
    ///   - url: New mount image
    func changeMedium(_ drive: UTMAppleConfigurationDrive, to url: URL) async throws {
        var newDrive = drive
        newDrive.imageURL = url
        let scopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let attachment = try newDrive.vzDiskImage()!
        if state == .started {
            try await detachDrive(id: drive.id)
            try await attachDrive(attachment, imageURL: url, id: drive.id)
        }
        let file = try UTMRegistryEntry.File(url: url)
        await registryEntry.setExternalDrive(file, forId: drive.id)
    }

    private func _attachExternalDrives(_ drives: [any VZUSBDevice]) -> (any Error)? {
        let group = DispatchGroup()
        var lastError: (any Error)?
        group.enter()
        vmQueue.async {
            defer {
                group.leave()
            }
            guard let apple = self.apple, let usbController = apple.usbControllers.first else {
                lastError = UTMAppleVirtualMachineError.operationNotAvailable
                return
            }
            for device in drives {
                group.enter()
                usbController.attach(device: device) { error in
                    if let error = error {
                        lastError = error
                    }
                    group.leave()
                }
            }
        }
        group.wait()
        return lastError
    }

    private func attachExternalDrives() async throws {
        let removableDrives = try await config.drives.reduce(into: [String: any VZUSBDevice]()) { devices, drive in
            guard drive.isExternal else {
                return
            }
            guard let attachment = try drive.vzDiskImage() else {
                return
            }
            let configuration = VZUSBMassStorageDeviceConfiguration(attachment: attachment)
            devices[drive.id] = VZUSBMassStorageDevice(configuration: configuration)
        }
        let drives = Array(removableDrives.values)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            if let error = self._attachExternalDrives(drives) {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
        self.removableDrives = removableDrives
    }

    private var guestToolsId: String {
        "guest-tools"
    }

    var hasGuestToolsAttached: Bool {
        removableDrives.keys.contains(guestToolsId)
    }

    func attachGuestTools(_ imageURL: URL) async throws {
        try await detachDrive(id: guestToolsId)
        let scopedAccess = imageURL.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                imageURL.stopAccessingSecurityScopedResource()
            }
        }
        let attachment = try VZDiskImageStorageDeviceAttachment(url: imageURL, readOnly: true)
        try await attachDrive(attachment, imageURL: imageURL, id: guestToolsId)
    }

    func detachGuestTools() async throws {
        try await detachDrive(id: guestToolsId)
    }
}

protocol UTMScreenshotProvider: AnyObject {
    var screenshot: UTMVirtualMachineScreenshot? { get }
}

enum UTMAppleVirtualMachineError: Error {
    case cannotAccessResource(URL)
    case operatingSystemInstallNotSupported
    case operationNotAvailable
    case ipswNotReadable
    case deviceSupportOutdated
}

extension UTMAppleVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotAccessResource(let url):
            return String.localizedStringWithFormat(NSLocalizedString("Cannot access resource: %@", comment: "UTMAppleVirtualMachine"), url.path)
        case .operatingSystemInstallNotSupported:
            return NSLocalizedString("The operating system cannot be installed on this machine.", comment: "UTMAppleVirtualMachine")
        case .operationNotAvailable:
            return NSLocalizedString("The operation is not available.", comment: "UTMAppleVirtualMachine")
        case .ipswNotReadable:
            return NSLocalizedString("The recovery IPSW cannot be read. Please select a new IPSW in Boot settings.", comment: "UTMAppleVirtualMachine")
        case .deviceSupportOutdated:
            return NSLocalizedString("You need to update macOS to run this virtual machine. A separate pop-up should prompt you to install this update. If you are trying to install a new beta version of macOS, you must manually download the Device Support package from the Apple Developer website.", comment: "UTMAppleVirtualMachine")
        }
    }
}

// MARK: - Registry access
extension UTMAppleVirtualMachine {
    @MainActor func updateRegistryFromConfig() async throws {
        // save a copy to not collide with updateConfigFromRegistry()
        let configShares = config.sharedDirectories
        let configDrives = config.drives
        try await updateRegistryBasics()
        registryEntry.sharedDirectories.removeAll(keepingCapacity: true)
        for sharedDirectory in configShares {
            if let url = sharedDirectory.directoryURL {
                let file = try UTMRegistryEntry.File(url: url, isReadOnly: sharedDirectory.isReadOnly)
                registryEntry.sharedDirectories.append(file)
            }
        }
        for drive in configDrives {
            if drive.isExternal, let url = drive.imageURL {
                let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
                registryEntry.externalDrives[drive.id] = file
            } else if drive.isExternal {
                registryEntry.externalDrives.removeValue(forKey: drive.id)
            }
        }
        // remove any unreferenced drives
        registryEntry.externalDrives = registryEntry.externalDrives.filter({ element in
            configDrives.contains(where: { $0.id == element.key && $0.isExternal })
        })
        // save IPSW reference
        if let url = config.system.boot.macRecoveryIpswURL {
            registryEntry.macRecoveryIpsw = try UTMRegistryEntry.File(url: url, isReadOnly: true)
        } else {
            registryEntry.macRecoveryIpsw = nil
        }
    }
    
    @MainActor func updateConfigFromRegistry() {
        // Only update shared directories if they actually changed to avoid unnecessary virtiofs reconnections
        let newShares = registryEntry.sharedDirectories.map({ UTMAppleConfigurationSharedDirectory(directoryURL: $0.url, isReadOnly: $0.isReadOnly )})

        let sharesChanged = newShares.count != config.sharedDirectories.count ||
            zip(newShares, config.sharedDirectories).contains { new, old in
                new.directoryURL != old.directoryURL || new.isReadOnly != old.isReadOnly
            }

        if sharesChanged {
            config.sharedDirectories = newShares
        }

        for i in config.drives.indices {
            let id = config.drives[i].id
            if config.drives[i].isExternal {
                config.drives[i].imageURL = registryEntry.externalDrives[id]?.url
            }
        }
        if let file = registryEntry.macRecoveryIpsw {
            config.system.boot.macRecoveryIpswURL = file.url
        }
    }
    
    @MainActor func changeUuid(to uuid: UUID, name: String? = nil, copyingEntry entry: UTMRegistryEntry? = nil) {
        config.information.uuid = uuid
        if let name = name {
            config.information.name = name
        }
        registryEntry = UTMRegistry.shared.entry(for: self)
        if let entry = entry {
            registryEntry.update(copying: entry)
        }
    }
}

// MARK: - Non-asynchronous version (to be removed)

extension UTMAppleVirtualMachine {
    @available(macOS 12, *)
    func requestInstallVM(with url: URL) {
        Task {
            do {
                try await installVM(with: url)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
}
