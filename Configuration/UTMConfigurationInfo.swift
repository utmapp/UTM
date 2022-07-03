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
    
    /// Base path of icon image. This property is not saved to file.
    var dataURL: URL?
    
    /// Full path to the custom icon image. File will be copied to VM bundle on save.
    /// This property is not saved to file.
    var selectedCustomIconPath: URL?
    
    /// Name of the icon.
    var icon: String?
    
    /// If true, the icon is stored in the bundle. Otherwise, the icon is built-in.
    var isIconCustom: Bool = false
    
    /// User specified notes to be displayed when the VM is selected.
    var notes: String?
    
    /// Random identifier not accessible by the user.
    var uuid: UUID = UUID()
    
    /// Use this to get the file to display the icon.
    var iconUrl: URL? {
        if self.isIconCustom {
            if let current = self.selectedCustomIconPath {
                return current // if we just selected a path
            }
            guard let icon = self.icon else {
                return nil
            }
            return dataURL?.appendingPathComponent(icon) // from saved config
        } else {
            guard let icon = self.icon else {
                return nil
            }
            return Bundle.main.url(forResource: icon, withExtension: "png", subdirectory: "Icons")
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case icon = "Icon"
        case isIconCustom = "IconCustom"
        case notes = "Notes"
        case uuid = "UUID"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        icon = try values.decodeIfPresent(String.self, forKey: .icon)
        isIconCustom = try values.decode(Bool.self, forKey: .isIconCustom)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        uuid = try values.decode(UUID.self, forKey: .uuid)
        dataURL = decoder.userInfo[.dataURL] as? URL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(isIconCustom, forKey: .isIconCustom)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(uuid, forKey: .uuid)
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
        dataURL = oldConfig.existingPath
        icon = oldConfig.icon
    }
    
    #if os(macOS)
    init(migrating oldConfig: UTMLegacyAppleConfiguration, dataURL: URL) {
        self.init()
        name = oldConfig.name
        notes = oldConfig.notes
        uuid = UUID()
        isIconCustom = oldConfig.iconCustom
        icon = oldConfig.icon
        self.dataURL = dataURL
    }
    #endif
}

// MARK: - Saving data

extension UTMConfigurationInfo {
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        // save new icon
        if isIconCustom {
            if let iconURL = selectedCustomIconPath {
                icon = iconURL.lastPathComponent
                return await [try UTMQemuConfiguration.copyItemIfChanged(from: iconURL, to: dataURL)]
            } else if let existingName = icon {
                return [dataURL.appendingPathComponent(existingName)]
            } else {
                throw UTMConfigurationError.customIconInvalid
            }
        }
        return []
    }
}
