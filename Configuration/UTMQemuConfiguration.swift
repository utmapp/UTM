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
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
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
    }
}

// MARK: UserInfo key constant

// TODO: maybe move this elsewhere as it is shared by both backend configs
extension CodingUserInfoKey {
    static var dataURL: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "dataURL")!
    }
}
