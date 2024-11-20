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
    @Published var _information: UTMConfigurationInfo = .init()
    
    @Published private var _system: UTMAppleConfigurationSystem = .init()
    
    @Published private var _virtualization: UTMAppleConfigurationVirtualization = .init()
    
    @Published private var _sharedDirectories: [UTMAppleConfigurationSharedDirectory] = []
    
    @Published private var _displays: [UTMAppleConfigurationDisplay] = []
    
    @Published private var _drives: [UTMAppleConfigurationDrive] = []
    
    @Published private var _networks: [UTMAppleConfigurationNetwork] = [.init()]
    
    @Published private var _serials: [UTMAppleConfigurationSerial] = []

    /// Set to true to request guest tools install. Not saved.
    @Published var isGuestToolsInstallRequested: Bool = false

    var backend: UTMBackend {
        .apple
    }
    
    enum CodingKeys: String, CodingKey {
        case information = "Information"
        case system = "System"
        case virtualization = "Virtualization"
        case sharedDirectories = "SharedDirectory" // legacy
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
        _information = try values.decode(UTMConfigurationInfo.self, forKey: .information)
        _system = try values.decode(UTMAppleConfigurationSystem.self, forKey: .system)
        _virtualization = try values.decode(UTMAppleConfigurationVirtualization.self, forKey: .virtualization)
        _sharedDirectories = try values.decodeIfPresent([UTMAppleConfigurationSharedDirectory].self, forKey: .sharedDirectories) ?? []
        _displays = try values.decode([UTMAppleConfigurationDisplay].self, forKey: .displays)
        _drives = try values.decode([UTMAppleConfigurationDrive].self, forKey: .drives)
        _networks = try values.decode([UTMAppleConfigurationNetwork].self, forKey: .networks)
        _serials = try values.decode([UTMAppleConfigurationSerial].self, forKey: .serials)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_information, forKey: .information)
        try container.encode(_system, forKey: .system)
        try container.encode(_virtualization, forKey: .virtualization)
        try container.encode(_displays, forKey: .displays)
        try container.encode(_drives, forKey: .drives)
        try container.encode(_networks, forKey: .networks)
        try container.encode(_serials, forKey: .serials)
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
    case featureNotSupported
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
        case .featureNotSupported:
            return NSLocalizedString("The host operating system needs to be updated to support one or more features requested by the guest.", comment: "UTMAppleConfiguration")
        }
    }
}

// MARK: - Public accessors

@MainActor extension UTMAppleConfiguration {
    var information: UTMConfigurationInfo {
        get {
            _information
        }
        
        set {
            _information = newValue
        }
    }
    
    var system: UTMAppleConfigurationSystem {
        get {
            _system
        }
        
        set {
            _system = newValue
        }
    }
    
    var virtualization: UTMAppleConfigurationVirtualization {
        get {
            _virtualization
        }
        
        set {
            _virtualization = newValue
        }
    }
    
    var sharedDirectories: [UTMAppleConfigurationSharedDirectory] {
        get {
            _sharedDirectories
        }
        
        set {
            _sharedDirectories = newValue
        }
    }
    
    var sharedDirectoriesPublisher: Published<[UTMAppleConfigurationSharedDirectory]>.Publisher {
        get {
            $_sharedDirectories
        }
    }
    
    var displays: [UTMAppleConfigurationDisplay] {
        get {
            _displays
        }
        
        set {
            _displays = newValue
        }
    }
    
    var drives: [UTMAppleConfigurationDrive] {
        get {
            _drives
        }
        
        set {
            _drives = newValue
        }
    }
    
    var networks: [UTMAppleConfigurationNetwork] {
        get {
            _networks
        }
        
        set {
            _networks = newValue
        }
    }
    
    var serials: [UTMAppleConfigurationSerial] {
        get {
            _serials
        }
        
        set {
            _serials = newValue
        }
    }
}

// MARK: - Conversion of old config format

