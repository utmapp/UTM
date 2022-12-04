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

/// Directory and clipboard sharing settings
struct UTMQemuConfigurationSharing: Codable {
    /// SPICE or virtfs sharing.
    var directoryShareMode: QEMUFileShareMode = .none
    
    /// Sharing should be read only
    var isDirectoryShareReadOnly: Bool = false
    
    /// The directory to share. Not saved.
    var directoryShareUrl: URL?
    
    /// SPICE clipboard sharing.
    var hasClipboardSharing: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case directoryShareMode = "DirectoryShareMode"
        case isDirectoryShareReadOnly = "DirectoryShareReadOnly"
        case hasClipboardSharing = "ClipboardSharing"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        directoryShareMode = try values.decode(QEMUFileShareMode.self, forKey: .directoryShareMode)
        isDirectoryShareReadOnly = try values.decode(Bool.self, forKey: .isDirectoryShareReadOnly)
        hasClipboardSharing = try values.decode(Bool.self, forKey: .hasClipboardSharing)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(directoryShareMode, forKey: .directoryShareMode)
        try container.encode(isDirectoryShareReadOnly, forKey: .isDirectoryShareReadOnly)
        try container.encode(hasClipboardSharing, forKey: .hasClipboardSharing)
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationSharing {
    init(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
        let rawTarget = target.rawValue
        if !architecture.hasAgentSupport {
            hasClipboardSharing = false
        }
        if !architecture.hasSharingSupport {
            directoryShareMode = .none
        }
        // overrides for specific configurations
        if rawTarget.hasPrefix("pc") || rawTarget.hasPrefix("q35") {
            directoryShareMode = .webdav
            hasClipboardSharing = true
        } else if (architecture == .arm || architecture == .aarch64) && (rawTarget.hasPrefix("virt-") || rawTarget == "virt") {
            directoryShareMode = .webdav
            hasClipboardSharing = true
        }
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationSharing {
    init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        if oldConfig.shareDirectoryEnabled {
            directoryShareMode = .webdav
        }
        isDirectoryShareReadOnly = oldConfig.shareDirectoryReadOnly
        hasClipboardSharing = oldConfig.shareClipboardEnabled
    }
}
