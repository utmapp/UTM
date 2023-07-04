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
struct UTMAppleConfigurationNetwork: Codable, Identifiable {
    enum NetworkMode: String, CaseIterable, QEMUConstant {
        case shared = "Shared"
        case bridged = "Bridged"
        
        var prettyValue: String {
            switch self {
            case .shared: return NSLocalizedString("Shared Network", comment: "UTMAppleConfigurationNetwork")
            case .bridged: return NSLocalizedString("Bridged (Advanced)", comment: "UTMAppleConfigurationNetwork")
            }
        }
    }
    
    var mode: NetworkMode = .shared
    
    /// Unique MAC address.
    var macAddress: String = VZMACAddress.randomLocallyAdministered().string
    
    /// In bridged mode this is the physical interface to bridge.
    var bridgeInterface: String?
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case mode = "Mode"
        case macAddress = "MacAddress"
        case bridgeInterface = "BridgeInterface"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decode(NetworkMode.self, forKey: .mode)
        macAddress = try values.decode(String.self, forKey: .macAddress)
        bridgeInterface = try values.decodeIfPresent(String.self, forKey: .bridgeInterface)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(macAddress, forKey: .macAddress)
        if mode == .bridged {
            try container.encodeIfPresent(bridgeInterface, forKey: .bridgeInterface)
        }
    }
    
    init?(from config: VZNetworkDeviceConfiguration) {
        guard let virtioConfig = config as? VZVirtioNetworkDeviceConfiguration else {
            return nil
        }
        macAddress = virtioConfig.macAddress.string
        if let attachment = virtioConfig.attachment as? VZBridgedNetworkDeviceAttachment {
            mode = .bridged
            bridgeInterface = attachment.interface.identifier
        } else if let _ = virtioConfig.attachment as? VZNATNetworkDeviceAttachment {
            mode = .shared
        } else {
            return nil
        }
    }
    
    func vzNetworking() -> VZNetworkDeviceConfiguration? {
        let config = VZVirtioNetworkDeviceConfiguration()
        guard let macAddress = VZMACAddress(string: macAddress) else {
            return nil
        }
        config.macAddress = macAddress
        switch mode {
        case .shared:
            let attachment = VZNATNetworkDeviceAttachment()
            config.attachment = attachment
        case .bridged:
            var found: VZBridgedNetworkInterface?
            if let bridgeInterface = bridgeInterface {
                for interface in VZBridgedNetworkInterface.networkInterfaces {
                    if interface.identifier == bridgeInterface {
                        found = interface
                        break
                    }
                }
            } else {
                // default to first interface if unspecified
                found = VZBridgedNetworkInterface.networkInterfaces.first
            }
            if let found = found {
                let attachment = VZBridgedNetworkDeviceAttachment(interface: found)
                config.attachment = attachment
            }
        }
        return config
    }
}

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationNetwork {
    init(migrating oldNetwork: Network) {
        switch oldNetwork.networkMode {
        case .Bridged: mode = .bridged
        case .Shared: mode = .shared
        }
        macAddress = oldNetwork.macAddress
        bridgeInterface = oldNetwork.bridgeInterfaceIdentifier
    }
}
