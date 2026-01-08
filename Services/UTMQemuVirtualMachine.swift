//
// Copyright © 2022 osy. All rights reserved.
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
import QEMUKit
#if os(macOS)
import SwiftPortmap
#endif

private var SpiceIoServiceGuestAgentContext = 0
private let kSuspendSnapshotName = "suspend"
private let kProbeSuspendDelay = 1*NSEC_PER_SEC

/// QEMU backend virtual machine
final class UTMQemuVirtualMachine: UTMSpiceVirtualMachine {
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
            true
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
    
    private(set) var isRunningAsDisposible: Bool = false
    
    weak var delegate: (any UTMVirtualMachineDelegate)?
    
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
    
    private(set) var state: UTMVirtualMachineState = .stopped {
        willSet {
            onStateChange?()
        }
        
        didSet {
            delegate?.virtualMachine(self, didTransitionToState: state)
        }
    }
    
    var screenshot: UTMVirtualMachineScreenshot? {
        willSet {
            onStateChange?()
        }
    }
    
    private(set) var snapshotUnsupportedError: Error?
    
    private var isScopedAccess: Bool = false
    
    private weak var screenshotTimer: Timer?
    
    /// Handle SPICE IO related events
    weak var ioServiceDelegate: UTMSpiceIODelegate? {
        didSet {
            if let ioService = ioService {
                ioService.delegate = ioServiceDelegate
            }
        }
    }
    
    /// SPICE interface
    private(set) var ioService: UTMSpiceIO? {
        didSet {
            oldValue?.delegate = nil
            ioService?.delegate = ioServiceDelegate
        }
    }
    
    /// Pipe interface (alternative to UTMSpiceIO)
    private var pipeInterface: UTMPipeInterface?

    private let qemuVM = QEMUVirtualMachine()
    
    /// QEMU Process interface
    var system: UTMQemuSystem? {
        get async {
            await qemuVM.launcher as? UTMQemuSystem
        }
    }
    
    /// QEMU QMP interface
    var monitor: QEMUMonitor? {
        get async {
            await qemuVM.monitor
        }
    }
    
    /// QEMU Guest Agent interface
    var guestAgent: QEMUGuestAgent? {
        get async {
            await qemuVM.guestAgent
        }
    }
    
    private var startTask: Task<Void, any Error>?
    
    private var swtpm: UTMSWTPM?
    
    private var changeCursorRequestInProgress: Bool = false

    private static var resourceCacheOperationQueue = DispatchQueue(label: "Resource Cache Operation")
    private static var isResourceCacheUpdated = false

    @Setting("UseFileLock") private var isUseFileLock = true

    #if WITH_SERVER
    @Setting("ServerPort") private var serverPort: Int = 0
    private var spicePort: SwiftPortmap.Port?
    private(set) var spiceServerInfo: UTMRemoteMessageServer.StartVirtualMachine.ServerInformation?
    #endif

    @MainActor required init(packageUrl: URL, configuration: UTMQemuConfiguration, isShortcut: Bool = false) throws {
        self.isScopedAccess = packageUrl.startAccessingSecurityScopedResource()
        // load configuration
        self.config = configuration
        self.pathUrl = packageUrl
        self.isShortcut = isShortcut
        self.registryEntry = UTMRegistryEntry.empty
        self.registryEntry = loadRegistry()
        self.screenshot = loadScreenshot()
    }
    
    deinit {
        if isScopedAccess {
            pathUrl.stopAccessingSecurityScopedResource()
        }
    }
    
    @MainActor func reload(from packageUrl: URL?) throws {
        let packageUrl = packageUrl ?? pathUrl
        guard let qemuConfig = try UTMQemuConfiguration.load(from: packageUrl) as? UTMQemuConfiguration else {
            throw UTMConfigurationError.invalidBackend
        }
        config = qemuConfig
        pathUrl = packageUrl
        updateConfigFromRegistry()
    }
}

