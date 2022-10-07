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

/// Network settings for a single device.
struct UTMQemuConfigurationNetwork: Codable, Identifiable {
    /// Operating mode of this adapter
    var mode: QEMUNetworkMode = .emulated
    
    /// Hardware model to emulate.
    var hardware: any QEMUNetworkDevice = QEMUNetworkDevice_x86_64.e1000
    
    /// Unique MAC address.
    var macAddress: String = UTMQemuConfigurationNetwork.randomMacAddress()
    
    /// If true, will attempt to isolate the host in the guest VLAN.
    var isIsolateFromHost: Bool = false
    
    /// List of forwarded ports.
    var portForward: [UTMQemuConfigurationPortForward] = []
    
    /// In bridged mode this is the physical interface to bridge.
    var bridgeInterface: String?
    
    /// Guest IPv4 for emulated VLAN.
    var vlanGuestAddress: String?
    
    /// Guest IPv6 for emulated VLAN.
    var vlanGuestAddressIPv6: String?
    
    /// Host IPv4 for emulated VLAN.
    var vlanHostAddress: String?
    
    /// Host IPv6 for emulated VLAN.
    var vlanHostAddressIPv6: String?
    
    /// DHCP start address for emulated VLAN.
    var vlanDhcpStartAddress: String?
    
    /// DHCP domain for emulated VLAN.
    var vlanDhcpDomain: String?
    
    /// DNS server for emulated VLAN.
    var vlanDnsServerAddress: String?
    
    /// DNS server (IPv6) for emulated VLAN.
    var vlanDnsServerAddressIPv6: String?
    
    /// DNS search domain for emulated VLAN.
    var vlanDnsSearchDomain: String?
    
    let id = UUID()
    
    /// Generate a random MAC address
    /// - Returns: A random MAC address
    static func randomMacAddress() -> String {
        var bytes = (0..<6).map { _ in
            arc4random() % 256
        }
        // byte 0 should be local
        bytes[0] = (bytes[0] & 0xFC) | 0x2
        let string = bytes.reduce("") { partialResult, byte in
            partialResult + String(format: ":%02X", byte)
        }
        return String(string.dropFirst())
    }
    
