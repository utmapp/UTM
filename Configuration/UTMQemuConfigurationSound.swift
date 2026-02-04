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

/// Settings for single audio device
struct UTMQemuConfigurationSound: Codable, Identifiable {
    /// Hardware model to emulate.
    var hardware: any QEMUSoundDevice = QEMUSoundDevice_x86_64.AC97
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case hardware = "Hardware"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hardware = try values.decode(AnyQEMUConstant.self, forKey: .hardware)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardware.asAnyQEMUConstant(), forKey: .hardware)
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationSound {
    init?(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
        let rawTarget = target.rawValue
        if rawTarget.hasPrefix("pc") || rawTarget == "isapc" {
            hardware = QEMUSoundDevice_i386.sb16
        } else if rawTarget.hasPrefix("pc") || rawTarget.hasPrefix("pseries") {
            hardware = QEMUSoundDevice_x86_64.AC97
        } else if rawTarget.hasPrefix("q35") || rawTarget.hasPrefix("virt-") || rawTarget == "virt" {
            hardware = QEMUSoundDevice_x86_64.intel_hda
        } else if rawTarget == "mac99" {
            hardware = QEMUSoundDevice_ppc.screamer
        } else if architecture == .m68k && rawTarget == QEMUTarget_m68k.q800.rawValue {
            hardware = QEMUSoundDevice_m68k.asc
        } else if rawTarget.hasPrefix("raspi") {
            return nil
        } else {
            let cards = architecture.soundDeviceType.allRawValues
            if let first = cards.first {
                hardware = AnyQEMUConstant(rawValue: first)!
            } else {
                return nil
            }
        }
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationSound {
    init?(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        guard oldConfig.soundEnabled else {
            return nil
        }
        if oldConfig.soundCard == "ac97" { // change in case for this one device
            hardware = AnyQEMUConstant(rawValue: "AC97")!
        } else if let hardwareStr = oldConfig.soundCard {
            hardware = AnyQEMUConstant(rawValue: hardwareStr)!
        }
    }
}