// MARK: - Shortcut access
extension UTMQemuVirtualMachine {
    func accessShortcut() async throws {
        guard isShortcut else {
            return
        }
        // if VM has not started yet, we create a temporary process
        let system = await system ?? UTMProcess()
        var bookmark = await registryEntry.package.remoteBookmark
        let existing = bookmark != nil
        if !existing {
            // create temporary bookmark
            bookmark = try pathUrl.bookmarkData()
        } else {
            let bookmarkPath = await registryEntry.package.path
            // in case old path is still accessed
            system.stopAccessingPath(bookmarkPath)
        }
        let (success, newBookmark, newPath) = await system.accessData(withBookmark: bookmark!, securityScoped: existing)
        if success {
            await registryEntry.setPackageRemoteBookmark(newBookmark, path: newPath)
        } else if existing {
            // the remote bookmark is invalid but the local one still might be valid
            await registryEntry.setPackageRemoteBookmark(nil)
            try await accessShortcut()
        } else {
            throw UTMQemuVirtualMachineError.failedToAccessShortcut
        }
    }
}

// MARK: - VM actions

extension UTMQemuVirtualMachine {
    private var rendererBackend: UTMQEMURendererBackend {
        let rawValue = UserDefaults.standard.integer(forKey: "QEMURendererBackend")
        return UTMQEMURendererBackend(rawValue: rawValue) ?? .qemuRendererBackendDefault
    }

