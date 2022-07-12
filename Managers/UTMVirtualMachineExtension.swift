//
// Copyright © 2020 osy. All rights reserved.
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

extension UTMVirtualMachine: Identifiable {
    public var id: String {
        if self.bookmark != nil {
            return bookmark!.base64EncodedString()
        } else {
            return self.path.path // path if we're an existing VM
        }
    }
}

extension UTMVirtualMachine: ObservableObject {
    
}

@objc extension UTMViewState: ObservableObject {
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

@objc extension UTMVirtualMachine {
    fileprivate static let gibInMib = 1024
    func subscribeToConfiguration() -> [AnyObject] {
        var s: [AnyObject] = []
        s.append(viewState.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        })
        if let config = config.qemuConfig {
            s.append(config.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            })
        } else if let config = config.appleConfig {
            s.append(config.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            })
        }
        return s
    }
    
    func propertyWillChange() -> Void {
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    @nonobjc convenience init<Config: UTMConfiguration>(newConfig: Config, destinationURL: URL) {
        let packageURL = UTMVirtualMachine.virtualMachinePath(newConfig.information.name, inParentURL: destinationURL)
        let configuration = UTMConfigurationWrapper(wrapping: newConfig)
        self.init(configuration: configuration, packageURL: packageURL)
    }
}

@objc extension UTMVirtualMachine {
    func reloadConfiguration() throws {
        try config.reload(from: path)
    }
    
    func saveUTM() async throws {
        let fileManager = FileManager.default
        let existingPath = path
        let newPath = existingPath.deletingLastPathComponent().appendingPathComponent(config.name).appendingPathExtension("utm")
        do {
            try await config.save(to: existingPath)
            try updateViewStatePostSave()
        } catch {
            try? reloadConfiguration()
            throw error
        }
        if existingPath != newPath {
            try await Task.detached {
                try fileManager.moveItem(at: existingPath, to: newPath)
            }.value
            path = newPath
            try reloadConfiguration()
        }
    }
    
    func updateViewStatePostSave() throws {
        // do nothing by default
    }
}

public extension UTMQemuVirtualMachine {
    override var detailsTitleLabel: String {
        config.qemuConfig!.information.name
    }
    
    override var detailsSubtitleLabel: String {
        self.detailsSystemTargetLabel
    }
    
    override var detailsNotes: String? {
        config.qemuConfig!.information.notes
    }
    
    override var detailsSystemTargetLabel: String {
        config.qemuConfig!.system.target.prettyValue
    }
    
    override var detailsSystemArchitectureLabel: String {
        config.qemuConfig!.system.architecture.prettyValue
    }
    
    override var detailsSystemMemoryLabel: String {
        let bytesInMib = Int64(1048576)
        return ByteCountFormatter.string(fromByteCount: Int64(config.qemuConfig!.system.memorySize) * bytesInMib, countStyle: .memory)
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
        logger.error("\(framework.path)")
        return FileManager.default.fileExists(atPath: framework.path)
    }
    
    /// Check if the current VM target is supported by the host
    @objc var isSupported: Bool {
        return UTMQemuVirtualMachine.isSupported(systemArchitecture: config.qemuConfig!.system.architecture)
    }
    
    @objc var drives: [UTMDrive] {
        let qemuDrives = config.qemuConfig!.drives
        var drives: [UTMDrive] = []
        for i in 0..<qemuDrives.count {
            let qemuDrive = qemuDrives[i]
            let drive = UTMDrive()
            drive.index = i
            switch qemuDrive.imageType {
            case .disk: drive.imageType = .disk
            case .cd: drive.imageType = .CD
            default: drive.imageType = .none // skip other types
            }
            drive.interface = qemuDrive.interface.rawValue
            drive.name = qemuDrive.id
            if qemuDrive.isExternal {
                // removable drive -> path stored only in viewState
                if let path = viewState.path(forRemovableDrive: qemuDrive.id) {
                    drive.status = .inserted
                    drive.path = path
                } else {
                    drive.status = .ejected
                    drive.path = nil
                }
            } else {
                // fixed drive -> path stored in configuration
                drive.status = .fixed
                drive.path = qemuDrive.imageURL?.lastPathComponent
            }
            drives.append(drive)
        }
        return drives
    }
    
    override func updateViewStatePostSave() throws {
        //FIXME: remove this once we remove viewState
        for drive in config.qemuConfig!.drives {
            if drive.isExternal, let url = drive.imageURL {
                let legacyDrive = drives.first(where: { $0.name == drive.id })
                try changeMedium(for: legacyDrive!, url: url)
            }
        }
    }
}

extension UTMDrive: Identifiable {
    public var id: Int {
        self.index
    }
}
