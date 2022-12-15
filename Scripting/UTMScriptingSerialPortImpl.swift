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

@MainActor
@objc(UTMScriptingSerialPortImpl)
class UTMScriptingSerialPortImpl: NSObject {
    @objc private(set) var id: Int
    @objc private(set) weak var parent: UTMScriptingVirtualMachineImpl?
    @objc private(set) var interface: UTMScriptingSerialInterface
    @objc private(set) var address: String
    @objc private(set) var port: Int
    
    init(qemuSerial: UTMQemuConfigurationSerial, parent: UTMScriptingVirtualMachineImpl, index: Int) {
        self.id = index
        self.parent = parent
        switch qemuSerial.mode {
        case .ptty:
            if let path = qemuSerial.pttyDevice?.path {
                self.interface = .ptty
                self.address = path
                self.port = 0
                return
            }
        case .tcpServer:
            if let port = qemuSerial.tcpPort {
                self.interface = .tcp
                self.address = qemuSerial.tcpHostAddress ?? "127.0.0.1"
                self.port = port
                return
            }
        default:
            break
        }
        self.interface = .unavailable
        self.address = ""
        self.port = 0
    }
    
    init(appleSerial: UTMAppleConfigurationSerial, parent: UTMScriptingVirtualMachineImpl, index: Int) {
        self.id = index
        self.parent = parent
        if appleSerial.mode == .ptty, let path = appleSerial.interface?.name {
            self.interface = .ptty
            self.address = path
            self.port = 0
        } else {
            self.interface = .unavailable
            self.address = ""
            self.port = 0
        }
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let parent = parent else {
            return nil
        }
        guard let parentDescription = parent.classDescription as? NSScriptClassDescription else {
            return nil
        }
        let parentSpecifier = parent.objectSpecifier
        return NSUniqueIDSpecifier(containerClassDescription: parentDescription,
                                   containerSpecifier: parentSpecifier,
                                   key: "serialPorts",
                                   uniqueID: id)
    }
}
