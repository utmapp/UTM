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
@available(iOS 13, macOS 11, *)
class UTMQemuConfiguration: Codable, ObservableObject {
    private let oldestVersion = 3
    private let currentVersion = 3
    
    /// Basic information and icon
    @Published var information: UTMConfigurationInfo = .init()
    
    /// System settings
    @Published var system: UTMQemuConfigurationSystem = .init()
    
    /// Additional QEMU tweaks
    @Published var qemu: UTMQemuConfigurationQEMU = .init()
    
    /// Input settings
    @Published var input: UTMQemuConfigurationInput = .init()
    
    /// Sharing settings
    @Published var sharing: UTMQemuConfigurationSharing = .init()
    
    /// All displays
    @Published var displays: [UTMQemuConfigurationDisplay] = []
    
    /// All drives
    @Published var drives: [UTMQemuConfigurationDrive] = []
    
    /// All network adapters
    @Published var networks: [UTMQemuConfigurationNetwork] = []
    
    /// All serial ouputs
    @Published var serials: [UTMQemuConfigurationSerial] = []
    
    /// All audio devices
    @Published var sound: [UTMQemuConfigurationSound] = []
    
    /// If set, points to the data directory for this configuration. Not saved.
    var dataURL: URL?
    
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
        system = try values.decode(UTMQemuConfigurationSystem.self, forKey: .system)
        qemu = try values.decode(UTMQemuConfigurationQEMU.self, forKey: .qemu)
        input = try values.decode(UTMQemuConfigurationInput.self, forKey: .input)
        sharing = try values.decode(UTMQemuConfigurationSharing.self, forKey: .sharing)
        displays = try values.decode([UTMQemuConfigurationDisplay].self, forKey: .displays)
        drives = try values.decode([UTMQemuConfigurationDrive].self, forKey: .drives)
        networks = try values.decode([UTMQemuConfigurationNetwork].self, forKey: .networks)
        serials = try values.decode([UTMQemuConfigurationSerial].self, forKey: .serials)
        sound = try values.decode([UTMQemuConfigurationSound].self, forKey: .sound)
        dataURL = decoder.userInfo[.dataURL] as? URL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(information, forKey: .information)
        try container.encode(system, forKey: .system)
        try container.encode(qemu, forKey: .qemu)
        try container.encode(input, forKey: .input)
        try container.encode(sharing, forKey: .sharing)
        try container.encode(displays, forKey: .displays)
        try container.encode(drives, forKey: .drives)
        try container.encode(networks, forKey: .networks)
        try container.encode(serials, forKey: .serials)
        try container.encode(sound, forKey: .sound)
        try container.encode(UTMBackend.qemu, forKey: .backend)
        try container.encode(currentVersion, forKey: .configurationVersion)
    }
}

// MARK: - Defaults

@available(iOS 13, macOS 11, *)
extension UTMQemuConfiguration {
    func reset(all: Bool = true) {
        if all {
            information = .init()
            system = .init()
            drives = []
        }
        qemu = .init()
        input = .init()
        sharing = .init()
        displays = []
        networks = []
        serials = []
        sound = []
    }
    
    func reset(forArchitecture architecture: QEMUArchitecture, target: QEMUTarget) {
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

@available(iOS 13, macOS 11, *)
extension UTMQemuConfiguration {
    convenience init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        information = .init(migrating: oldConfig)
        system = .init(migrating: oldConfig)
        qemu = .init(migrating: oldConfig)
        input = .init(migrating: oldConfig)
        sharing = .init(migrating: oldConfig)
        if let display = UTMQemuConfigurationDisplay(migrating: oldConfig) {
            displays = [display]
        }
        drives = (0..<oldConfig.countDrives).map({ i in UTMQemuConfigurationDrive(migrating: oldConfig, at: i) })
        if let network = UTMQemuConfigurationNetwork(migrating: oldConfig) {
            networks = [network]
        }
        if let serial = UTMQemuConfigurationSerial(migrating: oldConfig) {
            serials = [serial]
        }
        if let _sound = UTMQemuConfigurationSound(migrating: oldConfig) {
            sound = [_sound]
        }
    }
}

// MARK: UserInfo key constant

// TODO: maybe move this elsewhere as it is shared by both backend configs
extension CodingUserInfoKey {
    static var dataURL: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "dataURL")!
    }
}

// MARK: Config parsing

enum UTMBackend: String, CaseIterable, Codable {
    case apple = "Apple"
    case qemu = "QEMU"
}

enum QEMUConfigError: Error {
    case versionTooLow
    case versionTooHigh
    case invalidBackend
}

extension QEMUConfigError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .versionTooLow: return NSLocalizedString("This configuration is too old and is not supported.", comment: "UTMQemuConfiguration")
        case .versionTooHigh: return NSLocalizedString("This configuration is saved with a newer version of UTM and is not compatible with this version.", comment: "UTMQemuConfiguration")
        case .invalidBackend: return NSLocalizedString("The backend for this configuration is not supported.", comment: "UTMQemuConfiguration")
        }
    }
}
