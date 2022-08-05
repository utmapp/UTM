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
final class UTMAppleConfiguration: UTMConfiguration {
    /// Basic information and icon
    @Published var information: UTMConfigurationInfo = .init()
    
    @Published var system: UTMAppleConfigurationSystem = .init()
    
    @Published var virtualization: UTMAppleConfigurationVirtualization = .init()
    
    @Published var sharedDirectories: [UTMAppleConfigurationSharedDirectory] = []
    
    @Published var displays: [UTMAppleConfigurationDisplay] = [.init()]
    
    @Published var drives: [UTMAppleConfigurationDrive] = []
    
    @Published var networks: [UTMAppleConfigurationNetwork] = [.init()]
    
    @Published var serials: [UTMAppleConfigurationSerial] = []
    
    var backend: UTMBackend {
        .apple
    }
    
    enum CodingKeys: String, CodingKey {
        case information = "Information"
        case system = "System"
        case virtualization = "Virtualization"
        case sharedDirectories = "SharedDirectory"
        case displays = "Display"
        case drives = "Drive"
        case networks = "Network"
        case serials = "Serial"
        case backend = "Backend"
        case configurationVersion = "ConfigurationVersion"
    }
    
    init() {
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let backend = try values.decodeIfPresent(UTMBackend.self, forKey: .backend) ?? .unknown
        guard backend == .apple else {
            throw UTMConfigurationError.invalidBackend
        }
        let version = try values.decodeIfPresent(Int.self, forKey: .configurationVersion) ?? 0
        guard version >= Self.oldestVersion else {
            throw UTMConfigurationError.versionTooLow
        }
        guard version <= Self.currentVersion else {
            throw UTMConfigurationError.versionTooHigh
        }
        information = try values.decode(UTMConfigurationInfo.self, forKey: .information)
        system = try values.decode(UTMAppleConfigurationSystem.self, forKey: .system)
        virtualization = try values.decode(UTMAppleConfigurationVirtualization.self, forKey: .virtualization)
        sharedDirectories = try values.decode([UTMAppleConfigurationSharedDirectory].self, forKey: .sharedDirectories)
        displays = try values.decode([UTMAppleConfigurationDisplay].self, forKey: .displays)
        drives = try values.decode([UTMAppleConfigurationDrive].self, forKey: .drives)
        networks = try values.decode([UTMAppleConfigurationNetwork].self, forKey: .networks)
        serials = try values.decode([UTMAppleConfigurationSerial].self, forKey: .serials)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(information, forKey: .information)
        try container.encode(system, forKey: .system)
        try container.encode(virtualization, forKey: .virtualization)
        try container.encode(sharedDirectories, forKey: .sharedDirectories)
        try container.encode(displays, forKey: .displays)
        try container.encode(drives, forKey: .drives)
        try container.encode(networks, forKey: .networks)
        try container.encode(serials, forKey: .serials)
        try container.encode(UTMBackend.apple, forKey: .backend)
        try container.encode(Self.currentVersion, forKey: .configurationVersion)
    }
}

enum UTMAppleConfigurationError: Error {
    case notAppleConfiguration
    case platformUnsupported
    case kernelNotSpecified
    case hardwareModelInvalid
    case rosettaNotSupported
}

extension UTMAppleConfigurationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAppleConfiguration:
            return NSLocalizedString("This is not a valid Apple Virtualization configuration.", comment: "UTMAppleConfiguration")
        case .platformUnsupported:
            return NSLocalizedString("This virtual machine cannot run on the current host machine.", comment: "UTMAppleConfiguration")
        case .kernelNotSpecified:
            return NSLocalizedString("A valid kernel image must be specified.", comment: "UTMAppleConfiguration")
        case .hardwareModelInvalid:
            return NSLocalizedString("This virtual machine contains an invalid hardware model. The configuration may be corrupted or is outdated.", comment: "UTMAppleConfiguration")
        case .rosettaNotSupported:
            return NSLocalizedString("Rosetta is not supported on the current host machine.", comment: "UTMAppleConfiguration")
        }
    }
}

