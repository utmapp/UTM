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
@available(macOS 12, *)
@objc class UTMAppleVirtualMachine: UTMVirtualMachine {
    private let quitTimeoutSeconds = DispatchTimeInterval.seconds(30)
    
    var appleConfig: UTMAppleConfiguration! {
        config as? UTMAppleConfiguration
    }
    
    override var title: String {
        appleConfig.name
    }
    
    override var subtitle: String {
        systemTarget
    }
    
    override var icon: URL? {
        if appleConfig.iconCustom {
            return appleConfig.existingCustomIconURL
        } else {
            return appleConfig.existingIconURL
        }
    }
    
    override var notes: String? {
        appleConfig.notes
    }
    
    override var systemTarget: String {
        appleConfig.bootLoader?.operatingSystem.rawValue ?? ""
    }
    
    override var systemArchitecture: String {
        #if arch(arm64)
        "aarch64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "Unknown"
        #endif
    }
    
    override var systemMemory: String {
        return ByteCountFormatter.string(fromByteCount: Int64(appleConfig.memorySize), countStyle: .memory)
    }
    
    private let vmQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)
    
    private(set) var apple: VZVirtualMachine!
    
    private var progressObserver: NSKeyValueObservation?
    
    @Published private(set) var serialPort: UTMSerialPort?
    
    private var sharedDirectoriesChanged: AnyCancellable?
    
    override static func isAppleVM(forPath path: URL) -> Bool {
        do {
            _ = try UTMAppleConfiguration.load(from: path)
            return true
        } catch {
            return false
        }
    }
    
    override func loadConfiguration(withReload reload: Bool) throws {
        config = try UTMAppleConfiguration.load(from: path!)
    }
    
    override func saveUTM() throws {
        let fileManager = FileManager.default
        let newPath = packageURL(forName: appleConfig.name)
        let savePath: URL
        if let existingPath = path {
            savePath = existingPath
        } else {
            savePath = newPath
        }
        do {
            try appleConfig.save(to: savePath)
        } catch {
            if let reload = try? UTMAppleConfiguration.load(from: savePath) {
                config = reload
            }
            throw error
        }
        if let existingPath = path, existingPath.lastPathComponent != newPath.lastPathComponent {
            try fileManager.moveItem(at: existingPath, to: newPath)
            path = newPath
        } else {
            path = savePath
        }
    }
    
    override func startVM() -> Bool {
        guard state == .vmStopped || state == .vmSuspended else {
            return false
        }
        changeState(.vmStarting)
        guard createAppleVM() else {
            return false
        }
        vmQueue.async {
            self.apple.start { result in
                switch result {
                case .failure(let error):
                    self.errorTriggered(error.localizedDescription)
                case .success:
                    self.changeState(.vmStarted)
                }
            }
        }
        return true
    }
    
    override func quitVM(force: Bool) -> Bool {
        guard state == .vmStarted else {
            return false
        }
        if force {
            changeState(.vmStopping)
            vmQueue.async {
                self.apple.stop { error in
                    if let error = error {
                        self.errorTriggered(error.localizedDescription)
                    } else {
                        self.guestDidStop(self.apple)
                    }
                }
            }
        } else {
            vmQueue.async {
                do {
                    try self.apple.requestStop()
                } catch {
                    self.errorTriggered(error.localizedDescription)
                }
            }
        }
        return true
    }
    
    override func resetVM() -> Bool {
        // FIXME: implement this
        return false
    }
    
    override func pauseVM() -> Bool {
        guard state == .vmStarted else {
            return false
        }
        changeState(.vmPausing)
        vmQueue.async {
            self.apple.pause { result in
                switch result {
                case .failure(let error):
                    self.errorTriggered(error.localizedDescription)
                case .success:
                    self.changeState(.vmPaused)
                }
            }
        }
        return true
    }
    
    override func saveVM() -> Bool {
        // FIXME: implement this
        return false
    }
    
    override func deleteSaveVM() -> Bool {
        // FIXME: implement this
        return false
    }
    
    override func resumeVM() -> Bool {
        guard state == .vmPaused else {
            return false
        }
        vmQueue.async {
            self.apple.resume { result in
                switch result {
                case .failure(let error):
                    self.errorTriggered(error.localizedDescription)
                case .success:
                    self.changeState(.vmStarted)
                }
            }
        }
        return true
    }
    
    private func createAppleVM() -> Bool {
        if appleConfig.isSerialEnabled {
            do {
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
            } catch {
                errorTriggered(error.localizedDescription)
                return false
            }
        }
        let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: "share")
        fsConfig.share = makeDirectoryShare(from: appleConfig.sharedDirectories)
        appleConfig.apple.directorySharingDevices = [fsConfig]
        apple = VZVirtualMachine(configuration: appleConfig.apple, queue: vmQueue)
        apple.delegate = self
        sharedDirectoriesChanged = appleConfig.$sharedDirectories.sink { [weak self] newShares in
            guard let fsConfig = self?.apple?.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
                return
            }
            fsConfig.share = self?.makeDirectoryShare(from: newShares)
        }
        return true
    }
    
    func installVM(with ipswUrl: URL) -> Bool {
        guard state == .vmStopped else {
            return false
        }
        changeState(.vmStarting)
        guard createAppleVM() else {
            return false
        }
        #if os(macOS) && arch(arm64)
        vmQueue.async {
            let installer = VZMacOSInstaller(virtualMachine: self.apple, restoringFromImageAt: ipswUrl)
            self.progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
                self.delegate?.virtualMachine?(self, installationProgress: progress.fractionCompleted)
            }
            installer.install { result in
                switch result {
                case .failure(let error):
                    self.errorTriggered(error.localizedDescription)
                case .success:
                    self.changeState(.vmStarted)
                }
                self.progressObserver = nil
            }
        }
        return true
        #else
        changeState(.vmStopped)
        return false
        #endif
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

@available(macOS 12, *)
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
        errorTriggered(error.localizedDescription)
    }
}
