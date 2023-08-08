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
import SwiftUI

extension UTMData {
    func run(vm: VMData, options: UTMVirtualMachineStartOptions = []) {
        guard VMSessionState.currentSession == nil else {
            logger.error("Session already started")
            return
        }
        guard let wrapped = vm.wrapped else {
            return
        }
        let session = VMSessionState(for: wrapped as! UTMQemuVirtualMachine)
        session.start()
    }
    
    func stop(vm: VMData) {
        guard let wrapped = vm.wrapped else {
            return
        }
        if wrapped.registryEntry.hasSaveState {
            wrapped.requestVmDeleteState()
        }
    }
    
    func close(vm: VMData) {
        // do nothing
    }
    
    func tryClickAtPoint(point: CGPoint, button: CSInputButton) {
        if let vc = vmVC as? VMDisplayMetalViewController, let input = vc.vmInput {
            input.sendMouseButton(button, pressed: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                input.sendMouseButton(button, pressed: false)
            }
        }
    }
    
    func trySendTextSpice(_ text: String) {
        if let vc = vmVC as? VMDisplayMetalViewController {
            #if !os(visionOS) // FIXME: broken in visionOS
            vc.keyboardView.insertText(text)
            #endif
        } else if let vc = vmVC as? VMDisplayTerminalViewController {
            vc.vmSerialPort.write(text.data(using: .nonLossyASCII)!)
        }
    }
}
