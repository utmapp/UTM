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

/// Settings for a single display.
struct UTMQemuConfigurationDisplay: Codable, Identifiable {
    /// Hardware card to emulate.
    var hardware: any QEMUDisplayDevice = QEMUDisplayDevice_x86_64.virtio_vga
    
    /// Only used for VGA devices.
    var vgaRamMib: Int?
    
    /// If true, attempt to use SPICE guest agent to change the display resolution automatically.
    var isDynamicResolution: Bool = true
    
    /// Filter to use when upscaling.
    var upscalingFilter: QEMUScaler = .nearest
    
    /// Filter to use when downscaling.
    var downscalingFilter: QEMUScaler = .linear
    
    /// If true, use the true (retina) resolution of the display. Otherwise, use the percieved resolution.
    var isNativeResolution: Bool = false
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case hardware = "Hardware"
        case vgaRamMib = "VgaRamMib"
        case isDynamicResolution = "DynamicResolution"
        case upscalingFilter = "UpscalingFilter"
        case downscalingFilter = "DownscalingFilter"
        case isNativeResolution = "NativeResolution"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hardware = try values.decode(AnyQEMUConstant.self, forKey: .hardware)
        vgaRamMib = try values.decodeIfPresent(Int.self, forKey: .vgaRamMib)
        isDynamicResolution = try values.decode(Bool.self, forKey: .isDynamicResolution)
        upscalingFilter = try values.decode(QEMUScaler.self, forKey: .upscalingFilter)
        downscalingFilter = try values.decode(QEMUScaler.self, forKey: .downscalingFilter)
        isNativeResolution = try values.decode(Bool.self, forKey: .isNativeResolution)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardware.asAnyQEMUConstant(), forKey: .hardware)
        try container.encodeIfPresent(vgaRamMib, forKey: .vgaRamMib)
        try container.encode(isDynamicResolution, forKey: .isDynamicResolution)
        try container.encode(upscalingFilter, forKey: .upscalingFilter)
        try container.encode(downscalingFilter, forKey: .downscalingFilter)
        try container.encode(isNativeResolution, forKey: .isNativeResolution)
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationDisplay {
    init?(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
        if !architecture.hasAgentSupport {
            isDynamicResolution = false
        }
        let rawTarget = target.rawValue
        if rawTarget.hasPrefix("pc") || rawTarget.hasPrefix("q35") {
            hardware = QEMUDisplayDevice_x86_64.virtio_vga
        } else if rawTarget.hasPrefix("virt-") || rawTarget == "virt" {
            hardware = QEMUDisplayDevice_aarch64.virtio_ramfb
        } else {
            let cards = architecture.displayDeviceType.allRawValues
            if cards.contains("VGA") {
                hardware = AnyQEMUConstant(rawValue: "VGA")!
            } else if let first = cards.first {
                hardware = AnyQEMUConstant(rawValue: first)!
            } else {
                return nil
            }
        }
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationDisplay {
    init?(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        guard !oldConfig.displayConsoleOnly else {
            return nil
        }
        if let hardwareStr = oldConfig.displayCard {
            hardware = AnyQEMUConstant(rawValue: hardwareStr)!
        }
        isDynamicResolution = oldConfig.displayFitScreen
        isNativeResolution = oldConfig.displayRetina
        if let upscaler = convertScaler(from: oldConfig.displayUpscaler) {
            upscalingFilter = upscaler
        }
        if let downscaler = convertScaler(from: oldConfig.displayDownscaler) {
            downscalingFilter = downscaler
        }
    }
    
    private func convertScaler(from str: String?) -> QEMUScaler? {
        if str == "linear" {
            return .linear
        } else if str == "nearest" {
            return .nearest
        } else {
            return nil
        }
    }
}
