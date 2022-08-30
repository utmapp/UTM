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

/// Settings for a QEMU configuration
final class UTMQemuConfiguration: UTMConfiguration {
    /// Basic information and icon
    @Published var _information: UTMConfigurationInfo = .init()
    
    /// System settings
    @Published var _system: UTMQemuConfigurationSystem = .init()
    
    /// Additional QEMU tweaks
    @Published var _qemu: UTMQemuConfigurationQEMU = .init()
    
    /// Input settings
    @Published var _input: UTMQemuConfigurationInput = .init()
    
    /// Sharing settings
    @Published var _sharing: UTMQemuConfigurationSharing = .init()
    
    /// All displays
    @Published var _displays: [UTMQemuConfigurationDisplay] = []
    
    /// All drives
    @Published var _drives: [UTMQemuConfigurationDrive] = []
    
    /// All network adapters
    @Published var _networks: [UTMQemuConfigurationNetwork] = []
    
    /// All serial ouputs
    @Published var _serials: [UTMQemuConfigurationSerial] = []
    
    /// All audio devices
    @Published var _sound: [UTMQemuConfigurationSound] = []
    
    /// True if configuration is migrated from a legacy config. Not saved.
    private(set) var isLegacy: Bool = false
    
    var backend: UTMBackend {
        .qemu
    }
    
    enum CodingKeys: String, CodingKey {
        case information = "Information"
        case system = "System"
        case qemu = "QEMU"
        case input = "Input"
        case sharing = "Sharing"
        case displays = "Display"
        case drives = "Drive"
        case networks = "Network"
        case serials = "Serial"
        case sound = "Sound"
        case backend = "Backend"
        case configurationVersion = "ConfigurationVersion"
    }
    
    init() {
        reset()
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let backend = try values.decodeIfPresent(UTMBackend.self, forKey: .backend) ?? .qemu
        guard backend == .qemu else {
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
        _system = try values.decode(UTMQemuConfigurationSystem.self, forKey: .system)
        _qemu = try values.decode(UTMQemuConfigurationQEMU.self, forKey: .qemu)
        _input = try values.decode(UTMQemuConfigurationInput.self, forKey: .input)
        _sharing = try values.decode(UTMQemuConfigurationSharing.self, forKey: .sharing)
        _displays = try values.decode([UTMQemuConfigurationDisplay].self, forKey: .displays)
        _drives = try values.decode([UTMQemuConfigurationDrive].self, forKey: .drives)
        _networks = try values.decode([UTMQemuConfigurationNetwork].self, forKey: .networks)
        _serials = try values.decode([UTMQemuConfigurationSerial].self, forKey: .serials)
        _sound = try values.decode([UTMQemuConfigurationSound].self, forKey: .sound)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_information, forKey: .information)
        try container.encode(_system, forKey: .system)
        try container.encode(_qemu, forKey: .qemu)
        try container.encode(_input, forKey: .input)
        try container.encode(_sharing, forKey: .sharing)
        try container.encode(_displays, forKey: .displays)
        try container.encode(_drives, forKey: .drives)
        try container.encode(_networks, forKey: .networks)
        try container.encode(_serials, forKey: .serials)
        try container.encode(_sound, forKey: .sound)
        try container.encode(UTMBackend.qemu, forKey: .backend)
        try container.encode(Self.currentVersion, forKey: .configurationVersion)
    }
}

enum UTMQemuConfigurationError: Error {
    case migrationFailed
    case uefiNotSupported
}

extension UTMQemuConfigurationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return NSLocalizedString("Failed to migrate configuration from a previous UTM version.", comment: "UTMQemuConfigurationError")
        case .uefiNotSupported:
            return NSLocalizedString("UEFI is not supported with this architecture.", comment: "UTMQemuConfigurationError")
        }
    }
}

// MARK: - Public accessors

@MainActor extension UTMQemuConfiguration {
    var information: UTMConfigurationInfo {
        get {
            _information
        }
        
        set {
            _information = newValue
        }
    }
    
    var system: UTMQemuConfigurationSystem {
        get {
            _system
        }
        
        set {
            _system = newValue
        }
    }
    
    var qemu: UTMQemuConfigurationQEMU {
        get {
            _qemu
        }
        
        set {
            _qemu = newValue
        }
    }
    
    var input: UTMQemuConfigurationInput {
        get {
            _input
        }
        
        set {
            _input = newValue
        }
    }
    
    var sharing: UTMQemuConfigurationSharing {
        get {
            _sharing
        }
        
        set {
            _sharing = newValue
        }
    }
    
    var displays: [UTMQemuConfigurationDisplay] {
        get {
            _displays
        }
        
        set {
            _displays = newValue
        }
    }
    
    var drives: [UTMQemuConfigurationDrive] {
        get {
            _drives
        }
        
        set {
            _drives = newValue
        }
    }
    
