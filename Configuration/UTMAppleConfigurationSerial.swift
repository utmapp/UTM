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
struct UTMAppleConfigurationSerial: Codable, Identifiable {
    enum SerialMode: String, CaseIterable, QEMUConstant {
        case builtin = "Terminal"
        case ptty = "Ptty"
        
        var prettyValue: String {
            switch self {
            case .builtin: return NSLocalizedString("Built-in Terminal", comment: "UTMAppleConfigurationTerminal")
            case .ptty: return NSLocalizedString("Pseudo-TTY Device", comment: "UTMAppleConfigurationTerminal")
            }
        }
    }
    
    var mode: SerialMode = .builtin
    
    /// Terminal settings for built-in mode.
    var terminal: UTMConfigurationTerminal? = .init()
    
    /// Set to read handle before starting VM. Not saved.
    var fileHandleForReading: FileHandle?
    
    /// Set to write handle before starting VM. Not saved.
    var fileHandleForWriting: FileHandle?
    
    /// Serial interface used by the VM. Not saved.
    var interface: UTMSerialPort?
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case mode = "Mode"
        case terminal = "Terminal"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decode(SerialMode.self, forKey: .mode)
        terminal = try values.decodeIfPresent(UTMConfigurationTerminal.self, forKey: .terminal)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        // only save relevant settings
        switch mode {
        case .builtin:
            try container.encodeIfPresent(terminal, forKey: .terminal)
        default:
            break
        }
    }
    
    func vzSerial() -> VZSerialPortConfiguration? {
        guard let fileHandleForReading = fileHandleForReading, let fileHandleForWriting = fileHandleForWriting else {
            return nil
        }
        let attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: fileHandleForReading, fileHandleForWriting: fileHandleForWriting)
        let serialConfig = VZVirtioConsoleDeviceSerialPortConfiguration()
        serialConfig.attachment = attachment
        return serialConfig
    }
}
