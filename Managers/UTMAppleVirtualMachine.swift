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
    
    override var config: UTMConfigurable {
        didSet {
            configChanged = appleConfig.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    
    var appleConfig: UTMAppleConfiguration! {
        config as? UTMAppleConfiguration
    }
    
    override var detailsTitleLabel: String {
        appleConfig.name
    }
    
    override var detailsSubtitleLabel: String {
        detailsSystemTargetLabel
    }
    
    override var detailsNotes: String? {
        appleConfig.notes
    }
    
    override var detailsSystemTargetLabel: String {
        appleConfig.bootLoader?.operatingSystem.rawValue ?? ""
    }
    
    override var detailsSystemArchitectureLabel: String {
        appleConfig.architecture
    }
    
    class var currentArchitecture: String {
        #if arch(arm64)
        "aarch64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        #error("Unsupported architecture.")
        #endif
    }
    
    override var detailsSystemMemoryLabel: String {
        return ByteCountFormatter.string(fromByteCount: Int64(appleConfig.memorySize), countStyle: .memory)
    }
    
    override var hasSaveState: Bool {
        false
    }
    
    private let vmQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)
    
    private(set) var apple: VZVirtualMachine!
    
    private var progressObserver: NSKeyValueObservation?
    
    @Published private(set) var serialPort: UTMSerialPort?
    
    private var sharedDirectoriesChanged: AnyCancellable?
    
    private var configChanged: AnyCancellable?
    
    weak var screenshotDelegate: UTMScreenshotProvider?
    
    override static func isAppleVM(forPath path: URL) -> Bool {
        do {
            _ = try UTMAppleConfiguration.load(from: path)
            return true
        } catch {
            return false
        }
    }
    
    override func loadConfiguration(withReload reload: Bool) throws {
        let newConfig = try UTMAppleConfiguration.load(from: path!)
        if let oldConfig = config as? UTMAppleConfiguration {
            // copy non-persistent values over
            newConfig.sharedDirectories = oldConfig.sharedDirectories
            if #available(macOS 12, *) {
                newConfig.macRecoveryIpswURL = oldConfig.macRecoveryIpswURL
            }
        }
        config = newConfig
    }
    
    override func saveUTM() async throws {
        let fileManager = FileManager.default
        let newPath = packageURL(forName: appleConfig.name)
        let savePath: URL
        if let existingPath = path {
            savePath = existingPath
        } else {
            savePath = newPath
        }
        do {
            try await appleConfig.save(to: savePath)
        } catch {
            if let reload = try? UTMAppleConfiguration.load(from: savePath) {
                config = reload
            }
            throw error
        }
        if let existingPath = path, existingPath.lastPathComponent != newPath.lastPathComponent {
            try fileManager.moveItem(at: existingPath, to: newPath)
            path = newPath
            if let reload = try? UTMAppleConfiguration.load(from: newPath) {
                config = reload
            }
        } else if path == nil {
            path = savePath
        }
    }
    
    override func accessShortcut() async throws {
        // FIXME: Apple VM doesn't support saving bookmarks
    }
    
    private func _vmStart() async throws {
        try createAppleVM()
        try await withCheckedThrowingContinuation { continuation in
            vmQueue.async {
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
            try await _vmStart()
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


        // This perform any cleanup for the "--snapshot" feature, 
        // if it was initialized previously
        try appleConfig.cleanupDriveSnapShot()

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
    
    override func vmPause() async throws {
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
        if appleConfig.isSerialEnabled {
            let (fd, sfd, name) = try createPty()
            let terminalTtyHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            let slaveTtyHandle = FileHandle(fileDescriptor: sfd, closeOnDealloc: false)
            let attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: terminalTtyHandle, fileHandleForWriting: terminalTtyHandle)
            let serialConfig = VZVirtioConsoleDeviceSerialPortConfiguration()
            serialConfig.attachment = attachment
            appleConfig.apple.serialPorts = [serialConfig]
            DispatchQueue.main.async {
                self.serialPort = UTMSerialPort(portNamed: name, readFileHandle: slaveTtyHandle, writeFileHandle: slaveTtyHandle, terminalFileHandle: terminalTtyHandle)
            }
        }
        if #available(macOS 12, *) {
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: "share")
            fsConfig.share = makeDirectoryShare(from: appleConfig.sharedDirectories)
            appleConfig.apple.directorySharingDevices = [fsConfig]
            sharedDirectoriesChanged = appleConfig.$sharedDirectories.sink { [weak self] newShares in
                guard let fsConfig = self?.apple?.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
                    return
                }
                fsConfig.share = self?.makeDirectoryShare(from: newShares)
            }
        }

        // This perform any reset's needed for the "--snapshot" feature (if its in use)
        try appleConfig.setupDriveSnapShot()

        apple = VZVirtualMachine(configuration: appleConfig.apple, queue: vmQueue)
        apple.delegate = self
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
    
    @available(macOS 12, *)
    private func makeDirectoryShare(from sharedDirectories: [SharedDirectory]) -> VZDirectoryShare {
        let vzSharedDirectories = sharedDirectories.compactMap { sharedDirectory in
            sharedDirectory.vzSharedDirectory()
        }
        let directories = vzSharedDirectories.reduce(into: [String: VZSharedDirectory]()) { (dict, share) in
            let lastPathComponent = share.url.lastPathComponent
            var name = lastPathComponent
            var i = 2
            while dict.keys.contains(name) {
                name = "\(lastPathComponent) (\(i))"
                i += 1
            }
            dict[name] = share
        }
        return VZMultipleDirectoryShare(directories: directories)
    }
}

@available(macOS 11, *)
extension UTMAppleVirtualMachine: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        apple = nil
        sharedDirectoriesChanged = nil
        serialPort?.close()
        DispatchQueue.main.async {
            self.serialPort = nil
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
