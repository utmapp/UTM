//
// Copyright © 2023 osy. All rights reserved.
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
@objc(UTMScriptingGuestProcessImpl)
class UTMScriptingGuestProcessImpl: NSObject, UTMScriptable {
    @objc private(set) var id: Int
    
    private var parent: UTMScriptingVirtualMachineImpl
    
    init(from pid: Int, parent: UTMScriptingVirtualMachineImpl) {
        self.id = pid
        self.parent = parent
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let parentDescription = parent.classDescription as? NSScriptClassDescription else {
            return nil
        }
        let parentSpecifier = parent.objectSpecifier
        return NSUniqueIDSpecifier(containerClassDescription: parentDescription,
                                   containerSpecifier: parentSpecifier,
                                   key: "processes",
                                   uniqueID: id)
    }
    
    @objc func getResult(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            guard let guestAgent = await parent.guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            let status = try await guestAgent.guestExecStatus(id)
            return [
                "hasExited": status.hasExited,
                "exitCode": status.exitCode,
                "signalCode": status.signal,
                "outputText": textFromData(status.outData) ?? "",
                "outputData": textFromData(status.outData, isBase64Encoded: true) ?? "",
                "errorText": textFromData(status.errData) ?? "",
                "errorData": textFromData(status.errData, isBase64Encoded: true) ?? "",
            ]
        }
    }
}