extension UTMAppleConfiguration {
    convenience init(migrating oldConfig: UTMLegacyAppleConfiguration, dataURL: URL) {
        self.init()
        _information = .init(migrating: oldConfig, dataURL: dataURL)
        _system = .init(migrating: oldConfig)
        _virtualization = .init(migrating: oldConfig)
        if #available(macOS 12, *) {
            _sharedDirectories = oldConfig.sharedDirectories.map { .init(migrating: $0) }
        }
        #if arch(arm64)
        if #available(macOS 12, *) {
            _displays = oldConfig.displays.map { .init(migrating: $0) }
        }
        #endif
        _drives = oldConfig.diskImages.map { .init(migrating: $0) }
        _networks = oldConfig.networkDevices.map { .init(migrating: $0) }
        if oldConfig.isConsoleDisplay {
            var serial = UTMAppleConfigurationSerial()
            serial.terminal = .init(migrating: oldConfig)
            _serials = [serial]
        } else if oldConfig.isSerialEnabled {
            var serial = UTMAppleConfigurationSerial()
            serial.mode = .ptty
            _serials = [serial]
        }
    }
}

// MARK: - Creating Apple config

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
@MainActor extension UTMAppleConfiguration {
    func appleVZConfiguration(ignoringDrives: Bool = false) throws -> VZVirtualMachineConfiguration {
        let vzconfig = VZVirtualMachineConfiguration()
        try system.fillVZConfiguration(vzconfig)
        if #available(macOS 12, *), !sharedDirectories.isEmpty {
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: shareDirectoryTag)
            fsConfig.share = UTMAppleConfigurationSharedDirectory.makeDirectoryShare(from: sharedDirectories)
            vzconfig.directorySharingDevices.append(fsConfig)
        } else if !sharedDirectories.isEmpty {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        if !ignoringDrives {
            vzconfig.storageDevices = try drives.compactMap { drive in
                guard let attachment = try drive.vzDiskImage(useFsWorkAround: system.boot.operatingSystem == .linux) else {
                    return nil
                }
                if #available(macOS 13, *), drive.isExternal {
                    if #available(macOS 15, *) {
                        return nil // we will handle removable drives in `UTMAppleVirtualMachine`
                    } else {
                        return VZUSBMassStorageDeviceConfiguration(attachment: attachment)
                    }
                } else if #available(macOS 14, *), drive.isNvme, system.boot.operatingSystem == .linux {
                    return VZNVMExpressControllerDeviceConfiguration(attachment: attachment)
                } else {
                    return VZVirtioBlockDeviceConfiguration(attachment: attachment)
                }
            }
        }
        vzconfig.networkDevices.append(contentsOf: networks.compactMap({ $0.vzNetworking() }))
        vzconfig.serialPorts.append(contentsOf: serials.compactMap({ $0.vzSerial() }))
        // add remaining devices
        try virtualization.fillVZConfiguration(vzconfig, isMacOSGuest: system.boot.operatingSystem == .macOS)
        #if arch(arm64)
        if #available(macOS 12, *), system.boot.operatingSystem == .macOS {
            let graphics = VZMacGraphicsDeviceConfiguration()
            graphics.displays = displays.map({ display in
                display.vzMacDisplay()
            })
            if graphics.displays.count > 0 {
                vzconfig.graphicsDevices = [graphics]
            }
        }
        #endif
        if #available(macOS 13, *), system.boot.operatingSystem != .macOS {
            let graphics = VZVirtioGraphicsDeviceConfiguration()
            graphics.scanouts = displays.map({ display in
                display.vzVirtioDisplay()
            })
            if graphics.scanouts.count > 0 {
                vzconfig.graphicsDevices = [graphics]
            }
        } else if system.boot.operatingSystem != .macOS && !displays.isEmpty {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        if #available(macOS 15, *) {
            vzconfig.usbControllers = [VZXHCIControllerConfiguration()]
        }
        return vzconfig
    }

    var shareDirectoryTag: String {
        if #available(macOS 13, *), system.boot.operatingSystem == .macOS {
            return VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
        } else {
            return "share"
        }
    }
}

// MARK: - Saving data

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
@MainActor extension UTMAppleConfiguration {
    func prepareSave(for packageURL: URL) async throws {
        try await virtualization.prepareSave(for: packageURL)
    }
    
    func saveData(to dataURL: URL) async throws -> [URL] {
        var existingDataURLs = [URL]()
        existingDataURLs += try await _information.saveData(to: dataURL)
        existingDataURLs += try await _system.boot.saveData(to: dataURL)
        
        #if arch(arm64)
        if #available(macOS 12, *), system.macPlatform != nil {
            existingDataURLs += try await _system.macPlatform!.saveData(to: dataURL)
        }
        #endif

        // validate before we copy and create drive images
        try appleVZConfiguration(ignoringDrives: true).validate()

        for i in 0..<drives.count {
            existingDataURLs += try await _drives[i].saveData(to: dataURL)
        }
        
        return existingDataURLs
    }
}