    var networks: [UTMQemuConfigurationNetwork] {
        get {
            _networks
        }
        
        set {
            _networks = newValue
        }
    }
    
    var serials: [UTMQemuConfigurationSerial] {
        get {
            _serials
        }
        
        set {
            _serials = newValue
        }
    }
    
    var sound: [UTMQemuConfigurationSound] {
        get {
            _sound
        }
        
        set {
            _sound = newValue
        }
    }
}

// MARK: - Defaults

extension UTMQemuConfiguration {
    private func reset(all: Bool = true) {
        if all {
            _information = .init()
            _system = .init()
            _drives = []
        }
        _qemu = .init()
        _input = .init()
        _sharing = .init()
        _displays = []
        _networks = []
        _serials = []
        _sound = []
    }
    
    @MainActor func reset(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        reset(all: false)
        qemu = .init(forArchitecture: architecture, target: target)
        input = .init(forArchitecture: architecture, target: target)
        sharing = .init(forArchitecture: architecture, target: target)
        system.cpu = architecture.cpuType.default
        if let display = UTMQemuConfigurationDisplay(forArchitecture: architecture, target: target) {
            displays = [display]
        } else {
            serials = [UTMQemuConfigurationSerial()]
        }
        if let network = UTMQemuConfigurationNetwork(forArchitecture: architecture, target: target) {
            networks = [network]
        }
        if let _sound = UTMQemuConfigurationSound(forArchitecture: architecture, target: target) {
            sound = [_sound]
        }
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfiguration {
    convenience init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        isLegacy = true
        _information = .init(migrating: oldConfig)
        _system = .init(migrating: oldConfig)
        _qemu = .init(migrating: oldConfig)
        _input = .init(migrating: oldConfig)
        _sharing = .init(migrating: oldConfig)
        if let display = UTMQemuConfigurationDisplay(migrating: oldConfig) {
            _displays = [display]
        }
        _drives = (0..<oldConfig.countDrives).map({ i in UTMQemuConfigurationDrive(migrating: oldConfig, at: i) })
        // remove efi_vars which is no longer stored as a drive
        _drives.removeAll { drive in
            drive.imageName == QEMUPackageFileName.efiVariables.rawValue
        }
        if let network = UTMQemuConfigurationNetwork(migrating: oldConfig) {
            _networks = [network]
        }
        if let serial = UTMQemuConfigurationSerial(migrating: oldConfig) {
            _serials = [serial]
        }
        if let __sound = UTMQemuConfigurationSound(migrating: oldConfig) {
            _sound = [__sound]
        }
    }
}

// MARK: - Saving data

@MainActor extension UTMQemuConfiguration {
    func prepareSave(for packageURL: URL) async throws {
        guard isLegacy else {
            return // nothing needed
        }
        // move Images to Data
        let fileManager = FileManager.default
        let imagesURL = packageURL.appendingPathComponent(QEMUPackageFileName.images.rawValue)
        let dataURL = packageURL.appendingPathComponent(Self.dataDirectoryName)
        if fileManager.fileExists(atPath: imagesURL.path) {
            guard !fileManager.fileExists(atPath: dataURL.path) else {
                throw UTMQemuConfigurationError.migrationFailed
            }
            try await Task.detached {
                try fileManager.moveItem(at: imagesURL, to: dataURL)
            }.value
        }
        // update any drives
        for i in 0..<drives.count {
            if !drives[i].isExternal, let oldImageURL = drives[i].imageURL {
                drives[i].imageURL = dataURL.appendingPathComponent(oldImageURL.lastPathComponent)
            }
        }
        // move icon
        if information.isIconCustom, let oldIconURL = information.iconURL {
            let newIconURL = dataURL.appendingPathComponent(oldIconURL.lastPathComponent)
            try await Task.detached {
                try fileManager.moveItem(at: oldIconURL, to: newIconURL)
            }.value
            information.iconURL = newIconURL
        }
        // move debug log
        if let oldLogURL = qemu.debugLogURL, fileManager.fileExists(atPath: oldLogURL.path) {
            let newLogURL = dataURL.appendingPathComponent(oldLogURL.lastPathComponent)
            await Task.detached {
                do {
                    try fileManager.moveItem(at: oldLogURL, to: newLogURL)
                } catch {
                    // okay to fail
                    try? fileManager.removeItem(at: oldLogURL)
                }
            }.value
            qemu.debugLogURL = newLogURL
        }
        // move efi variables
        qemu.efiVarsURL = nil // will be set at saveData
    }
    
    func saveData(to dataURL: URL) async throws -> [URL] {
        var existingDataURLs = [URL]()
        
        existingDataURLs += try await _information.saveData(to: dataURL)
        existingDataURLs += try await _qemu.saveData(to: dataURL, for: system)

        for i in 0..<drives.count {
            existingDataURLs += try await _drives[i].saveData(to: dataURL)
        }
        
        return existingDataURLs
    }
}