    private var vulkanDriver: UTMQEMUVulkanDriver {
        get throws {
            let rawValue = UserDefaults.standard.integer(forKey: "QEMUVulkanDriver")
            let driver = UTMQEMUVulkanDriver(rawValue: rawValue) ?? .qemuVulkanDriverDefault
            if driver == .qemuVulkanDriverKosmicKrisp {
                if #unavailable(iOS 18, macOS 15, tvOS 18, visionOS 2) {
                    throw UTMQemuVirtualMachineError.vulkanVersionNotSupported
                }
            }
            if ![.qemuRendererBackendDefault, .qemuRendererBackendAngleMetal].contains(rendererBackend) {
                if driver == .qemuVulkanDriverDefault || driver == .qemuVulkanDriverDisabled {
                    return .qemuVulkanDriverDisabled
                } else {
                    throw UTMQemuVirtualMachineError.vulkanNotCompatible
                }
            }
            return driver
        }
    }

    @MainActor private func qemuEnsureEfiVarsAvailable() async throws {
        guard let efiVarsURL = config.qemu.efiVarsURL else {
            return
        }
        if !FileManager.default.fileExists(atPath: efiVarsURL.path) {
            config.qemu.isUefiVariableResetRequested = true
            config.qemu.hasPreloadedSecureBootKeys = config.qemu.hasTPMDevice
            _ = try await config.qemu.saveData(to: efiVarsURL.deletingLastPathComponent(), for: config.system)
        }
    }
    
    private func determineSnapshotSupport() async -> Error? {
        // predetermined reasons
        if isRunningAsDisposible {
            return UTMQemuVirtualMachineError.qemuError(NSLocalizedString("Suspend state cannot be saved when running in disposible mode.", comment: "UTMQemuVirtualMachine"))
        }
        #if arch(x86_64)
        let hasHypervisor = await config.qemu.hasHypervisor
        let architecture = await config.system.architecture
        if hasHypervisor && architecture == .x86_64 {
            return UTMQemuVirtualMachineError.qemuError(NSLocalizedString("Suspend is not supported for virtualization.", comment: "UTMQemuVirtualMachine"))
        }
        #endif
        for display in await config.displays {
            if display.hardware.rawValue.contains("-gl-") || display.hardware.rawValue.hasSuffix("-gl") {
                return UTMQemuVirtualMachineError.qemuError(NSLocalizedString("Suspend is not supported when GPU acceleration is enabled.", comment: "UTMQemuVirtualMachine"))
            }
        }
        for drive in await config.drives {
            if drive.interface == .nvme {
                return UTMQemuVirtualMachineError.qemuError(NSLocalizedString("Suspend is not supported when an emulated NVMe device is active.", comment: "UTMQemuVirtualMachine"))
            }
        }
        return nil
    }
    
    private func _start(options: UTMVirtualMachineStartOptions) async throws {
        // check if we can actually start this VM
        guard await isSupported else {
            throw UTMQemuVirtualMachineError.emulationNotSupported
        }

        // create QEMU resource cache if needed
        try await ensureQemuResourceCacheUpToDate()

        let hasDebugLog = await config.qemu.hasDebugLog
        // start logging
        if hasDebugLog, let debugLogURL = await config.qemu.debugLogURL {
            await qemuVM.setRedirectLog(url: debugLogURL)
        } else {
            await qemuVM.setRedirectLog(url: nil)
        }
        let isRunningAsDisposible = options.contains(.bootDisposibleMode)
        let isRemoteSession = options.contains(.remoteSession)
        #if WITH_SERVER
        let spicePassword = isRemoteSession ? String.random(length: 32) : nil
        let spicePort = isRemoteSession ? try SwiftPortmap.Port.TCP(unusedPortStartingAt: UInt16(serverPort)) : nil
        #else
        if isRemoteSession {
            throw UTMVirtualMachineError.notImplemented
        }
        #endif
        await MainActor.run {
            config.qemu.isDisposable = isRunningAsDisposible
            #if WITH_SERVER
            config.qemu.spiceServerPort = spicePort?.internalPort
            config.qemu.spiceServerPassword = spicePassword
            config.qemu.isSpiceServerTlsEnabled = true
            #endif
        }

        // start TPM
        if await config.qemu.hasTPMDevice {
            let swtpm = UTMSWTPM()
            swtpm.ctrlSocketUrl = await config.swtpmSocketURL
            swtpm.dataUrl = await config.qemu.tpmDataURL
            swtpm.currentDirectoryUrl = await config.socketURL
            try await swtpm.start()
            self.swtpm = swtpm
        }

        let allArguments = await config.allArguments
        let arguments = allArguments.map({ $0.string })
        let resources = allArguments.compactMap({ $0.fileUrls }).flatMap({ $0 })
        let remoteBookmarks = await remoteBookmarks

        let system = await UTMQemuSystem(arguments: arguments, architecture: config.system.architecture.rawValue)
        system.resources = resources
        system.currentDirectoryUrl = await config.socketURL
        system.remoteBookmarks = remoteBookmarks
        system.rendererBackend = rendererBackend
        system.vulkanDriver = try vulkanDriver
        system.shmemDirectoryURL = await config.shmemDirectoryURL
        #if os(macOS) // FIXME: verbose logging is broken on iOS
        system.hasDebugLog = hasDebugLog
        #endif
        try Task.checkCancellation()

        if isShortcut {
            try await accessShortcut()
            try Task.checkCancellation()
        }

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
        #if os(macOS) // FIXME: verbose logging is broken on iOS
        if hasDebugLog {
            options.insert(.hasDebugLog)
        }
        #endif
        let spiceSocketUrl = await config.spiceSocketURL
        let interface: any QEMUInterface
        let spicePublicKey: Data?
        if isRemoteSession {
            let pipeInterface = UTMPipeInterface()
            await MainActor.run {
                pipeInterface.monitorInPipeURL = config.monitorPipeURL.appendingPathExtension("in")
                pipeInterface.monitorOutPipeURL = config.monitorPipeURL.appendingPathExtension("out")
                pipeInterface.guestAgentInPipeURL = config.guestAgentPipeURL.appendingPathExtension("in")
                pipeInterface.guestAgentOutPipeURL = config.guestAgentPipeURL.appendingPathExtension("out")
            }
            try pipeInterface.start()
            interface = pipeInterface
            // generate a TLS key for this session
            guard let key = GenerateRSACertificate("UTM Remote SPICE Server" as CFString,
                                                   "UTM" as CFString,
                                                   Int.random(in: 1..<CLong.max) as CFNumber,
                                                   1 as CFNumber,
                                                   false as CFBoolean)?.takeUnretainedValue() as? [Data] else {
                throw UTMQemuVirtualMachineError.keyGenerationFailed
            }
            try await key[1].write(to: config.spiceTlsKeyUrl)
            try await key[2].write(to: config.spiceTlsCertUrl)
            spicePublicKey = key[3]
        } else {
            let ioService = UTMSpiceIO(socketUrl: spiceSocketUrl, options: options)
            ioService.logHandler = { [weak system] (line: String) -> Void in
                guard !line.contains("spice_make_scancode") else {
                    return // do not log key presses for privacy reasons
                }
                system?.logging?.writeLine(line)
            }
            try ioService.start()
            interface = ioService
            spicePublicKey = nil
        }
        try Task.checkCancellation()
        
        // create EFI variables for legacy config as well as handle UEFI resets
        try await qemuEnsureEfiVarsAvailable()
        try Task.checkCancellation()
        
        // start QEMU
        await qemuVM.setDelegate(self)
        try await qemuVM.start(launcher: system, interface: interface)
        let monitor = await monitor!
        try Task.checkCancellation()
        
        // load saved state if requested
        let isSuspended = await registryEntry.isSuspended
        if !isRunningAsDisposible && isSuspended {
            try await monitor.qemuRestoreSnapshot(kSuspendSnapshotName)
            try Task.checkCancellation()
        }
        
        // set up SPICE sharing and removable drives
        try await self.restoreExternalDrives(withMounting: !isSuspended)
        if let ioService = interface as? UTMSpiceIO {
            try await self.restoreSharedDirectory(for: ioService)
        } else {
            // TODO: implement shared directory in remote interface
        }
        try Task.checkCancellation()
        
        // continue VM boot
        try await monitor.continueBoot()
        
        // delete saved state
        if isSuspended {
            try? await deleteSnapshot()
        }
        
        // save ioService and let it set the delegate
        self.ioService = interface as? UTMSpiceIO
        self.pipeInterface = interface as? UTMPipeInterface
        self.isRunningAsDisposible = isRunningAsDisposible
        
        // test out snapshots
        self.snapshotUnsupportedError = await determineSnapshotSupport()

        #if WITH_SERVER
        // save server details
        if let spicePort = spicePort, let spicePublicKey = spicePublicKey, let spicePassword = spicePassword {
            self.spiceServerInfo = .init(spicePortInternal: spicePort.internalPort,
                                         spicePortExternal: try? await spicePort.externalPort,
                                         spiceHostExternal: try? await spicePort.externalIpv4Address,
                                         spicePublicKey: spicePublicKey,
                                         spicePassword: spicePassword)
            self.spicePort = spicePort
        }
        #endif

        // update timestamp
        if !isRunningAsDisposible {
            try? updateLastModified()
        }
    }
    
    func start(options: UTMVirtualMachineStartOptions = []) async throws {
        guard state == .stopped else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        state = .starting
        do {
            startTask = Task {
                try await _start(options: options)
            }
            defer {
                startTask = nil
            }
            try await startTask!.value
            state = .started
            if screenshotTimer == nil && !options.contains(.remoteSession) {
                screenshotTimer = startScreenshotTimer()
            }
        } catch {
            // delete suspend state on error
            await registryEntry.setIsSuspended(false)
            await qemuVM.kill()
            state = .stopped
            throw error
        }
    }
    
    func stop(usingMethod method: UTMVirtualMachineStopMethod) async throws {
        if method == .request {
            guard let monitor = await monitor else {
                throw UTMQemuVirtualMachineError.invalidVmState
            }
            try await monitor.qemuPowerDown()
            return
        }
        let kill = method == .kill
        if kill {
            // prevent deadlock force stopping during startup
            ioService?.disconnect()
        }
        guard state != .stopped else {
            return // nothing to do
        }
        guard kill || state == .started || state == .paused else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        if !kill {
            state = .stopping
        }
        if kill {
            await qemuVM.kill()
        } else {
            try await qemuVM.stop()
        }
        isRunningAsDisposible = false
    }
    
    private func _restart() async throws {
        if await registryEntry.isSuspended {
            try? await deleteSnapshot()
        }
        guard let monitor = await qemuVM.monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await monitor.qemuReset()
    }
    
    func restart() async throws {
        guard state == .started || state == .paused else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        state = .stopping
        do {
            try await _restart()
            state = .started
        } catch {
            state = .stopped
            throw error
        }
    }
    
    private func _pause() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        if isScreenshotEnabled {
            await takeScreenshot()
        }
        try await monitor.qemuStop()
    }
    
    func pause() async throws {
        guard state == .started else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        state = .pausing
        do {
            try await _pause()
            state = .paused
        } catch {
            state = .stopped
            throw error
        }
    }
    
    private func _saveSnapshot(name: String) async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        let result = try await monitor.qemuSaveSnapshot(name)
        if result.localizedCaseInsensitiveContains("Error") {
            throw UTMQemuVirtualMachineError.qemuError(result)
        }
        try? updateLastModified()
    }
    
    func saveSnapshot(name: String? = nil) async throws {
        guard state == .paused || state == .started else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        if let snapshotUnsupportedError = snapshotUnsupportedError {
            throw UTMQemuVirtualMachineError.saveSnapshotFailed(snapshotUnsupportedError)
        }
        let prev = state
        state = .saving
        defer {
            state = prev
        }
        do {
            try await _saveSnapshot(name: name ?? kSuspendSnapshotName)
            if name == nil {
                await registryEntry.setIsSuspended(true)
                try saveScreenshot()
            }
        } catch {
            throw UTMQemuVirtualMachineError.saveSnapshotFailed(error)
        }
    }
    
    private func _deleteSnapshot(name: String) async throws {
        if let monitor = await monitor { // if QEMU is running
            let result = try await monitor.qemuDeleteSnapshot(name)
            if result.localizedCaseInsensitiveContains("Error") {
                throw UTMQemuVirtualMachineError.qemuError(result)
            }
            try? updateLastModified()
        }
    }
    
    func deleteSnapshot(name: String? = nil) async throws {
        if name == nil {
            await registryEntry.setIsSuspended(false)
        }
        try await _deleteSnapshot(name: name ?? kSuspendSnapshotName)
    }
    
    private func _resume() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await monitor.qemuResume()
        if await registryEntry.isSuspended {
            try? await deleteSnapshot()
        }
    }
    
    func resume() async throws {
        guard state == .paused else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        state = .resuming
        do {
            try await _resume()
            state = .started
        } catch {
            state = .stopped
            throw error
        }
    }
    
    private func _restoreSnapshot(name: String) async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        let result = try await monitor.qemuRestoreSnapshot(name)
        if result.localizedCaseInsensitiveContains("Error") {
            throw UTMQemuVirtualMachineError.qemuError(result)
        }
    }
    
    func restoreSnapshot(name: String? = nil) async throws {
        guard state == .paused || state == .started else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        let prev = state
        state = .restoring
        do {
            try await _restoreSnapshot(name: name ?? kSuspendSnapshotName)
            state = prev
        } catch {
            state = .stopped
            throw error
        }
    }
    
    /// Attempt to cancel the current operation
    ///
    /// Currently only `vmStart()` can be cancelled.
    func cancelOperation() {
        startTask?.cancel()
    }
}

