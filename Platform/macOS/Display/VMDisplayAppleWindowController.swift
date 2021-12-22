//
// Copyright © 2021 osy. All rights reserved.
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

import Virtualization

@available(macOS 12, *)
class VMDisplayAppleWindowController: VMDisplayWindowController {
    var appleView: VZVirtualMachineView!
    
    var appleVM: UTMAppleVirtualMachine! {
        vm as? UTMAppleVirtualMachine
    }
    
    var appleConfig: UTMAppleConfiguration! {
        vmConfiguration as? UTMAppleConfiguration
    }
    
    override func windowDidLoad() {
        appleView = VZVirtualMachineView(frame: displayView.bounds)
        appleView.virtualMachine = appleVM.apple
        appleView.autoresizingMask = [.width, .height]
        displayView.addSubview(appleView)
        window!.recalculateKeyViewLoop()
        super.windowDidLoad()
    }
    
    override func enterLive() {
        drivesToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
        restartToolbarItem.isEnabled = false // FIXME: enable this
        resizeConsoleToolbarItem.isEnabled = false
        sharedFolderToolbarItem.isEnabled = false
        super.enterLive()
    }
}
