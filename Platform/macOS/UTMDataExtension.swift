//
// Copyright © 2020 osy. All rights reserved.
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

@available(macOS 11, *)
extension UTMData {
    func run(vm: UTMVirtualMachine) {
        var window: VMDisplayWindowController? = vmWindows[vm]
        if window == nil {
            let close = { (notification: Notification) -> Void in
                self.vmWindows.removeValue(forKey: vm)
                window = nil
            }
            if vm.configuration.displayConsoleOnly {
                window = VMDisplayTerminalWindowController(vm: vm, onClose: close)
            } else {
                window = VMDisplayMetalWindowController(vm: vm, onClose: close)
            }
        }
        if let unwrappedWindow = window {
            vmWindows[vm] = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
        } else {
            logger.critical("Failed to create window controller.")
        }
    }
    
    func stop(vm: UTMVirtualMachine) throws {
        if let window = vmWindows[vm] {
            window.close()
        } else if vm.viewState.suspended {
            guard vm.deleteSaveVM() else {
                throw NSLocalizedString("Failed to delete saved state.", comment: "UTMDataExtension")
            }
        } else {
            throw NSLocalizedString("VM is not suspended or active.", comment: "UTMDataExtension")
        }
    }
}