// MARK: - VM delegate
extension UTMQemuVirtualMachine: QEMUVirtualMachineDelegate {
    func qemuVMDidStart(_ qemuVM: QEMUVirtualMachine) {
        // not used
    }
    
    func qemuVMWillStop(_ qemuVM: QEMUVirtualMachine) {
        // not used
    }
    
    func qemuVMDidStop(_ qemuVM: QEMUVirtualMachine) {
        #if WITH_SERVER
        spicePort = nil
        spiceServerInfo = nil
        #endif
        swtpm?.stop()
        swtpm = nil
        ioService = nil
        ioServiceDelegate = nil
        pipeInterface?.disconnect()
        pipeInterface = nil
        snapshotUnsupportedError = nil
        try? saveScreenshot()
        state = .stopped
    }
    
    func qemuVM(_ qemuVM: QEMUVirtualMachine, didError error: Error) {
        delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
    }
    
    func qemuVM(_ qemuVM: QEMUVirtualMachine, didCreatePttyDevice path: String, label: String) {
        let scanner = Scanner(string: label)
        guard scanner.scanString("term") != nil else {
            logger.error("Invalid terminal device '\(label)'")
            return
        }
        var term: Int = -1
        guard scanner.scanInt(&term) else {
            logger.error("Cannot get index from terminal device '\(label)'")
            return
        }
        let index = term
        Task { @MainActor in
            guard index >= 0 && index < config.serials.count else {
                logger.error("Serial device '\(path)' out of bounds for index \(index)")
                return
            }
            config.serials[index].pttyDevice = URL(fileURLWithPath: path)
        }
    }
}

