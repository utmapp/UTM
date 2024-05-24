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
struct UTMAppleConfigurationDisplay: Codable, Identifiable {
    
    var widthInPixels: Int = 1920
    
    var heightInPixels: Int = 1200
    
    var pixelsPerInch: Int = 80

    var isDynamicResolution: Bool = true

    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case widthInPixels = "WidthPixels"
        case heightInPixels = "HeightPixels"
        case pixelsPerInch = "PixelsPerInch"
        case isDynamicResolution = "DynamicResolution"
    }
    
    init() {
    }
    
    init(width: Int, height: Int, ppi: Int = 80) {
        widthInPixels = width
        heightInPixels = height
        pixelsPerInch = ppi
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        widthInPixels = try values.decode(Int.self, forKey: .widthInPixels)
        heightInPixels = try values.decode(Int.self, forKey: .heightInPixels)
        pixelsPerInch = try values.decode(Int.self, forKey: .pixelsPerInch)
        isDynamicResolution = try values.decodeIfPresent(Bool.self, forKey: .isDynamicResolution) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widthInPixels, forKey: .widthInPixels)
        try container.encode(heightInPixels, forKey: .heightInPixels)
        try container.encode(pixelsPerInch, forKey: .pixelsPerInch)
        try container.encode(isDynamicResolution, forKey: .isDynamicResolution)
    }
    
    #if arch(arm64)
    @available(macOS 12, *)
    init(from config: VZMacGraphicsDisplayConfiguration) {
        widthInPixels = config.widthInPixels
        heightInPixels = config.heightInPixels
        pixelsPerInch = config.pixelsPerInch
    }
    
    @available(macOS 12, *)
    func vzMacDisplay() -> VZMacGraphicsDisplayConfiguration {
        VZMacGraphicsDisplayConfiguration(widthInPixels: widthInPixels,
                                          heightInPixels: heightInPixels,
                                          pixelsPerInch: pixelsPerInch)
    }
    #endif
    
    @available(macOS 13, *)
    func vzVirtioDisplay() -> VZVirtioGraphicsScanoutConfiguration {
        VZVirtioGraphicsScanoutConfiguration(widthInPixels: widthInPixels,
                                             heightInPixels: heightInPixels)
    }
}

// MARK: - Conversion of old config format

#if arch(arm64)
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
extension UTMAppleConfigurationDisplay {
    init(migrating oldDisplay: Display) {
        widthInPixels = oldDisplay.widthInPixels
        heightInPixels = oldDisplay.heightInPixels
        pixelsPerInch = oldDisplay.pixelsPerInch
    }
}
#endif
