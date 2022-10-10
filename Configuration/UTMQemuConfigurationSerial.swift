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
import Combine

/// Settings for single serial device
struct UTMQemuConfigurationSerial: Codable, Identifiable {
    /// The back-end character device (host controlled).
    var mode: QEMUSerialMode = .builtin
    
    /// The front-end serial port target (guest controlled).
    var target: QEMUSerialTarget = .autoDevice
    
    /// Terminal settings for built-in mode.
    var terminal: UTMConfigurationTerminal? = .init()
    
    /// Hardware model to emulate (for manual mode).
    var hardware: (any QEMUSerialDevice)?
    
    /// Path to PTTY (determined after VM starts). Not saved.
    var pttyDevice: URL?
    
    /// TCP server to connect to (for TCP client mode).
    var tcpHostAddress: String?
    
    /// TCP port to listed on or connect to (for TCP client/server mode).
    var tcpPort: Int?
    
    /// Applies only to TCP targets. If true, will wait for connection before starting VM.
    var isWaitForConnection: Bool?
    
    /// Applies only to TCP server. If true, the port will be listened on all interfaces.
    var isRemoteConnectionAllowed: Bool?
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case mode = "Mode"
        case target = "Target"
        case terminal = "Terminal"
        case hardware = "Hardware"
        case tcpHostAddress = "TcpHostAddress"
        case tcpPort = "TcpPort"
        case isWaitForConnection = "WaitForConnection"
        case isRemoteConnectionAllowed = "RemoteConnectionAllowed"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decode(QEMUSerialMode.self, forKey: .mode)
        target = try values.decode(QEMUSerialTarget.self, forKey: .target)
        terminal = try values.decodeIfPresent(UTMConfigurationTerminal.self, forKey: .terminal)
        hardware = try values.decodeIfPresent(AnyQEMUConstant.self, forKey: .hardware)
        tcpHostAddress = try values.decodeIfPresent(String.self, forKey: .tcpHostAddress)
        tcpPort = try values.decodeIfPresent(Int.self, forKey: .tcpPort)
        isWaitForConnection = try values.decodeIfPresent(Bool.self, forKey: .isWaitForConnection)
        isRemoteConnectionAllowed = try values.decodeIfPresent(Bool.self, forKey: .isRemoteConnectionAllowed)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(target, forKey: .target)
        // only save relevant settings
        switch mode {
        case .builtin:
            try container.encodeIfPresent(terminal, forKey: .terminal)
        case .tcpClient:
            try container.encodeIfPresent(tcpHostAddress, forKey: .tcpHostAddress)
            try container.encodeIfPresent(tcpPort, forKey: .tcpPort)
        case .tcpServer:
            try container.encodeIfPresent(tcpPort, forKey: .tcpPort)
            try container.encodeIfPresent(isWaitForConnection, forKey: .isWaitForConnection)
            try container.encodeIfPresent(isRemoteConnectionAllowed, forKey: .isRemoteConnectionAllowed)
        default:
            break
        }
    }
}

// MARK: - Default construction

extension UTMQemuConfigurationSerial {
    init?(forArchitecture architecture: QEMUArchitecture, target: any QEMUTarget) {
        self.init()
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationSerial {
    init?(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        guard oldConfig.displayConsoleOnly else {
            return nil
        }
        terminal = UTMConfigurationTerminal(migrating: oldConfig)
    }
}
