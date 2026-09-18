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
import AccessoryAccess

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
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

    /// `UTMAppleUSBPassthroughState` on macOS 27, always nil on older versions
    private var usbPassthroughState: Any?

    /// USB passthrough requires macOS 27
    var hasUsbRedirection: Bool {
        if #available(macOS 27, *) {
            return true
        } else {
            return false
        }
    }

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
            let isRestoring = isSuspended && !options.contains(.bootRecovery)
            try await beginAccessingResources()
            try await createAppleVM(isRestoring: isRestoring)
            if isRestoring {
                try await restoreSnapshot()
            } else {
                try await _start(options: options)
            }
            if #available(macOS 15, *) {
                try await attachExternalDrives()
            }
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
            state = .started
            if screenshotTimer == nil {
                screenshotTimer = startScreenshotTimer()
            }
            if #available(macOS 27, *), hasUsbRedirection {
                // failures here must not stop the virtual machine
                Task { @MainActor in
                    await startUsbPassthrough()
                }
            }
        } catch {
            await stopAccesingResources()
            if #available(macOS 27, *) {
                await stopUsbPassthrough()
            }
            await releaseFailedAppleVM()
            state = .stopped
            try? await deleteSnapshot()
            throw error
        }
    }
    
    private func _forceStop() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume() // already stopped
                    return
                }
                apple.stop { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        self.guestDidStop(apple)
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
        state = .stopping
        do {
            try await _forceStop()
            state = .stopped
        } catch {
            state = .stopped
            throw error
        }
    }
    
    private func _restart() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                apple.stop { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        apple.start { result in
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
        state = .stopping
        do {
            try await _restart()
            state = .started
            if #available(macOS 27, *) {
                await synchronizeUsbDevices()
            }
        } catch {
            state = .stopped
            throw error
        }
    }
    
    private func _pause() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                if self.isScreenshotEnabled {
                    Task { @MainActor in
                        await self.takeScreenshot()
                        try? self.saveScreenshot()
                    }
                }
                apple.pause { result in
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
        do {
            try await _pause()
            state = .paused
        } catch {
            state = .stopped
            throw error
        }
    }
    
    #if arch(arm64)
    @available(macOS 14, *)
    private func _saveSnapshot(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                apple.saveMachineStateTo(url: url) { error in
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
        guard name == nil else {
            throw UTMSnapshotError.notSupported
        }
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
        state = .saving
        defer {
            state = .paused
        }
        if #available(macOS 27, *) {
            await recordUsbDevicesForSave()
        }
        try await _saveSnapshot(url: vmSavedStateURL)
        await registryEntry.setIsSuspended(true)
        #endif
    }
    
    func deleteSnapshot(name: String? = nil) async throws {
        guard name == nil else {
            throw UTMSnapshotError.notSupported
        }
        guard let vmSavedStateURL = await config.system.boot.vmSavedStateURL else {
            return
        }
        await registryEntry.setIsSuspended(false)
        await registryEntry.setConnectedUsbDevices([])
        try FileManager.default.removeItem(at: vmSavedStateURL)
        try? updateLastModified()
    }
    
    #if arch(arm64)
    @available(macOS 14, *)
    private func _restoreSnapshot(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                apple.restoreMachineStateFrom(url: url) { error in
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
        guard name == nil else {
            throw UTMSnapshotError.notSupported
        }
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
        state = .restoring
        do {
            try await _restoreSnapshot(url: vmSavedStateURL)
            try await _resume()
        } catch {
            state = .stopped
            throw error
        }
        state = .started
        try await deleteSnapshot(name: name)
        #else
        throw UTMAppleVirtualMachineError.operationNotAvailable
        #endif
    }
    
    private func _resume() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                guard let apple = self.apple else {
                    continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                    return
                }
                apple.resume { result in
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
        do {
            try await _resume()
            state = .started
        } catch {
            state = .stopped
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

    @MainActor private func createAppleVM(isRestoring: Bool = false) async throws {
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
        var usbControllerDelegate: AnyObject?
        if #available(macOS 27, *), hasUsbRedirection {
            if isRestoring {
                await restoreUsbDevices(to: vzConfig)
            }
            usbControllerDelegate = usbState.controllerDelegate
        }
        vmQueue.async { [self] in
            apple = VZVirtualMachine(configuration: vzConfig, queue: vmQueue)
            apple!.delegate = self
            if #available(macOS 27, *), let usbControllerDelegate = usbControllerDelegate as? UTMAppleUSBControllerDelegate {
                apple!.usbControllers.first?.delegate = usbControllerDelegate
            }
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
    
    @MainActor private func closeSerialPorts() {
        for i in config.serials.indices {
            if let serialPort = config.serials[i].interface {
                serialPort.close()
                config.serials[i].interface = nil
                config.serials[i].fileHandleForReading = nil
                config.serials[i].fileHandleForWriting = nil
            }
        }
    }
    
    /// Release what `createAppleVM` set up when the virtual machine did not come up.
    ///
    /// No delegate callback follows a failed start, so without this the virtual machine would hold on
    /// to its devices (and any network they reserve) and the serial ports would stay open.
    private func releaseFailedAppleVM() async {
        let isReleased = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            vmQueue.async { [self] in
                if let apple = apple, apple.state != .stopped && apple.state != .error {
                    // the guest is alive, everything is released once it stops
                    continuation.resume(returning: false)
                    return
                }
                apple = nil
                snapshotUnsupportedError = nil
                continuation.resume(returning: true)
            }
        }
        if isReleased {
            await closeSerialPorts()
        }
    }
    
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
            progressObserver = nil
            installProgress = nil
            await stopAccesingResources()
            await releaseFailedAppleVM()
            delegate?.virtualMachine(self, didCompleteInstallation: false)
            state = .stopped
            let error = error as NSError
            if error.domain == "VZErrorDomain" && error.code == 10006 {
                throw UTMAppleVirtualMachineError.deviceSupportOutdated
            }
            #if os(macOS) && arch(arm64)
            if error.domain == "VZErrorDomain" && error.code == 10007,
               let versions = await Self.restoreImageVersionIfNewerThanHost(at: ipswUrl) {
                throw UTMAppleVirtualMachineError.installMacOSVersionTooNew(guestVersion: versions.guest, hostVersion: versions.host)
            }
            #endif
            throw error
        }
    }

    #if os(macOS) && arch(arm64)
    /// Returns the macOS version of a restore image when it is newer than the version running on this Mac.
    ///
    /// Installing a guest newer than the host is not supported by `VZMacOSInstaller`, but the restore only
    /// fails partway through with a generic error. We check the versions after a failure so the user can be
    /// told what to do about it. Returns nil if the versions cannot be compared or the guest is not newer.
    private static func restoreImageVersionIfNewerThanHost(at ipswUrl: URL) async -> (guest: String, host: String)? {
        let scopedAccess = ipswUrl.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                ipswUrl.stopAccessingSecurityScopedResource()
            }
        }
        guard let image = try? await VZMacOSRestoreImage.image(from: ipswUrl) else {
            return nil
        }
        let guest = image.operatingSystemVersion
        let host = ProcessInfo.processInfo.operatingSystemVersion
        let guestComponents = [guest.majorVersion, guest.minorVersion, guest.patchVersion]
        let hostComponents = [host.majorVersion, host.minorVersion, host.patchVersion]
        guard hostComponents.lexicographicallyPrecedes(guestComponents) else {
            return nil
        }
        return (guest: Self.versionString(guest), host: Self.versionString(host))
    }

    private static func versionString(_ version: OperatingSystemVersion) -> String {
        if version.patchVersion == 0 {
            return "\(version.majorVersion).\(version.minorVersion)"
        } else {
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
    }
    #endif
    
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

extension UTMAppleVirtualMachine: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        vmQueue.async { [self] in
            apple = nil
            snapshotUnsupportedError = nil
        }
        removableDrives.removeAll()
        sharedDirectoriesChanged = nil
        Task { @MainActor in
            stopAccesingResources()
            if #available(macOS 27, *) {
                stopUsbPassthrough()
            }
            closeSerialPorts()
        }
        try? saveScreenshot()
        state = .stopped
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        guestDidStop(virtualMachine)
        delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
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

