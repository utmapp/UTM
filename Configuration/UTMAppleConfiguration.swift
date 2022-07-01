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
final class UTMAppleConfiguration: Codable, ObservableObject {
    private let oldestVersion = 3
    private let currentVersion = 3
    
    /// Basic information and icon
    @Published var information: UTMConfigurationInfo = .init()
    
    @Published var system: UTMAppleConfigurationSystem = .init()
    
    @Published var devices: UTMAppleConfigurationDevices = .init()
    
    @Published var sharedDirectories: [UTMAppleConfigurationSharedDirectory] = []
    
    @Published var displays: [UTMAppleConfigurationDisplay] = [.init()]
    
    @Published var drives: [UTMAppleConfigurationDrive] = []
    
    @Published var networks: [UTMAppleConfigurationNetwork] = [.init()]
    
    @Published var serials: [UTMAppleConfigurationSerial] = []
    
    /// If set, points to the data directory for this configuration. Not saved.
    var dataURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case information = "Information"
        case system = "System"
        case devices = "Devices"
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
        let backend = try values.decodeIfPresent(UTMBackend.self, forKey: .backend) ?? .apple
        guard backend == .apple else {
            throw QEMUConfigError.invalidBackend
        }
        let version = try values.decodeIfPresent(Int.self, forKey: .configurationVersion) ?? 0
        guard version >= oldestVersion else {
            throw QEMUConfigError.versionTooLow
        }
        guard version <= currentVersion else {
            throw QEMUConfigError.versionTooHigh
        }
        information = try values.decode(UTMConfigurationInfo.self, forKey: .information)
        system = try values.decode(UTMAppleConfigurationSystem.self, forKey: .system)
        devices = try values.decode(UTMAppleConfigurationDevices.self, forKey: .devices)
        sharedDirectories = try values.decode([UTMAppleConfigurationSharedDirectory].self, forKey: .sharedDirectories)
        displays = try values.decode([UTMAppleConfigurationDisplay].self, forKey: .displays)
        drives = try values.decode([UTMAppleConfigurationDrive].self, forKey: .drives)
        networks = try values.decode([UTMAppleConfigurationNetwork].self, forKey: .networks)
        serials = try values.decode([UTMAppleConfigurationSerial].self, forKey: .serials)
        dataURL = decoder.userInfo[.dataURL] as? URL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(information, forKey: .information)
        try container.encode(system, forKey: .system)
        try container.encode(sharedDirectories, forKey: .sharedDirectories)
        try container.encode(displays, forKey: .displays)
        try container.encode(drives, forKey: .drives)
        try container.encode(networks, forKey: .networks)
        try container.encode(serials, forKey: .serials)
        try container.encode(UTMBackend.apple, forKey: .backend)
        try container.encode(currentVersion, forKey: .configurationVersion)
    }
}

enum UTMAppleConfigurationError: Error {
    case versionTooHigh
    case platformUnsupported
    case notAppleConfiguration
    case invalidDataURL
    case kernelNotSpecified
    case customIconInvalid
    case hardwareModelInvalid
    case cannotCreateDiskImage
    case invalidDriveConfiguration
}

// MARK: - Conversion of old config format

@available(iOS 13, macOS 11, *)
extension UTMAppleConfiguration {
    convenience init(migrating oldConfig: UTMLegacyAppleConfiguration, dataURL: URL) {
        self.init()
        self.dataURL = dataURL
        information = .init(migrating: oldConfig, dataURL: dataURL)
        system = .init(migrating: oldConfig)
        devices = .init(migrating: oldConfig)
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
        devices.fillVZConfiguration(vzconfig)
        if #available(macOS 12, *) {
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: "share")
            fsConfig.share = UTMAppleConfigurationSharedDirectory.makeDirectoryShare(from: sharedDirectories)
            vzconfig.directorySharingDevices = [fsConfig]
        }
        vzconfig.storageDevices = drives.compactMap { drive in
            guard let attachment = try? drive.vzDiskImage() else {
                return nil
            }
            return VZVirtioBlockDeviceConfiguration(attachment: attachment)
        }
        vzconfig.networkDevices = networks.compactMap({ $0.vzNetworking() })
        vzconfig.serialPorts = serials.compactMap({ $0.vzSerial() })
        #if arch(arm64)
        if #available(macOS 12, *) {
            if system.boot.operatingSystem == .macOS {
                let graphics = VZMacGraphicsDeviceConfiguration()
                graphics.displays = displays.map({ display in
                    display.vzDisplay()
                })
                vzconfig.graphicsDevices = [graphics]
            }
        }
        #endif
        return vzconfig
    }
}