    enum CodingKeys: String, CodingKey {
        case mode = "Mode"
        case hardware = "Hardware"
        case macAddress = "MacAddress"
        case isIsolateFromHost = "IsolateFromHost"
        case portForward = "PortForward"
        case bridgeInterface = "BridgeInterface"
        case vlanGuestAddress = "VlanGuestAddress"
        case vlanGuestAddressIPv6 = "VlanGuestAddressIPv6"
        case vlanHostAddress = "VlanHostAddress"
        case vlanHostAddressIPv6 = "VlanHostAddressIPv6"
        case vlanDhcpStartAddress = "VlanDhcpStartAddress"
        case vlanDhcpDomain = "VlanDhcpDomain"
        case vlanDnsServerAddress = "VlanDnsServerAddress"
        case vlanDnsServerAddressIPv6 = "VlanDnsServerAddressIPv6"
        case vlanDnsSearchDomain = "VlanDnsSearchDomain"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decode(QEMUNetworkMode.self, forKey: .mode)
        hardware = try values.decode(AnyQEMUConstant.self, forKey: .hardware)
        macAddress = try values.decode(String.self, forKey: .macAddress)
        isIsolateFromHost = try values.decode(Bool.self, forKey: .isIsolateFromHost)
        portForward = try values.decode([UTMQemuConfigurationPortForward].self, forKey: .portForward)
        bridgeInterface = try values.decodeIfPresent(String.self, forKey: .bridgeInterface)
        vlanGuestAddress = try values.decodeIfPresent(String.self, forKey: .vlanGuestAddress)
        vlanGuestAddressIPv6 = try values.decodeIfPresent(String.self, forKey: .vlanGuestAddressIPv6)
        vlanHostAddress = try values.decodeIfPresent(String.self, forKey: .vlanHostAddress)
        vlanHostAddressIPv6 = try values.decodeIfPresent(String.self, forKey: .vlanHostAddressIPv6)
        vlanDhcpStartAddress = try values.decodeIfPresent(String.self, forKey: .vlanDhcpStartAddress)
        vlanDhcpDomain = try values.decodeIfPresent(String.self, forKey: .vlanDhcpDomain)
        vlanDnsServerAddress = try values.decodeIfPresent(String.self, forKey: .vlanDnsServerAddress)
        vlanDnsServerAddressIPv6 = try values.decodeIfPresent(String.self, forKey: .vlanDnsServerAddressIPv6)
        vlanDnsSearchDomain = try values.decodeIfPresent(String.self, forKey: .vlanDnsSearchDomain)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(hardware.asAnyQEMUConstant(), forKey: .hardware)
        try container.encode(macAddress, forKey: .macAddress)
        try container.encode(isIsolateFromHost, forKey: .isIsolateFromHost)
        try container.encode(portForward, forKey: .portForward)
        if mode == .bridged {
            try container.encodeIfPresent(bridgeInterface, forKey: .bridgeInterface)
        }
        try container.encodeIfPresent(vlanGuestAddress, forKey: .vlanGuestAddress)
        try container.encodeIfPresent(vlanGuestAddressIPv6, forKey: .vlanGuestAddressIPv6)
        try container.encodeIfPresent(vlanHostAddress, forKey: .vlanHostAddress)
        try container.encodeIfPresent(vlanHostAddressIPv6, forKey: .vlanHostAddressIPv6)
        try container.encodeIfPresent(vlanDhcpStartAddress, forKey: .vlanDhcpStartAddress)
        try container.encodeIfPresent(vlanDhcpDomain, forKey: .vlanDhcpDomain)
        try container.encodeIfPresent(vlanDnsServerAddress, forKey: .vlanDnsServerAddress)
        try container.encodeIfPresent(vlanDnsServerAddressIPv6, forKey: .vlanDnsServerAddressIPv6)
        try container.encodeIfPresent(vlanDnsSearchDomain, forKey: .vlanDnsSearchDomain)
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationNetwork {
    init?(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
        let rawTarget = target.rawValue
        if rawTarget.hasPrefix("pc") {
            hardware = QEMUNetworkDevice_x86_64.rtl8139
        } else if rawTarget.hasPrefix("q35") {
            hardware = QEMUNetworkDevice_x86_64.e1000
        } else if rawTarget.hasPrefix("virt-") || rawTarget == "virt" {
            hardware = QEMUNetworkDevice_aarch64.virtio_net_pci
        } else {
            let cards = architecture.networkDeviceType.allRawValues
            if let first = cards.first {
                hardware = AnyQEMUConstant(rawValue: first)!
            } else {
                return nil
            }
        }
        #if os(macOS)
        mode = .shared
        #else
        mode = .emulated
        #endif
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationNetwork {
    init?(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        guard oldConfig.networkEnabled else {
            return nil
        }
        guard let oldMode = convertMode(from: oldConfig.networkMode) else {
            return nil
        }
        mode = oldMode
        if let hardwareStr = oldConfig.networkCard {
            hardware = AnyQEMUConstant(rawValue: hardwareStr)!
        }
        if let macString = oldConfig.networkCardMac {
            macAddress = macString
        }
        isIsolateFromHost = oldConfig.networkIsolate
        bridgeInterface = oldConfig.networkBridgeInterface
        vlanGuestAddress = oldConfig.networkAddress
        vlanGuestAddressIPv6 = oldConfig.networkAddressIPv6
        vlanHostAddress = oldConfig.networkHost
        vlanHostAddressIPv6 = oldConfig.networkHostIPv6
        vlanDhcpStartAddress = oldConfig.networkDhcpStart
        vlanDhcpDomain = oldConfig.networkDhcpDomain
        vlanDnsServerAddress = oldConfig.networkDnsServer
        vlanDnsServerAddressIPv6 = oldConfig.networkDnsServerIPv6
        vlanDnsSearchDomain = oldConfig.networkDnsSearch
        for i in 0..<oldConfig.countPortForwards {
            let oldPortForward = oldConfig.portForward(for: i)!
            portForward.append(UTMQemuConfigurationPortForward(migrating: oldPortForward))
        }
    }
    
    private func convertMode(from str: String?) -> QEMUNetworkMode? {
        if str == "emulated" {
            return .emulated
        } else if str == "shared" {
            return .shared
        } else if str == "host" {
            return .host
        } else if str == "bridged" {
            return .bridged
        } else {
            return nil
        }
    }
}
