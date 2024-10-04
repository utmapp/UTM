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

/// Basic information about the VM only used in listing and presenting.
struct UTMConfigurationInfo: Codable {
    /// VM name displayed to user.
    var name: String = NSLocalizedString("Virtual Machine", comment: "UTMConfigurationInfo")
    
    #if os(macOS)
    /// If true, starts the VM in full screen.
    var isFullScreenStart: Bool = false
    #endif
    
    /// Path to the icon.
    var iconURL: URL?
    
    /// If true, the icon is stored in the bundle. Otherwise, the icon is built-in.
    var isIconCustom: Bool = false
    
    /// User specified notes to be displayed when the VM is selected.
    var notes: String?
    
    /// Random identifier not accessible by the user.
    var uuid: UUID = UUID()
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case icon = "Icon"
        case isIconCustom = "IconCustom"
        case notes = "Notes"
        case uuid = "UUID"
        case isFullScreenStart = "IsFullScreenStart"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        isIconCustom = try values.decode(Bool.self, forKey: .isIconCustom)
        if isIconCustom {
            guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
                throw UTMConfigurationError.invalidDataURL
            }
            let iconName = try values.decode(String.self, forKey: .icon)
            iconURL = dataURL.appendingPathComponent(iconName)
        } else if let iconName = try values.decodeIfPresent(String.self, forKey: .icon) {
            iconURL = Self.builtinIcon(named: iconName)
        }
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        uuid = try values.decode(UUID.self, forKey: .uuid)
        #if os(macOS)
        isFullScreenStart = try values.decodeIfPresent(Bool.self, forKey: .isFullScreenStart) ?? false
        #endif
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if isIconCustom, let iconURL = iconURL {
            try container.encode(true, forKey: .isIconCustom)
            try container.encode(iconURL.lastPathComponent, forKey: .icon)
        } else if !isIconCustom, let name = iconURL?.deletingPathExtension().lastPathComponent {
            try container.encode(false, forKey: .isIconCustom)
            try container.encode(name, forKey: .icon)
        } else {
            try container.encode(false, forKey: .isIconCustom)
        }
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(uuid, forKey: .uuid)
        #if os(macOS)
        try container.encode(isFullScreenStart, forKey: .isFullScreenStart)
        #endif
    }
    
    static func builtinIcon(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Icons")
    }
}

// MARK: - Conversion of old config format

extension UTMConfigurationInfo {
    init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        name = oldConfig.name
        notes = oldConfig.notes
        if let uuidString = oldConfig.systemUUID, let uuid = UUID(uuidString: uuidString) {
            self.uuid = uuid
        }
        isIconCustom = oldConfig.iconCustom
        if isIconCustom {
            if let name = oldConfig.icon, let dataURL = oldConfig.existingPath {
                iconURL = dataURL.appendingPathComponent(name)
            } else {
                isIconCustom = false
            }
        }
        if !isIconCustom, let name = oldConfig.icon {
            iconURL = Self.builtinIcon(named: name)
        }
    }
    
    #if os(macOS)
    init(migrating oldConfig: UTMLegacyAppleConfiguration, dataURL: URL) {
        self.init()
        name = oldConfig.name
        notes = oldConfig.notes
        uuid = UUID()
        isIconCustom = oldConfig.iconCustom
        if isIconCustom {
            if let name = oldConfig.icon {
                iconURL = dataURL.appendingPathComponent(name)
            } else {
                isIconCustom = false
            }
        }
        if let name = oldConfig.icon {
            iconURL = Self.builtinIcon(named: name)
        }
    }
    #endif
}

// MARK: - Saving data

extension UTMConfigurationInfo {
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        // save new icon
        if isIconCustom, let iconURL = iconURL {
            let newIconURL = try await UTMQemuConfiguration.copyItemIfChanged(from: iconURL, to: dataURL)
            self.iconURL = newIconURL
            return [newIconURL]
        }
        return []
    }
}
