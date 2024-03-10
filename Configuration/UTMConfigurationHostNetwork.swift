//
// Copyright © 2024 osy. All rights reserved.
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

/// Host network settings.
struct UTMConfigurationHostNetwork: Codable, Identifiable {
    /// Network name
    var name: String
    
    /// Network UUID
    var uuid: String = UUID().uuidString

    let id = UUID()

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case uuid = "Uuid"
    }

    init() {
        self.name = uuid
    }
    
    init(name: String) {
        self.name = name
    }
    
    init(name: String, uuid: String) {
        self.name = name
        self.uuid = uuid
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try values.decodeIfPresent(UUID.self, forKey: .uuid)?.uuidString ?? UUID().uuidString
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? uuid
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
    }
    
    static func parseVMware(from url: URL) -> [UTMConfigurationHostNetwork] {
        let accessing = url.startAccessingSecurityScopedResource()
        if !accessing { return [] }
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var currentId: String?;
        var currentName: String?;
        var currentUuid: String?;
        var result: [UTMConfigurationHostNetwork] = []
        
        if let content = try? String(contentsOf: url) {
            for line in content.split(whereSeparator: \.isNewline) {
                let parts = line.split(separator: " ")
                if parts.count != 3 || (parts[0] != "answer" && !parts[1].starts(with: "VNET_")) {
                    continue
                }
                
                let name_parts = parts[1].split(separator: "_", maxSplits: 2)
                if name_parts.count != 3 {
                    continue
                }
                
                if currentId == nil {
                    currentId = String(name_parts[1])
                }
                               
                if let id = currentId {
                    if id != name_parts[1] {
                        if let uuid = currentUuid {
                            result.append(UTMConfigurationHostNetwork(name: currentName ?? "VMware vmnet\(id)", uuid: uuid))
                        }
                        
                        currentId = String(name_parts[1])
                        currentName = nil
                        currentUuid = nil
                    }
                    
                    if name_parts[2] == "DISPLAY_NAME" {
                        currentName = String(parts[2])
                    }
                    
                    if name_parts[2] == "HOSTONLY_UUID" {
                        currentUuid = String(parts[2])
                    }
                }
            }
            
            if let id = currentId, let uuid = currentUuid {
                var newNetwork = UTMConfigurationHostNetwork()
                newNetwork.name = if let name = currentName {
                    name
                } else {
                    "VMware vmnet\(id)"
                }
                newNetwork.uuid = uuid
                result.append(newNetwork)
            }
        }

        return result
    }
}