// MARK: - Input device switching
extension UTMQemuVirtualMachine {
    func changeInputTablet(_ tablet: Bool) async throws {
        defer {
            changeCursorRequestInProgress = false
        }
        guard state == .started else {
            return
        }
        guard let monitor = await monitor else {
            return
        }
        do {
            let index = try await monitor.mouseIndex(forAbsolute: tablet)
            guard index > -1 else {
                return
            }
            try await monitor.mouseSelect(index)
            ioService?.primaryInput?.requestMouseMode(!tablet)
        } catch {
            logger.error("Error changing mouse mode: \(error)")
        }
    }

    func requestInputTablet(_ tablet: Bool) {
        guard !changeCursorRequestInProgress else {
            return
        }
        changeCursorRequestInProgress = true
        Task {
            defer {
                changeCursorRequestInProgress = false
            }
            try await changeInputTablet(tablet)
        }
    }
}

// MARK: - Architecture supported
extension UTMQemuVirtualMachine {
    /// Check if a QEMU target is supported
    /// - Parameter systemArchitecture: QEMU architecture
    /// - Returns: true if UTM is compiled with the supporting binaries
    internal static func isSupported(systemArchitecture: QEMUArchitecture) -> Bool {
        let arch = systemArchitecture.rawValue
        let bundleURL = Bundle.main.bundleURL
        #if os(macOS)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let base = "Versions/A/"
        #else
        let contentsURL = bundleURL
        let base = ""
        #endif
        let frameworksURL = contentsURL.appendingPathComponent("Frameworks", isDirectory: true)
        let framework = frameworksURL.appendingPathComponent("qemu-" + arch + "-softmmu.framework/" + base + "qemu-" + arch + "-softmmu", isDirectory: false)
        return FileManager.default.fileExists(atPath: framework.path)
    }
    
