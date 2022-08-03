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
import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
struct UTMAppleConfigurationMacPlatform: Codable {
    var hardwareModel: Data
    var machineIdentifier: Data
    var auxiliaryStorageURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case hardwareModel = "HardwareModel"
        case machineIdentifier = "MachineIdentifier"
        case auxiliaryStoragePath = "AuxiliaryStoragePath"
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hardwareModel = try container.decode(Data.self, forKey: .hardwareModel)
        machineIdentifier = try container.decode(Data.self, forKey: .machineIdentifier)
        if let auxiliaryStoragePath = try container.decodeIfPresent(String.self, forKey: .auxiliaryStoragePath) {
            auxiliaryStorageURL = dataURL.appendingPathComponent(auxiliaryStoragePath)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardwareModel, forKey: .hardwareModel)
        try container.encode(machineIdentifier, forKey: .machineIdentifier)
        try container.encodeIfPresent(auxiliaryStorageURL?.lastPathComponent, forKey: .auxiliaryStoragePath)
    }
    
    #if arch(arm64)
    @available(macOS 12, *)
    init(newHardware: VZMacHardwareModel) {
        hardwareModel = newHardware.dataRepresentation
        machineIdentifier = VZMacMachineIdentifier().dataRepresentation
    }
    
    @available(macOS 12, *)
    init(from config: VZMacPlatformConfiguration) {
        hardwareModel = config.hardwareModel.dataRepresentation
        machineIdentifier = config.machineIdentifier.dataRepresentation
        auxiliaryStorageURL = config.auxiliaryStorage?.url
    }
    
    @available(macOS 12, *)
    func vzMacPlatform() -> VZMacPlatformConfiguration? {
        guard let vzHardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModel) else {
            return nil
        }
        guard let vzMachineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifier) else {
            return nil
        }
        var vzAuxiliaryStorage: VZMacAuxiliaryStorage?
        if let auxiliaryStorageURL = auxiliaryStorageURL {
            vzAuxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL)
        }
        let config = VZMacPlatformConfiguration()
        config.hardwareModel = vzHardwareModel
        config.machineIdentifier = vzMachineIdentifier
        config.auxiliaryStorage = vzAuxiliaryStorage
        return config
    }
    #endif
}

// MARK: - Conversion of old config format

#if arch(arm64)
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
extension UTMAppleConfigurationMacPlatform {
    init(migrating oldBoot: MacPlatform) {
        hardwareModel = oldBoot.hardwareModel
        machineIdentifier = oldBoot.machineIdentifier
        auxiliaryStorageURL = oldBoot.auxiliaryStorageURL
    }
}
#endif

// MARK: - Saving data

#if arch(arm64)
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
extension UTMAppleConfigurationMacPlatform {
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        let auxStorageURL = dataURL.appendingPathComponent("AuxiliaryStorage")
        if !fileManager.fileExists(atPath: auxStorageURL.path) {
            guard let hwModel = VZMacHardwareModel(dataRepresentation: hardwareModel) else {
                throw UTMAppleConfigurationError.hardwareModelInvalid
            }
            _ = try VZMacAuxiliaryStorage(creatingStorageAt: auxStorageURL, hardwareModel: hwModel, options: [])
        }
        auxiliaryStorageURL = auxStorageURL
        return [auxStorageURL]
    }
}
#endif
