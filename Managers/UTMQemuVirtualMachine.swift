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

/// QEMU backend virtual machine
@objc class UTMQemuVirtualMachine: UTMVirtualMachine {
    /// Set to true to request guest tools install.
    ///
    /// This property is observable and must only be accessed on the main thread.
    @Published var isGuestToolsInstallRequested: Bool = false
    
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
}

// MARK: - Shortcut access
extension UTMQemuVirtualMachine {
    override func accessShortcut() async throws {
        guard isShortcut else {
            return
        }
        // if VM has not started yet, we create a temporary process
        let system = await system ?? UTMQemu()
        var bookmark = await registryEntry.package.remoteBookmark
        let existing = bookmark != nil
        if !existing {
            // create temporary bookmark
            bookmark = try path.bookmarkData()
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
        guard let efiVarsURL = qemuConfig.qemu.efiVarsURL else {
            return
        }
        guard qemuConfig.isLegacy else {
            return
        }
        _ = try await qemuConfig.qemu.saveData(to: efiVarsURL.deletingLastPathComponent(), for: qemuConfig.system)
    }
    
    private func _vmStart() async throws {
        // check if we can actually start this VM
        guard isSupported else {
            throw UTMQemuVirtualMachineError.emulationNotSupported
        }
        // start logging
        if await qemuConfig.qemu.hasDebugLog, let debugLogURL = await qemuConfig.qemu.debugLogURL {
            logging.log(toFile: debugLogURL)
        }
        await MainActor.run {
            qemuConfig.qemu.isDisposable = isRunningAsSnapshot
        }
        
        let allArguments = await qemuConfig.allArguments
        let arguments = allArguments.map({ $0.string })
        let resources = allArguments.compactMap({ $0.fileUrls }).flatMap({ $0 })
        let remoteBookmarks = await remoteBookmarks
        
        let system = await UTMQemuSystem(arguments: arguments, architecture: qemuConfig.system.architecture.rawValue)
        system.resources = resources
        system.remoteBookmarks = remoteBookmarks as NSDictionary
        system.rendererBackend = rendererBackend
        try Task.checkCancellation()
        
        if isShortcut {
            try await accessShortcut()
            try Task.checkCancellation()
        }
        
        let ioService = UTMSpiceIO(configuration: config)
        try ioService.start()
        try Task.checkCancellation()
        
        // create EFI variables for legacy config
        // this is ugly code and should be removed when legacy config support is removed
        try await qemuEnsureEfiVarsAvailable()
        try Task.checkCancellation()
        
        // start QEMU
        await qemuVM.setDelegate(self)
        try await qemuVM.start(launcher: system, interface: ioService)
        let monitor = await monitor!
        try Task.checkCancellation()
        
        // load saved state if requested
        if !isRunningAsSnapshot, await registryEntry.isSuspended {
            try await monitor.qemuRestoreSnapshot(kSuspendSnapshotName)
            try Task.checkCancellation()
        }
        
        // set up SPICE sharing and removable drives
        try await self.restoreExternalDrives()
        try await self.restoreSharedDirectory()
        try Task.checkCancellation()
        
        // continue VM boot
        try await monitor.continueBoot()
        
        // delete saved state
        if await registryEntry.isSuspended {
            try? await _vmDeleteState()
        }
        
        // save ioService and let it set the delegate
        self.ioService = ioService
    }
    
    override func vmStart() async throws {
        guard state == .vmStopped else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        changeState(.vmStarting)
        do {
            startTask = Task {
                try await _vmStart()
            }
            defer {
                startTask = nil
            }
            try await startTask!.value
            changeState(.vmStarted)
        } catch {
            // delete suspend state on error
            await registryEntry.setIsSuspended(false)
            changeState(.vmStopped)
            throw error
        }
    }
    
    override func vmStop(force: Bool) async throws {
        if force {
            // prevent deadlock force stopping during startup
            ioService?.disconnect()
        }
        guard state != .vmStopped else {
            return // nothing to do
        }
        guard force || state == .vmStarted else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        if !force {
            changeState(.vmStopping)
        }
        defer {
            changeState(.vmStopped)
        }
        if force {
            await qemuVM.kill()
        } else {
            try await qemuVM.stop()
        }
    }
    
    private func _vmReset() async throws {
        if await registryEntry.isSuspended {
            try? await _vmDeleteState()
        }
        guard let monitor = await qemuVM.monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await monitor.qemuReset()
    }
    
    override func vmReset() async throws {
        guard state == .vmStarted || state == .vmPaused else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        changeState(.vmStopping)
        do {
            try await _vmReset()
            changeState(.vmStarted)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    private func _vmPause() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        await updateScreenshot()
        await saveScreenshot()
        try await monitor.qemuStop()
    }
    
    override func vmPause(save: Bool) async throws {
        guard state == .vmStarted else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        changeState(.vmPausing)
        do {
            try await _vmPause()
            if save {
                try? await _vmSaveState()
            }
            changeState(.vmPaused)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    private func _vmSaveState() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        do {
            let result = try await monitor.qemuSaveSnapshot(kSuspendSnapshotName)
            if result.localizedCaseInsensitiveContains("Error") {
                throw UTMQemuVirtualMachineError.qemuError(result)
            }
            await registryEntry.setIsSuspended(true)
            await saveScreenshot()
        } catch {
            throw UTMQemuVirtualMachineError.saveSnapshotFailed(error)
        }
    }
    
    override func vmSaveState() async throws {
        guard state == .vmPaused || state == .vmStarted else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await _vmSaveState()
    }
    
    private func _vmDeleteState() async throws {
        if let monitor = await monitor { // if QEMU is running
            let result = try await monitor.qemuDeleteSnapshot(kSuspendSnapshotName)
            if result.localizedCaseInsensitiveContains("Error") {
                throw UTMQemuVirtualMachineError.qemuError(result)
            }
        }
        await registryEntry.setIsSuspended(false)
    }
    
    override func vmDeleteState() async throws {
        try await _vmDeleteState()
    }
    
    private func _vmResume() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await monitor.qemuResume()
        if await registryEntry.isSuspended {
            try? await _vmDeleteState()
        }
    }
    
    override func vmResume() async throws {
        guard state == .vmPaused else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        changeState(.vmResuming)
        do {
            try await _vmResume()
            changeState(.vmStarted)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    override func vmGuestPowerDown() async throws {
        guard let monitor = await monitor else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        try await monitor.qemuPowerDown()
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
        changeState(.vmStopped)
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
            guard index >= 0 && index < qemuConfig.serials.count else {
                logger.error("Serial device '\(path)' out of bounds for index \(index)")
                return
            }
            qemuConfig.serials[index].pttyDevice = URL(fileURLWithPath: path)
        }
    }
}

// MARK: - Input device switching
extension UTMQemuVirtualMachine {
    func requestInputTablet(_ tablet: Bool) {
        
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
    @MainActor
    override func updateScreenshot() {
        ioService?.screenshot(completion: { screenshot in
            Task { @MainActor in
                self.screenshot = screenshot
            }
        })
    }
    
    @MainActor
    override func saveScreenshot() {
        super.saveScreenshot()
    }
}

// MARK: - Display details
extension UTMQemuVirtualMachine {
    internal var qemuConfig: UTMQemuConfiguration {
        config.qemuConfig!
    }
    
    @MainActor override var detailsTitleLabel: String {
        qemuConfig.information.name
    }
    
    @MainActor override var detailsSubtitleLabel: String {
        detailsSystemTargetLabel
    }
    
    @MainActor override var detailsNotes: String? {
        qemuConfig.information.notes
    }
    
    @MainActor override var detailsSystemTargetLabel: String {
        qemuConfig.system.target.prettyValue
    }
    
    @MainActor override var detailsSystemArchitectureLabel: String {
        qemuConfig.system.architecture.prettyValue
    }
    
    @MainActor override var detailsSystemMemoryLabel: String {
        let bytesInMib = Int64(1048576)
        return ByteCountFormatter.string(fromByteCount: Int64(qemuConfig.system.memorySize) * bytesInMib, countStyle: .binary)
    }
    
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
    @objc var isSupported: Bool {
        return UTMQemuVirtualMachine.isSupported(systemArchitecture: qemuConfig._system.architecture)
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
    
    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let tempBookmark = try url.bookmarkData()
        try await eject(drive, isForced: true)
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
        await registryEntry.setExternalDrive(file, forId: drive.id)
        try await changeMedium(drive, with: tempBookmark, url: url, isSecurityScoped: false)
    }
    
    private func changeMedium(_ drive: UTMQemuConfigurationDrive, with bookmark: Data, url: URL?, isSecurityScoped: Bool) async throws {
        let system = await system ?? UTMQemu()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateExternalDriveRemoteBookmark(bookmark, forId: drive.id)
        if let qemu = await monitor, qemu.isConnected {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives() async throws {
        guard await system != nil else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        for drive in await qemuConfig.drives {
            if !drive.isExternal {
                continue
            }
            let id = drive.id
            if let bookmark = await registryEntry.externalDrives[id]?.remoteBookmark {
                // an image bookmark was saved while QEMU was running
                try await changeMedium(drive, with: bookmark, url: nil, isSecurityScoped: true)
            } else if let localBookmark = await registryEntry.externalDrives[id]?.bookmark {
                // an image bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: localBookmark)
                try await changeMedium(drive, to: url)
            } else {
                // a placeholder image might have been mounted
                try await eject(drive)
            }
        }
    }
    
    @objc func restoreExternalDrivesAndShares(completion: @escaping (Error?) -> Void) {
        Task.detached {
            do {
                try await self.restoreExternalDrives()
                try await self.restoreSharedDirectory()
                completion(nil)
            } catch {
                completion(error)
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
        let file = try await UTMRegistryEntry.File(url: url, isReadOnly: qemuConfig.sharing.isDirectoryShareReadOnly)
        await registryEntry.setSingleSharedDirectory(file)
        if await qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(url)
            }
        } else if await qemuConfig.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }
    
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        let system = await system ?? UTMQemu()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let _ = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateSingleSharedDirectoryRemoteBookmark(bookmark)
    }
    
    func restoreSharedDirectory() async throws {
        guard let share = await registryEntry.sharedDirectories.first else {
            return
        }
        if await qemuConfig.sharing.directoryShareMode == .virtfs {
            if let bookmark = share.remoteBookmark {
                // a share bookmark was saved while QEMU was running
                try await changeVirtfsSharedDirectory(with: bookmark, isSecurityScoped: true)
            } else {
                // a share bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: share.bookmark)
                try await changeSharedDirectory(to: url)
            }
        } else if await qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(share.url)
            }
        }
    }
}

// MARK: - Registry syncing
extension UTMQemuVirtualMachine {
    @MainActor override func updateRegistryFromConfig() async throws {
        // save a copy to not collide with updateConfigFromRegistry()
        let configShare = qemuConfig.sharing.directoryShareUrl
        let configDrives = qemuConfig.drives
        try await super.updateRegistryFromConfig()
        for drive in configDrives {
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
            }
        }
        if let url = configShare {
            try await changeSharedDirectory(to: url)
        }
        // remove any unreferenced drives
        registryEntry.externalDrives = registryEntry.externalDrives.filter({ element in
            configDrives.contains(where: { $0.id == element.key && $0.isExternal })
        })
    }
    
    @MainActor override func updateConfigFromRegistry() {
        super.updateConfigFromRegistry()
        qemuConfig.sharing.directoryShareUrl = sharedDirectoryURL
        for i in qemuConfig.drives.indices {
            let id = qemuConfig.drives[i].id
            if qemuConfig.drives[i].isExternal {
                qemuConfig.drives[i].imageURL = registryEntry.externalDrives[id]?.url
            }
        }
    }
    
    @MainActor @objc var remoteBookmarks: [URL: Data] {
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
