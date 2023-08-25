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

/// Represent a single port forward
struct UTMQemuConfigurationPortForward: Codable, Identifiable, Hashable {
    /// Socket protocol
    var `protocol`: QEMUNetworkProtocol = .tcp
    
    /// Host address (nil for any address).
    var hostAddress: String?
    
    /// Host port to recieve connection.
    var hostPort: Int = 0
    
    /// Guest address (nil for any address).
    var guestAddress: String?
    
    /// Guest port where connection is coming from.
    var guestPort: Int = 0
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case `protocol` = "Protocol"
        case hostAddress = "HostAddress"
        case hostPort = "HostPort"
        case guestAddress = "GuestAddress"
        case guestPort = "GuestPort"
    }
    
    enum CodingKeysOld: String, CodingKey {
        case `protocol` = "protocol"
        case hostAddress = "hostAddress"
        case hostPort = "hostPort"
        case guestAddress = "guestAddress"
        case guestPort = "guestPort"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        do {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            `protocol` = try values.decode(QEMUNetworkProtocol.self, forKey: .protocol)
            hostAddress = try values.decodeIfPresent(String.self, forKey: .hostAddress)
            hostPort = try values.decode(Int.self, forKey: .hostPort)
            guestAddress = try values.decodeIfPresent(String.self, forKey: .guestAddress)
            guestPort = try values.decode(Int.self, forKey: .guestPort)
        } catch is DecodingError {
            // before UTM v4.4, we mistakingly used camel-case in the config.plist
            let values = try decoder.container(keyedBy: CodingKeysOld.self)
            `protocol` = try values.decode(QEMUNetworkProtocol.self, forKey: .protocol)
            hostAddress = try values.decodeIfPresent(String.self, forKey: .hostAddress)
            hostPort = try values.decode(Int.self, forKey: .hostPort)
            guestAddress = try values.decodeIfPresent(String.self, forKey: .guestAddress)
            guestPort = try values.decode(Int.self, forKey: .guestPort)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(`protocol`, forKey: .protocol)
        try container.encodeIfPresent(hostAddress, forKey: .hostAddress)
        try container.encode(hostPort, forKey: .hostPort)
        try container.encodeIfPresent(guestAddress, forKey: .guestAddress)
        try container.encode(guestPort, forKey: .guestPort)
    }
    
    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationPortForward {
    init(migrating oldForward: UTMLegacyQemuConfigurationPortForward) {
        self.init()
        if let oldProtocol = convertProtocol(from: oldForward.protocol) {
            `protocol` = oldProtocol
        }
        hostAddress = oldForward.hostAddress
        if let portNum = oldForward.guestPort {
            hostPort = portNum.intValue
        }
        guestAddress = oldForward.guestAddress
        if let portNum = oldForward.guestPort {
            guestPort = portNum.intValue
        }
    }
    
    private func convertProtocol(from str: String?) -> QEMUNetworkProtocol? {
        if str == "tcp" {
            return .tcp
        } else if str == "udp" {
            return .udp
        } else {
            return nil
        }
    }
}
