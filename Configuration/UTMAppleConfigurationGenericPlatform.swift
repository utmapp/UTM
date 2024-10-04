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
struct UTMAppleConfigurationGenericPlatform: Codable {
    var machineIdentifier: Data?
    
    private enum CodingKeys: String, CodingKey {
        case machineIdentifier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        machineIdentifier = try container.decodeIfPresent(Data.self, forKey: .machineIdentifier)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(machineIdentifier, forKey: .machineIdentifier)
    }
    
    init() {
        if #available(macOS 13, *) {
            machineIdentifier = VZGenericMachineIdentifier().dataRepresentation
        }
    }
    
    @available(macOS 12, *)
    func vzGenericPlatform() -> VZGenericPlatformConfiguration? {
        let config = VZGenericPlatformConfiguration()
        if #available(macOS 13, *) {
            if let machineIdentifier = machineIdentifier, let vzMachineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifier) {
                config.machineIdentifier = vzMachineIdentifier
            }
        }
        if #available(macOS 15, *) {
            // always enable nestedVirtualization when available
            config.isNestedVirtualizationEnabled = VZGenericPlatformConfiguration.isNestedVirtualizationSupported
        }
        return config
    }
}
