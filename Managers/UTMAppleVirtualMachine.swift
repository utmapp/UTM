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

import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
@objc class UTMAppleVirtualMachine: UTMVirtualMachine {
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
    
    lazy private(set) var apple: VZVirtualMachine = {
        let vm = VZVirtualMachine(configuration: self.appleConfig.apple, queue: vmQueue)
        vm.delegate = self
        return vm
    }()
    
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
        changeState(.vmStopping)
        if force {
            vmQueue.async {
                self.apple.stop { error in
                    if let error = error {
                        self.errorTriggered(error.localizedDescription)
                    } else {
                        self.changeState(.vmStopped)
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
    
    func installVM(with ipswUrl: URL) -> Bool {
        guard state == .vmStopped else {
            return false
        }
        changeState(.vmStarting)
        #if os(macOS) && arch(arm64)
        vmQueue.async {
            let installer = VZMacOSInstaller(virtualMachine: self.apple, restoringFromImageAt: ipswUrl)
            installer.install { result in
                switch result {
                case .failure(let error):
                    self.errorTriggered(error.localizedDescription)
                case .success:
                    self.changeState(.vmStopped)
                    _ = self.startVM()
                }
            }
        }
        return true
        #else
        changeState(.vmStopped)
        return false
        #endif
    }
}

@available(macOS 12, *)
extension UTMAppleVirtualMachine: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        changeState(.vmStopped)
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        errorTriggered(error.localizedDescription)
    }
}