// MARK: - USB passthrough

@available(macOS 27, *)
@MainActor extension UTMAppleVirtualMachine {
    private var usbState: UTMAppleUSBPassthroughState {
        if let state = usbPassthroughState as? UTMAppleUSBPassthroughState {
            return state
        }
        let state = UTMAppleUSBPassthroughState(vm: self)
        usbPassthroughState = state
        return state
    }

    /// Receives USB passthrough events (set by the primary window)
    var usbPassthroughDelegate: (any UTMAppleUSBPassthroughDelegate)? {
        get {
            usbState.delegate
        }

        set {
            usbState.delegate = newValue
        }
    }

    /// Is a window of this virtual machine the main window?
    var isUsbPassthroughFrontmost: Bool {
        usbState.delegate?.usbPassthroughIsFrontmost(self) ?? false
    }

    /// Host USB devices connected to this virtual machine
    var connectedUsbDevices: [UTMAppleUSBDevice] {
        usbState.connections.values.map(\.device)
    }

    /// Virtual machine in this process that holds a device
    /// - Parameter device: USB device
    /// - Returns: The virtual machine or nil if the device is not connected to any
    func usbDeviceOwner(_ device: UTMAppleUSBDevice) -> UTMAppleVirtualMachine? {
        UTMAppleUSBManager.shared.owner(of: device)
    }

