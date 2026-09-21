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
@objc(UTMScriptingDeleteCommand)
class UTMScriptingDeleteCommand: NSDeleteCommand, UTMScriptable {
    override func performDefaultImplementation() -> Any? {
        // a specifier for something inside a virtual machine, such as one of its snapshots, can
        // be coerced into the virtual machine itself, and deleting that would throw away far
        // more than was asked for
        guard keySpecifier.key == "scriptingVirtualMachines" else {
            return super.performDefaultImplementation()
        }
        if let scriptingVM = keySpecifier.objectsByEvaluatingSpecifier as? UTMScriptingVirtualMachineImpl {
            scriptingVM.delete(self)
            return nil
        } else {
            return super.performDefaultImplementation()
        }
    }
}