    /// Check if the current VM target is supported by the host
    @MainActor var isSupported: Bool {
        return UTMQemuVirtualMachine.isSupported(systemArchitecture: config.system.architecture)
    }
}

// MARK: - External drives
extension UTMQemuVirtualMachine {
    func eject(_ drive: UTMQemuConfigurationDrive) async throws {
        try await eject(drive, isForced: false)
    }

    private func eject(_ drive: UTMQemuConfigurationDrive, isForced: Bool) async throws {
        guard drive.isExternal else {
            return
        }
        if let qemu = await monitor, qemu.isConnected {
            try qemu.ejectDrive("drive\(drive.id)", force: isForced)
        }
        if let oldPath = await registryEntry.externalDrives[drive.id]?.path {
            await system?.stopAccessingPath(oldPath)
        }
        await registryEntry.removeExternalDrive(forId: drive.id)
    }

    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {
        try await changeMedium(drive, to: url, isAccessOnly: false)
    }

    private func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL, isAccessOnly: Bool) async throws {
        let isScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let tempBookmark = try url.bookmarkData()
        try await eject(drive, isForced: true)
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
        await registryEntry.setExternalDrive(file, forId: drive.id)
        try await changeMedium(drive, with: tempBookmark, isSecurityScoped: false, isAccessOnly: isAccessOnly)
    }

    private func changeMedium(_ drive: UTMQemuConfigurationDrive, with bookmark: Data, isSecurityScoped: Bool, isAccessOnly: Bool) async throws {
        let system = await system ?? UTMProcess()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateExternalDriveRemoteBookmark(bookmark, forId: drive.id)
        if let qemu = await monitor, qemu.isConnected && !isAccessOnly {
            let isLocked = isUseFileLock && !drive.isReadOnly
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path, locking: isLocked)
        }
    }

    private func restoreExternalDrives(withMounting isMounting: Bool) async throws {
        guard await system != nil else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        for drive in await config.drives {
            if !drive.isExternal {
                continue
            }
            let id = drive.id
            if let bookmark = await registryEntry.externalDrives[id]?.remoteBookmark {
                // an image bookmark was saved while QEMU was running
                try await changeMedium(drive, with: bookmark, isSecurityScoped: true, isAccessOnly: !isMounting)
            } else if let localBookmark = await registryEntry.externalDrives[id]?.bookmark {
                // an image bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: localBookmark)
                try await changeMedium(drive, to: url, isAccessOnly: !isMounting)
            } else if isMounting && (drive.imageType == .cd || drive.imageType == .disk) {
                // a placeholder image might have been mounted
                try await eject(drive)
            }
        }
    }
}