    /// Connect a host USB device to the guest
    /// - Parameters:
    ///   - device: USB device
    ///   - takingOver: Disconnect the device from another virtual machine first
    func connectUsbDevice(_ device: UTMAppleUSBDevice, takingOver: Bool = false) async throws {
        // paused is allowed to reconnect devices after saving the state failed
        guard state == .started || state == .paused || state == .saving else {
            throw UTMAppleVirtualMachineError.operationNotAvailable
        }
        let manager = UTMAppleUSBManager.shared
        manager.unrelease(device)
        var device = device
        if let owner = manager.owner(of: device) {
            if owner === self {
                return // already connected
            }
            guard takingOver else {
                throw UTMAppleVirtualMachineError.usbDeviceInUse(device.name)
            }
            // the system reports the device again once it is detached from the other guest
            let claim = manager.claim(device.registryDevice, for: self, timeout: .seconds(5))
            do {
                try await owner.detachUsbDevice(device)
            } catch {
                claim.cancel()
                throw error
            }
            device = try await claim.value
        }
        try await attachUsbDevice(device)
    }

    /// Disconnect a host USB device from the guest at the request of the user
    ///
    /// The device stays assigned to UTM but is not connected again until the user asks for it.
    /// - Parameter device: USB device
    func disconnectUsbDevice(_ device: UTMAppleUSBDevice) async throws {
        UTMAppleUSBManager.shared.release(device)
        try await detachUsbDevice(device)
    }

    /// Called by the USB controller delegate when the system detached a device
    /// - Parameter uuid: Identifier of the detached `VZUSBPassthroughDevice`
    func usbPassthroughDeviceDidDisconnect(uuid: UUID) {
        guard let (registryID, connection) = usbState.connections.first(where: { $0.value.vzDevice.uuid == uuid }) else {
            return
        }
        usbState.connections.removeValue(forKey: registryID)
        UTMAppleUSBManager.shared.setOwner(nil, of: connection.device)
        logger.debug("USB device detached from guest: \(connection.device.name)")
        usbState.delegate?.usbPassthrough(self, deviceDidDisconnect: connection.device)
    }

    /// Called by the USB manager when a connected device is no longer reported by the system
    /// - Parameter device: USB device
    func usbHostDeviceDidDisconnect(_ device: UTMAppleUSBDevice) {
        // the USB controller delegate normally reports this first
        if let connection = usbState.connections.removeValue(forKey: device.registryID) {
            usbState.delegate?.usbPassthrough(self, deviceDidDisconnect: connection.device)
        }
    }

    /// Connect a device the system delivered to this virtual machine, reporting failures to the delegate
    /// - Parameter device: USB device
    func autoConnectUsbDevice(_ device: UTMAppleUSBDevice) async {
        do {
            try await connectUsbDevice(device)
        } catch {
            logger.debug("Failed to connect USB device \(device.name): \(error)")
            usbState.delegate?.usbPassthrough(self, device: device, didFailWithError: error)
        }
    }