// MARK: - Conversion of old config format

extension UTMAppleConfiguration {
    convenience init(migrating oldConfig: UTMLegacyAppleConfiguration, dataURL: URL) {
        self.init()
        information = .init(migrating: oldConfig, dataURL: dataURL)
        system = .init(migrating: oldConfig)
        virtualization = .init(migrating: oldConfig)
        sharedDirectories = oldConfig.sharedDirectories.map { .init(migrating: $0) }
        #if arch(arm64)
        if #available(macOS 12, *) {
            displays = oldConfig.displays.map { .init(migrating: $0) }
        }
        #endif
        drives = oldConfig.diskImages.map { .init(migrating: $0) }
        networks = oldConfig.networkDevices.map { .init(migrating: $0) }
        if oldConfig.isConsoleDisplay {
            var serial = UTMAppleConfigurationSerial()
            serial.terminal = .init(migrating: oldConfig)
            serials = [serial]
        } else if oldConfig.isSerialEnabled {
            var serial = UTMAppleConfigurationSerial()
            serial.mode = .ptty
            serials = [serial]
        }
    }
}

// MARK: - Creating Apple config

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfiguration {
    var appleVZConfiguration: VZVirtualMachineConfiguration {
        let vzconfig = VZVirtualMachineConfiguration()
        system.fillVZConfiguration(vzconfig)
        if #available(macOS 12, *) {
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: "share")
            fsConfig.share = UTMAppleConfigurationSharedDirectory.makeDirectoryShare(from: sharedDirectories)
            vzconfig.directorySharingDevices.append(fsConfig)
        }
        vzconfig.storageDevices = drives.compactMap { drive in
            guard let attachment = try? drive.vzDiskImage() else {
                return nil
            }
            if #available(macOS 13, *), drive.isExternal {
                return VZUSBMassStorageDeviceConfiguration(attachment: attachment)
            } else {
                return VZVirtioBlockDeviceConfiguration(attachment: attachment)
            }
        }
        vzconfig.networkDevices.append(contentsOf: networks.compactMap({ $0.vzNetworking() }))
        vzconfig.serialPorts.append(contentsOf: serials.compactMap({ $0.vzSerial() }))
        // add remaining devices
        virtualization.fillVZConfiguration(vzconfig)
        #if arch(arm64)
        if #available(macOS 12, *) {
            if system.boot.operatingSystem == .macOS {
                let graphics = VZMacGraphicsDeviceConfiguration()
                graphics.displays = displays.map({ display in
                    display.vzMacDisplay()
                })
                vzconfig.graphicsDevices = [graphics]
            }
        }
        #endif
        if #available(macOS 13, *) {
            if system.boot.operatingSystem != .macOS {
                let graphics = VZVirtioGraphicsDeviceConfiguration()
                graphics.scanouts = displays.map({ display in
                    display.vzVirtioDisplay()
                })
                vzconfig.graphicsDevices = [graphics]
            }
        }
        return vzconfig
    }
}

// MARK: - Saving data

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfiguration {
    func prepareSave(for packageURL: URL) async throws {
        try await virtualization.prepareSave(for: packageURL)
    }
    
    func saveData(to dataURL: URL) async throws -> [URL] {
        var existingDataURLs = [URL]()
        existingDataURLs += try await information.saveData(to: dataURL)
        existingDataURLs += try await system.boot.saveData(to: dataURL)
        
        #if arch(arm64)
        if #available(macOS 12, *), system.macPlatform != nil {
            existingDataURLs += try await system.macPlatform!.saveData(to: dataURL)
        }
        #endif

        // validate before we copy and create drive images
        try appleVZConfiguration.validate()

        for i in 0..<drives.count {
            existingDataURLs += try await drives[i].saveData(to: dataURL)
        }
        
        return existingDataURLs
    }
}
