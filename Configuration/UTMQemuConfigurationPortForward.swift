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
