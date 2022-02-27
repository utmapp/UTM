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
        } else if self.path != nil {
            return self.path!.path // path if we're an existing VM
        } else if let uuid = (self.config as? UTMQemuConfiguration)?.systemUUID {
            return uuid
        } else {
            return UUID().uuidString
        }
    }
}

@available(iOS 13, macOS 11, *)
extension UTMVirtualMachine: ObservableObject {
    
}

@objc extension UTMVirtualMachine {
    fileprivate static let gibInMib = 1024
    func subscribeToConfiguration() -> [AnyObject] {
        var s: [AnyObject] = []
        if #available(iOS 13, macOS 11, *) {
            s.append(viewState.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            })
            if let config = config as? UTMQemuConfiguration {
                s.append(config.objectWillChange.sink { [weak self] in
                    self?.objectWillChange.send()
                })
            }
        }
        return s
    }
    
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

public extension UTMQemuVirtualMachine {
    override var detailsTitleLabel: String {
        qemuConfig.name
    }
    
    override var detailsSubtitleLabel: String {
        self.detailsSystemTargetLabel
    }
    
    override var detailsNotes: String? {
        qemuConfig.notes
    }
    
    override var detailsSystemTargetLabel: String {
        guard let arch = qemuConfig.systemArchitecture else {
            return ""
        }
        guard let target = qemuConfig.systemTarget else {
            return ""
        }
        guard let targets = UTMQemuConfiguration.supportedTargets(forArchitecture: arch) else {
            return ""
        }
        guard let prettyTargets = UTMQemuConfiguration.supportedTargets(forArchitecturePretty: arch) else {
            return ""
        }
        guard let index = targets.firstIndex(of: target) else {
            return ""
        }
        return prettyTargets[index]
    }
    
    override var detailsSystemArchitectureLabel: String {
        let archs = UTMQemuConfiguration.supportedArchitectures()
        let prettyArchs = UTMQemuConfiguration.supportedArchitecturesPretty()
        guard let arch = qemuConfig.systemArchitecture else {
            return ""
        }
        guard let index = archs.firstIndex(of: arch) else {
            return ""
        }
        return prettyArchs[index]
    }
    
    override var detailsSystemMemoryLabel: String {
        guard let memory = qemuConfig.systemMemory else {
            return NSLocalizedString("Unknown", comment: "UTMVirtualMachineExtension")
        }
        if memory.intValue > UTMVirtualMachine.gibInMib {
            return String(format: "%.1f GB", memory.floatValue / Float(UTMVirtualMachine.gibInMib))
        } else {
            return String(format: "%d MB", memory.intValue)
        }
    }
    
    /// Check if a QEMU target is supported
    /// - Parameter systemArchitecture: QEMU architecture
    /// - Returns: true if UTM is compiled with the supporting binaries
    @objc static func isSupported(systemArchitecture: String?) -> Bool {
        guard let arch = systemArchitecture else {
            return true // ignore this
        }
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
}

extension UTMDrive: Identifiable {
    public var id: Int {
        self.index
    }
}