// MARK: - Shared directory
extension UTMQemuVirtualMachine {
    func stopAccessingPath(_ path: String) async {
        await system?.stopAccessingPath(path)
    }

    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        let system = await system ?? UTMProcess()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let _ = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateSingleSharedDirectoryRemoteBookmark(bookmark)
    }
}

// MARK: - Registry syncing
extension UTMQemuVirtualMachine {
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

    @MainActor var remoteBookmarks: [URL: Data] {
        var dict = [URL: Data]()
        for file in registryEntry.externalDrives.values {
            if let bookmark = file.remoteBookmark {
                dict[file.url] = bookmark
            }
        }
        for file in registryEntry.sharedDirectories {
            if let bookmark = file.remoteBookmark {
                dict[file.url] = bookmark
            }
        }
        return dict
    }
}

// MARK: - Caching QEMU resources
extension UTMQemuVirtualMachine {
    private func _ensureQemuResourceCacheUpToDate() throws {
        let fm = FileManager.default
        let qemuResourceUrl = Bundle.main.url(forResource: "qemu", withExtension: nil)!
        let cacheUrl = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let qemuCacheUrl = cacheUrl.appendingPathComponent("qemu", isDirectory: true)

        guard fm.fileExists(atPath: qemuCacheUrl.path) else {
            try fm.copyItem(at: qemuResourceUrl, to: qemuCacheUrl)
            return
        }

        logger.info("Updating QEMU resource cache...")
        // first visit all the subdirectories and create them if needed
        let subdirectoryEnumerator = fm.enumerator(at: qemuResourceUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .producesRelativePathURLs, .includesDirectoriesPostOrder])!
        for case let directoryURL as URL in subdirectoryEnumerator {
            guard subdirectoryEnumerator.isEnumeratingDirectoryPostOrder else {
                continue
            }
            let relativePath = directoryURL.relativePath
            let destUrl = qemuCacheUrl.appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: destUrl.path, isDirectory: &isDirectory) {
                // old file is now a directory
                if !isDirectory.boolValue {
                    logger.info("Removing file \(destUrl.path)")
                    try fm.removeItem(at: destUrl)
                } else {
                    continue
                }
            }
            logger.info("Creating directory \(destUrl.path)")
            try fm.createDirectory(at: destUrl, withIntermediateDirectories: true)
        }
        // next check all the files
        let fileEnumerator = fm.enumerator(at: qemuResourceUrl, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles, .producesRelativePathURLs])!
        for case let sourceUrl as URL in fileEnumerator {
            let relativePath = sourceUrl.relativePath
            let sourceResourceValues = try sourceUrl.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
            guard !sourceResourceValues.isDirectory! else {
                continue
            }
            let destUrl = qemuCacheUrl.appendingPathComponent(relativePath)
            if fm.fileExists(atPath: destUrl.path) {
                // first do a quick comparsion with resource keys
                let destResourceValues = try destUrl.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
                // old directory is now a file
                if destResourceValues.isDirectory! {
                    logger.info("Removing directory \(destUrl.path)")
                    try fm.removeItem(at: destUrl)
                } else if destResourceValues.contentModificationDate == sourceResourceValues.contentModificationDate && destResourceValues.fileSize == sourceResourceValues.fileSize {
                    // assume the file is the same
                    continue
                } else {
                    logger.info("Removing file \(destUrl.path)")
                    try fm.removeItem(at: destUrl)
                }
            }
            // if we are here, the file has changed
            logger.info("Copying file \(sourceUrl.path) to \(destUrl.path)")
            try fm.copyItem(at: sourceUrl, to: destUrl)
        }
    }

    func ensureQemuResourceCacheUpToDate() async throws {
        guard !Self.isResourceCacheUpdated else {
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            Self.resourceCacheOperationQueue.async { [weak self] in
                do {
                    if !Self.isResourceCacheUpdated {
                        try self?._ensureQemuResourceCacheUpToDate()
                        Self.isResourceCacheUpdated = true
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errors

enum UTMQemuVirtualMachineError: Error {
    case failedToAccessShortcut
    case emulationNotSupported
    case qemuError(String)
    case accessDriveImageFailed
    case accessShareFailed
    case invalidVmState
    case saveSnapshotFailed(Error)
    case keyGenerationFailed
    case vulkanNotCompatible
    case vulkanVersionNotSupported
}

extension UTMQemuVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedToAccessShortcut:
            return NSLocalizedString("Failed to access data from shortcut.", comment: "UTMQemuVirtualMachine")
        case .emulationNotSupported:
            return NSLocalizedString("This build of UTM does not support emulating the architecture of this VM.", comment: "UTMQemuVirtualMachine")
        case .qemuError(let message):
            return message
        case .accessDriveImageFailed: return NSLocalizedString("Failed to access drive image path.", comment: "UTMQemuVirtualMachine")
        case .accessShareFailed: return NSLocalizedString("Failed to access shared directory.", comment: "UTMQemuVirtualMachine")
        case .invalidVmState: return NSLocalizedString("The virtual machine is in an invalid state.", comment: "UTMQemuVirtualMachine")
        case .saveSnapshotFailed(let error):
            return String.localizedStringWithFormat(NSLocalizedString("Failed to save VM snapshot. Usually this means at least one device does not support snapshots. %@", comment: "UTMQemuVirtualMachine"), error.localizedDescription)
        case .keyGenerationFailed:
            return NSLocalizedString("Failed to generate TLS key for server.", comment: "UTMQemuVirtualMachine")
        case .vulkanNotCompatible:
            return NSLocalizedString("The selected Vulkan driver is not compatible with the selected renderer backend.", comment: "UTMQemuVirtualMachine")
        case .vulkanVersionNotSupported:
            return NSLocalizedString("Host OS version is too old to support the selected Vulkan driver.", comment: "UTMQemuVirtualMachine")
        }
    }
}
