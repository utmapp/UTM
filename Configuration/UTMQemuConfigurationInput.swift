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

/// Settings for input devices and USB.
struct UTMQemuConfigurationInput: Codable {
    /// Level of USB support (disabled/2.0/3.0).
    var usbBusSupport: QEMUUSBBus = .usb2_0
    
    /// If enabled, USB forwarding can be used (if supported by the host).
    var hasUsbSharing: Bool = false
    
    /// The maximum number of USB devices that can be forwarded concurrently.
    var maximumUsbShare: Int = 3
    
    enum CodingKeys: String, CodingKey {
        case usbBusSupport = "UsbBusSupport"
        case hasUsbSharing = "UsbSharing"
        case maximumUsbShare = "MaximumUsbShare"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        usbBusSupport = try values.decode(QEMUUSBBus.self, forKey: .usbBusSupport)
        hasUsbSharing = try values.decode(Bool.self, forKey: .hasUsbSharing)
        maximumUsbShare = try values.decode(Int.self, forKey: .maximumUsbShare)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usbBusSupport, forKey: .usbBusSupport)
        try container.encode(hasUsbSharing, forKey: .hasUsbSharing)
        try container.encode(maximumUsbShare, forKey: .maximumUsbShare)
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationInput {
    init(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
        let rawTarget = target.rawValue
        if !architecture.hasUsbSupport || !target.hasUsbSupport {
            usbBusSupport = .disabled
        } else if rawTarget.hasPrefix("pc") || rawTarget.hasPrefix("q35") {
            usbBusSupport = .usb3_0
        } else if (architecture == .arm || architecture == .aarch64) && (rawTarget.hasPrefix("virt-") || rawTarget == "virt") {
            usbBusSupport = .usb3_0
        }
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationInput {
    init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        if oldConfig.inputLegacy {
            usbBusSupport = .disabled
        } else if oldConfig.usb3Support {
            usbBusSupport = .usb3_0
        } else {
            usbBusSupport = .usb2_0
        }
        if let sharingNum = oldConfig.usbRedirectionMaximumDevices {
            hasUsbSharing = true
            maximumUsbShare = sharingNum.intValue
        }
    }
}
