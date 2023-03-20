//
// Copyright © 2023 osy. All rights reserved.
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

@MainActor
@objc(UTMScriptingCreateCommand)
class UTMScriptingCreateCommand: NSCreateCommand, UTMScriptable {
    private var bytesInMib: Int {
        1048576
    }
    
    private var bytesInGib: Int {
        1073741824
    }
    
    private var data: UTMData? {
        (NSApp.scriptingDelegate as? AppDelegate)?.data
    }
    
    @objc override func performDefaultImplementation() -> Any? {
        if createClassDescription.implementationClassName == "UTMScriptingVirtualMachineImpl" {
            withScriptCommand(self) { [self] in
                guard let backend = resolvedKeyDictionary["backend"] as? AEKeyword, let backend = UTMScriptingBackend(rawValue: backend) else {
                    throw ScriptingError.backendNotFound
                }
                guard let configuration = resolvedKeyDictionary["configuration"] as? [AnyHashable : Any] else {
                    throw ScriptingError.configurationNotFound
                }
                if backend == .qemu {
                    return try await createQemuVirtualMachine(from: configuration).objectSpecifier
                } else if backend == .apple {
                    return try await createAppleVirtualMachine(from: configuration).objectSpecifier
                } else {
                    throw ScriptingError.backendNotFound
                }
            }
            return nil
        } else {
            return super.performDefaultImplementation()
        }
    }
    
    private func createQemuVirtualMachine(from record: [AnyHashable : Any]) async throws -> UTMScriptingVirtualMachineImpl {
        guard let data = data else {
            throw ScriptingError.notReady
        }
        guard record["name"] as? String != nil else {
            throw ScriptingError.nameNotSpecified
        }
        guard let architecture = record["architecture"] as? String, let architecture = QEMUArchitecture(rawValue: architecture) else {
            throw ScriptingError.architectureNotSpecified
        }
        let machine = record["machine"] as? String
        let target = architecture.targetType.init(rawValue: machine ?? "") ?? architecture.targetType.default
        let config = UTMQemuConfiguration()
        config.system.architecture = architecture
        config.system.target = target
        config.reset(forArchitecture: architecture, target: target)
        config.qemu.hasHypervisor = true
        config.qemu.hasUefiBoot = true
        // add default drives
        config.drives.append(UTMQemuConfigurationDrive(forArchitecture: architecture, target: target, isExternal: true))
        var fixed = UTMQemuConfigurationDrive(forArchitecture: architecture, target: target)
        fixed.sizeMib = 64 * bytesInGib / bytesInMib
        config.drives.append(fixed)
        // add a default serial device
        var serial = UTMQemuConfigurationSerial()
        serial.mode = .ptty
        config.serials = [serial]
        // remove GUI devices
        config.displays = []
        config.sound = []
        // parse the remaining config
        let wrapper = UTMScriptingConfigImpl(config)
        try wrapper.updateConfiguration(from: record)
        // create the vm
        let vm = try await data.create(config: config)
        return UTMScriptingVirtualMachineImpl(for: vm, data: data)
    }
    
    private func createAppleVirtualMachine(from record: [AnyHashable : Any]) async throws -> UTMScriptingVirtualMachineImpl {
        guard let data = data else {
            throw ScriptingError.notReady
        }
        guard #available(macOS 13, *) else {
            throw ScriptingError.backendNotSupported
        }
        guard record["name"] as? String != nil else {
            throw ScriptingError.nameNotSpecified
        }
        let config = UTMAppleConfiguration()
        config.system.boot = try UTMAppleConfigurationBoot(for: .linux)
        config.virtualization.hasBalloon = true
        config.virtualization.hasEntropy = true
        config.networks = [UTMAppleConfigurationNetwork()]
        // remove any display devices
        config.displays = []
        // add a default serial device
        var serial = UTMAppleConfigurationSerial()
        serial.mode = .ptty
        config.serials = [serial]
        // add default drives
        config.drives.append(UTMAppleConfigurationDrive(existingURL: nil, isExternal: true))
        config.drives.append(UTMAppleConfigurationDrive(newSize: 64 * bytesInGib / bytesInMib))
        // parse the remaining config
        let wrapper = UTMScriptingConfigImpl(config)
        try wrapper.updateConfiguration(from: record)
        // create the vm
        let vm = try await data.create(config: config)
        return UTMScriptingVirtualMachineImpl(for: vm, data: data)
    }
    
    enum ScriptingError: Error, LocalizedError {
        case notReady
        case backendNotFound
        case backendNotSupported
        case configurationNotFound
        case nameNotSpecified
        case architectureNotSpecified
        
        var errorDescription: String? {
            switch self {
            case .notReady: return NSLocalizedString("UTM is not ready to accept commands.", comment: "UTMScriptingAppDelegate")
            case .backendNotFound: return NSLocalizedString("A valid backend must be specified.", comment: "UTMScriptingAppDelegate")
            case .backendNotSupported: return NSLocalizedString("This backend is not supported on your machine.", comment: "UTMScriptingAppDelegate")
            case .configurationNotFound: return NSLocalizedString("A valid configuration must be specified.", comment: "UTMScriptingAppDelegate")
            case .nameNotSpecified: return NSLocalizedString("No name specified in the configuration.", comment: "UTMScriptingAppDelegate")
            case .architectureNotSpecified: return NSLocalizedString("No architecture specified in the configuration.", comment: "UTMScriptingAppDelegate")
            }
        }
    }
}