    private func attachUsbDevice(_ device: UTMAppleUSBDevice) async throws {
        let manager = UTMAppleUSBManager.shared
        manager.setOwner(self, of: device)
        do {
            let configuration = VZUSBPassthroughDeviceConfiguration(device: device.accessory)
            let vzDevice = try VZUSBPassthroughDevice(configuration: configuration)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                vmQueue.async {
                    guard let apple = self.apple, let usbController = apple.usbControllers.first else {
                        continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                        return
                    }
                    usbController.attach(device: vzDevice) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            usbState.connections[device.registryID] = UTMAppleUSBPassthroughState.Connection(device: device, vzDevice: vzDevice)
            logger.debug("Connected USB device \(device.name)")
        } catch {
            manager.setOwner(nil, of: device)
            throw error
        }
    }

    private func detachUsbDevice(_ device: UTMAppleUSBDevice) async throws {
        guard let connection = usbState.connections[device.registryID] else {
            throw UTMAppleVirtualMachineError.usbDeviceNotConnected(device.name)
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                vmQueue.async {
                    guard let apple = self.apple, let usbController = apple.usbControllers.first else {
                        continuation.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                        return
                    }
                    usbController.detach(device: connection.vzDevice) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
        } catch let error as VZError where error.code == .deviceNotFound {
            // already detached by the system
        }
        usbState.connections.removeValue(forKey: device.registryID)
        UTMAppleUSBManager.shared.setOwner(nil, of: device)
    }

    // MARK: Lifecycle

    /// Called after the virtual machine started to pick up restored devices and receive new ones
    private func startUsbPassthrough() async {
        let manager = UTMAppleUSBManager.shared
        manager.addVirtualMachine(self)
        do {
            try await manager.ensureRegistered()
        } catch {
            logger.debug("USB passthrough unavailable: \(error)")
            return
        }
        await synchronizeUsbDevices()
    }

    /// Called when the virtual machine stopped or failed to start
    private func stopUsbPassthrough() {
        UTMAppleUSBManager.shared.removeVirtualMachine(self)
        guard let state = usbPassthroughState as? UTMAppleUSBPassthroughState else {
            return
        }
        state.connections.removeAll()
        state.pendingRestore.removeAll()
    }

    /// Match the tracked connections with the devices attached to the USB controller
    ///
    /// This picks up devices restored from a saved state and drops devices the system detached.
    private func synchronizeUsbDevices() async {
        let vzDevices: [any VZUSBDevice] = await withCheckedContinuation { continuation in
            vmQueue.async {
                continuation.resume(returning: self.apple?.usbControllers.first?.usbDevices ?? [])
            }
        }
        let attached = vzDevices.compactMap { $0 as? VZUSBPassthroughDevice }
        let manager = UTMAppleUSBManager.shared
        for (uuid, device) in usbState.pendingRestore {
            if let vzDevice = attached.first(where: { $0.uuid == uuid }) {
                usbState.connections[device.registryID] = UTMAppleUSBPassthroughState.Connection(device: device, vzDevice: vzDevice)
            } else {
                manager.setOwner(nil, of: device)
            }
        }
        usbState.pendingRestore.removeAll()
        for (registryID, connection) in usbState.connections where !attached.contains(where: { $0 === connection.vzDevice }) {
            usbState.connections.removeValue(forKey: registryID)
            manager.setOwner(nil, of: connection.device)
        }
    }

    // MARK: Saved state

    /// Add saved devices to the configuration with their UUID so they are part of the restored state
    ///
    /// The saved state references the devices by UUID. A device that is missing is skipped and the
    /// guest sees it as unplugged.
    /// - Parameter vzConfig: Configuration of the virtual machine to restore
    private func restoreUsbDevices(to vzConfig: VZVirtualMachineConfiguration) async {
        let saved = registryEntry.connectedUsbDevices.filter { $0.uuid != nil }
        guard !saved.isEmpty, let controller = vzConfig.usbControllers.first else {
            return
        }
        let manager = UTMAppleUSBManager.shared
        do {
            try await manager.ensureRegistered()
        } catch {
            logger.debug("USB passthrough unavailable: \(error)")
            return
        }
        var configurations = controller.usbDevices
        for entry in saved {
            guard let uuid = entry.uuid, let device = await manager.device(matching: entry, timeout: .seconds(2)) else {
                logger.debug("Saved USB device \(entry.name) not found")
                continue
            }
            let configuration = VZUSBPassthroughDeviceConfiguration(device: device.accessory)
            configuration.uuid = uuid
            configurations.append(configuration)
            manager.setOwner(self, of: device)
            usbState.pendingRestore[uuid] = device
        }
        controller.usbDevices = configurations
    }

    /// Record the connected devices with their UUID so they can be part of the restored state
    private func recordUsbDevicesForSave() async {
        let saved = usbState.connections.values.map { connection in
            var entry = connection.device.registryDevice
            entry.uuid = connection.vzDevice.uuid
            return entry
        }
        registryEntry.setConnectedUsbDevices(saved)
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
    case installMacOSVersionTooNew(guestVersion: String, hostVersion: String)
    case usbDeviceNotFound(String)
    case usbDeviceInUse(String)
    case usbDeviceNotConnected(String)
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
        case .installMacOSVersionTooNew(let guestVersion, let hostVersion):
            return String.localizedStringWithFormat(NSLocalizedString("Installation failed because macOS %1$@ is newer than macOS %2$@ running on this Mac. Update this Mac to macOS %1$@ or later and try again, or install an older version of macOS.", comment: "UTMAppleVirtualMachine"), guestVersion, hostVersion)
        case .usbDeviceNotFound(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The USB device '%@' cannot be found.", comment: "UTMAppleVirtualMachine"), name)
        case .usbDeviceInUse(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The USB device '%@' is already connected to another virtual machine.", comment: "UTMAppleVirtualMachine"), name)
        case .usbDeviceNotConnected(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The USB device '%@' is not connected to this virtual machine.", comment: "UTMAppleVirtualMachine"), name)
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
