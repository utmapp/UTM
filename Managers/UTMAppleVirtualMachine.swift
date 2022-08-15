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
@objc class UTMAppleVirtualMachine: UTMVirtualMachine {
    private let quitTimeoutSeconds = DispatchTimeInterval.seconds(30)
    
    var appleConfig: UTMAppleConfiguration {
        config.appleConfig!
    }
    
    override var detailsTitleLabel: String {
        appleConfig.information.name
    }
    
    override var detailsSubtitleLabel: String {
        detailsSystemTargetLabel
    }
    
    override var detailsNotes: String? {
        appleConfig.information.notes
    }
    
    override var detailsSystemTargetLabel: String {
        appleConfig.system.boot.operatingSystem.rawValue
    }
    
    override var detailsSystemArchitectureLabel: String {
        appleConfig.system.architecture
    }
    
    override var detailsSystemMemoryLabel: String {
        let bytesInMib = Int64(1048576)
        return ByteCountFormatter.string(fromByteCount: Int64(appleConfig.system.memorySize) * bytesInMib, countStyle: .memory)
    }
    
    override var hasSaveState: Bool {
        false
    }
    
    private let vmQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)
    
    private(set) var apple: VZVirtualMachine!
    
    private var progressObserver: NSKeyValueObservation?
    
    private var sharedDirectoriesChanged: AnyCancellable?
    
    weak var screenshotDelegate: UTMScreenshotProvider?
    
    private var activeResourceUrls: [URL] = []
    
    override func reloadConfiguration() throws {
        let newConfig = try UTMAppleConfiguration.load(from: path) as! UTMAppleConfiguration
        let oldConfig = appleConfig
        // copy non-persistent values over
        newConfig.sharedDirectories = oldConfig.sharedDirectories
        if #available(macOS 12, *) {
            newConfig.system.boot.macRecoveryIpswURL = oldConfig.system.boot.macRecoveryIpswURL
        }
        config = UTMConfigurationWrapper(wrapping: newConfig)
    }
    
    override func accessShortcut() async throws {
        // not needed for Apple VMs
    }
    
    private func _vmStart() async throws {
        try createAppleVM()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            vmQueue.async {
                #if os(macOS) && arch(arm64)
                let boot = self.appleConfig.system.boot
                if #available(macOS 13, *), boot.operatingSystem == .macOS {
                    let options = VZMacOSVirtualMachineStartOptions()
                    options.startUpFromMacOSRecovery = boot.startUpFromMacOSRecovery
                    self.apple.start(options: options) { result in
                        if let result = result {
                            continuation.resume(with: .failure(result))
                        } else {
                            continuation.resume()
                        }
                    }
                    return
                }
                #endif
                self.apple.start { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    override func vmStart() async throws {
        guard state == .vmStopped else {
            return
        }
        changeState(.vmStarting)
        do {
            try await beginAccessingResources()
            try await _vmStart()
            if #available(macOS 12, *) {
                sharedDirectoriesChanged = appleConfig.$sharedDirectories.sink { [weak self] newShares in
                    guard let self = self else {
                        return
                    }
                    self.vmQueue.async {
                        self.updateSharedDirectories(with: newShares)
                    }
                }
            }
            changeState(.vmStarted)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    private func _vmStop(force: Bool) async throws {
        if force, #available(macOS 12, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                vmQueue.async {
                    self.apple.stop { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            self.guestDidStop(self.apple)
                            continuation.resume()
                        }
                    }
                }
            }
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                vmQueue.async {
                    do {
                        try self.apple.requestStop()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    override func vmStop(force: Bool) async throws {
        guard state == .vmStarted else {
            return
        }
        changeState(.vmStopping)
        do {
            try await _vmStop(force: force)
            changeState(.vmStopped)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    private func _vmReset() async throws {
        guard #available(macOS 12, *) else {
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                self.apple.stop { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        self.apple.start { result in
                            continuation.resume(with: result)
                        }
                    }
                }
            }
        }
    }
    
    override func vmReset() async throws {
        guard state == .vmStarted || state == .vmPaused else {
            return
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                DispatchQueue.main.sync {
                    self.updateScreenshot()
                }
                self.saveScreenshot()
                self.apple.pause { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    override func vmPause(save: Bool) async throws {
        changeState(.vmPausing)
        do {
            try await _vmPause()
            changeState(.vmPaused)
        } catch {
            changeState(.vmStopped)
            throw error
        }
    }
    
    override func vmSaveState() async throws {
        // FIXME: implement this
    }
    
    override func vmDeleteState() async throws {
        // FIXME: implement this
    }
    
    private func _vmResume() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                self.apple.resume { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    override func vmResume() async throws {
        guard state == .vmPaused else {
            return
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
    
    override func updateScreenshot() {
        screenshot = screenshotDelegate?.screenshot
    }
    
    private func createAppleVM() throws {
        for i in appleConfig.serials.indices {
            let (fd, sfd, name) = try createPty()
            let terminalTtyHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            let slaveTtyHandle = FileHandle(fileDescriptor: sfd, closeOnDealloc: false)
            appleConfig.serials[i].fileHandleForReading = terminalTtyHandle
            appleConfig.serials[i].fileHandleForWriting = terminalTtyHandle
            Task { @MainActor in
                let serialPort = UTMSerialPort(portNamed: name, readFileHandle: slaveTtyHandle, writeFileHandle: slaveTtyHandle, terminalFileHandle: terminalTtyHandle)
                appleConfig.serials[i].interface = serialPort
            }
        }
        let vzConfig = appleConfig.appleVZConfiguration
        apple = VZVirtualMachine(configuration: vzConfig, queue: vmQueue)
        apple.delegate = self
    }
    
    @available(macOS 12, *)
    private func updateSharedDirectories(with newShares: [UTMAppleConfigurationSharedDirectory]) {
        guard let fsConfig = apple?.directorySharingDevices.first(where: { device in
            if let device = device as? VZVirtioFileSystemDevice {
                return device.tag == "share"
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
        guard state == .vmStopped else {
            return
        }
        changeState(.vmStarting)
        try createAppleVM()
        #if os(macOS) && arch(arm64)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vmQueue.async {
                let installer = VZMacOSInstaller(virtualMachine: self.apple, restoringFromImageAt: ipswUrl)
                self.progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
                    self.delegate?.virtualMachine?(self, didUpdateInstallationProgress: progress.fractionCompleted)
                }
                installer.install { result in
                    continuation.resume(with: result)
                }
            }
        }
        changeState(.vmStarted)
        progressObserver = nil
        #else
        changeState(.vmStopped)
        #endif
    }
    
    @available(macOS 12, *)
    func requestInstallVM(with ipswUrl: URL) {
        Task {
            do {
                try await installVM(with: ipswUrl)
            } catch {
                await MainActor.run {
                    delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
                }
            }
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
        for i in appleConfig.drives.indices {
            let drive = appleConfig.drives[i]
            if let url = drive.imageURL, drive.isExternal {
                if url.startAccessingSecurityScopedResource() {
                    activeResourceUrls.append(url)
                } else {
                    appleConfig.drives[i].imageURL = nil
                    throw UTMAppleVirtualMachineError.cannotAccessResource(url)
                }
            }
        }
        for i in appleConfig.sharedDirectories.indices {
            let share = appleConfig.sharedDirectories[i]
            if let url = share.directoryURL {
                if url.startAccessingSecurityScopedResource() {
                    activeResourceUrls.append(url)
                } else {
                    appleConfig.sharedDirectories[i].directoryURL = nil
                    throw UTMAppleVirtualMachineError.cannotAccessResource(url)
                }
            }
        }
    }
    
    @MainActor private func stopAccesingResources() {
        for url in activeResourceUrls {
            url.stopAccessingSecurityScopedResource()
        }
        activeResourceUrls.removeAll()
    }
}

@available(macOS 11, *)
extension UTMAppleVirtualMachine: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        apple = nil
        sharedDirectoriesChanged = nil
        Task { @MainActor in
            stopAccesingResources()
        }
        for i in appleConfig.serials.indices {
            if let serialPort = appleConfig.serials[i].interface {
                serialPort.close()
                Task { @MainActor in
                    appleConfig.serials[i].interface = nil
                    appleConfig.serials[i].fileHandleForReading = nil
                    appleConfig.serials[i].fileHandleForWriting = nil
                }
            }
        }
        changeState(.vmStopped)
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        guestDidStop(virtualMachine)
        DispatchQueue.main.async {
            self.delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
        }
    }
}

protocol UTMScreenshotProvider: AnyObject {
    var screenshot: CSScreenshot? { get }
}

enum UTMAppleVirtualMachineError: Error {
    case cannotAccessResource(URL)
}

extension UTMAppleVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotAccessResource(let url):
            return String.localizedStringWithFormat(NSLocalizedString("Cannot access resource: %@", comment: "UTMAppleVirtualMachine"), url.path)
        }
    }
}
