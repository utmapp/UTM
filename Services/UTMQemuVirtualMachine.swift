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

private var SpiceIoServiceGuestAgentContext = 0
private let kSuspendSnapshotName = "suspend"
private let kProbeSuspendDelay = 1*NSEC_PER_SEC

/// QEMU backend virtual machine
final class UTMQemuVirtualMachine: UTMVirtualMachine {
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
    
    private(set) var screenshot: PlatformImage? {
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
    
    private let qemuVM = QEMUVirtualMachine()
    
    private var system: UTMQemuSystem? {
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
    
    @MainActor private func qemuEnsureEfiVarsAvailable() async throws {
        guard let efiVarsURL = config.qemu.efiVarsURL else {
            return
        }
        var doesVarsExist = FileManager.default.fileExists(atPath: efiVarsURL.path)
        if config.qemu.isUefiVariableResetRequested {
            if doesVarsExist {
                try FileManager.default.removeItem(at: efiVarsURL)
                doesVarsExist = false
            }
            config.qemu.isUefiVariableResetRequested = false
        }
        if !doesVarsExist {
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
        let hasDebugLog = await config.qemu.hasDebugLog
        // start logging
        if hasDebugLog, let debugLogURL = await config.qemu.debugLogURL {
            await qemuVM.setRedirectLog(url: debugLogURL)
        } else {
            await qemuVM.setRedirectLog(url: nil)
        }
        let isRunningAsDisposible = options.contains(.bootDisposibleMode)
        await MainActor.run {
            config.qemu.isDisposable = isRunningAsDisposible
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
        let ioService = UTMSpiceIO(socketUrl: spiceSocketUrl, options: options)
        ioService.logHandler = { [weak system] (line: String) -> Void in
            guard !line.contains("spice_make_scancode") else {
                return // do not log key presses for privacy reasons
            }
            system?.logging?.writeLine(line)
        }
        try ioService.start()
        try Task.checkCancellation()
        
        // create EFI variables for legacy config as well as handle UEFI resets
        try await qemuEnsureEfiVarsAvailable()
        try Task.checkCancellation()
        
        // start QEMU
        await qemuVM.setDelegate(self)
        try await qemuVM.start(launcher: system, interface: ioService)
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
        try await self.restoreSharedDirectory(for: ioService)
        try Task.checkCancellation()
        
        // continue VM boot
        try await monitor.continueBoot()
        
        // delete saved state
        if isSuspended {
            try? await deleteSnapshot()
        }
        
        // save ioService and let it set the delegate
        self.ioService = ioService
        self.isRunningAsDisposible = isRunningAsDisposible
        
        // test out snapshots
        self.snapshotUnsupportedError = await determineSnapshotSupport()
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
            if screenshotTimer == nil {
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
        await takeScreenshot()
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
        swtpm?.stop()
        swtpm = nil
        ioService = nil
        ioServiceDelegate = nil
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
    func requestInputTablet(_ tablet: Bool) {
        guard !changeCursorRequestInProgress else {
            return
        }
        guard let spiceIO = ioService else {
            return
        }
        changeCursorRequestInProgress = true
        Task {
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
                try await monitor.mouseSelect(index)
                spiceIO.primaryInput?.requestMouseMode(!tablet)
            } catch {
                logger.error("Error changing mouse mode: \(error)")
            }
        }
    }
}

// MARK: - USB redirection
extension UTMQemuVirtualMachine {
    var hasUsbRedirection: Bool {
        return jb_has_usb_entitlement()
    }
}

// MARK: - Screenshot
extension UTMQemuVirtualMachine {
    @MainActor @discardableResult
    func takeScreenshot() async -> Bool {
        let screenshot = await ioService?.screenshot()
        self.screenshot = screenshot?.image
        return true
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
    func eject(_ drive: UTMQemuConfigurationDrive, isForced: Bool = false) async throws {
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
    
    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL, isAccessOnly: Bool = false) async throws {
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let tempBookmark = try url.bookmarkData()
        try await eject(drive, isForced: true)
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
        await registryEntry.setExternalDrive(file, forId: drive.id)
        try await changeMedium(drive, with: tempBookmark, url: url, isSecurityScoped: false, isAccessOnly: isAccessOnly)
    }
    
    private func changeMedium(_ drive: UTMQemuConfigurationDrive, with bookmark: Data, url: URL?, isSecurityScoped: Bool, isAccessOnly: Bool) async throws {
        let system = await system ?? UTMProcess()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateExternalDriveRemoteBookmark(bookmark, forId: drive.id)
        if let qemu = await monitor, qemu.isConnected && !isAccessOnly {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives(withMounting isMounting: Bool) async throws {
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
                try await changeMedium(drive, with: bookmark, url: nil, isSecurityScoped: true, isAccessOnly: !isMounting)
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
    
    @MainActor func externalImageURL(for drive: UTMQemuConfigurationDrive) -> URL? {
        registryEntry.externalDrives[drive.id]?.url
    }
}

// MARK: - Shared directory
extension UTMQemuVirtualMachine {
    @MainActor var sharedDirectoryURL: URL? {
        registryEntry.sharedDirectories.first?.url
    }
    
    func clearSharedDirectory() async {
        if let oldPath = await registryEntry.sharedDirectories.first?.path {
            await system?.stopAccessingPath(oldPath)
        }
        await registryEntry.removeAllSharedDirectories()
    }
    
    func changeSharedDirectory(to url: URL) async throws {
        await clearSharedDirectory()
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let file = try await UTMRegistryEntry.File(url: url, isReadOnly: config.sharing.isDirectoryShareReadOnly)
        await registryEntry.setSingleSharedDirectory(file)
        if await config.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(url)
            }
        } else if await config.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }
    
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        let system = await system ?? UTMProcess()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let _ = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateSingleSharedDirectoryRemoteBookmark(bookmark)
    }
    
    func restoreSharedDirectory(for ioService: UTMSpiceIO) async throws {
        guard let share = await registryEntry.sharedDirectories.first else {
            return
        }
        if await config.sharing.directoryShareMode == .virtfs {
            if let bookmark = share.remoteBookmark {
                // a share bookmark was saved while QEMU was running
                try await changeVirtfsSharedDirectory(with: bookmark, isSecurityScoped: true)
            } else {
                // a share bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: share.bookmark)
                try await changeSharedDirectory(to: url)
            }
        } else if await config.sharing.directoryShareMode == .webdav {
            ioService.changeSharedDirectory(share.url)
        }
    }
}

// MARK: - Registry syncing
extension UTMQemuVirtualMachine {
    @MainActor func updateRegistryFromConfig() async throws {
        // save a copy to not collide with updateConfigFromRegistry()
        let configShare = config.sharing.directoryShareUrl
        let configDrives = config.drives
        try await updateRegistryBasics()
        for drive in configDrives {
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
            } else if drive.isExternal {
                try await eject(drive)
            }
        }
        if let url = configShare {
            try await changeSharedDirectory(to: url)
        } else {
            await clearSharedDirectory()
        }
        // remove any unreferenced drives
        registryEntry.externalDrives = registryEntry.externalDrives.filter({ element in
            configDrives.contains(where: { $0.id == element.key && $0.isExternal })
        })
    }
    
    @MainActor func updateConfigFromRegistry() {
        config.sharing.directoryShareUrl = sharedDirectoryURL
        for i in config.drives.indices {
            let id = config.drives[i].id
            if config.drives[i].isExternal {
                config.drives[i].imageURL = registryEntry.externalDrives[id]?.url
            }
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

enum UTMQemuVirtualMachineError: Error {
    case failedToAccessShortcut
    case emulationNotSupported
    case qemuError(String)
    case accessDriveImageFailed
    case accessShareFailed
    case invalidVmState
    case saveSnapshotFailed(Error)
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
        }
    }
}
