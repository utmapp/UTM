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
import Carbon.HIToolbox

@available(macOS 11, *)
extension UTMData {
    func run(vm: UTMVirtualMachine) {
        var window: VMDisplayWindowController? = vmWindows[vm]
        if window == nil {
            let close = { (notification: Notification) -> Void in
                self.vmWindows.removeValue(forKey: vm)
                window = nil
            }
            if let avm = vm as? UTMAppleVirtualMachine {
                if avm.appleConfig.architecture == UTMAppleVirtualMachine.currentArchitecture {
                    window = VMDisplayAppleWindowController(vm: avm, onClose: close)
                }
            }
            if let qvm = vm as? UTMQemuVirtualMachine {
                if qvm.qemuConfig.displayConsoleOnly {
                    window = VMDisplayTerminalWindowController(vm: qvm, onClose: close)
                } else {
                    window = VMDisplayMetalWindowController(vm: qvm, onClose: close)
                }
            }
            if window == nil {
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(NSLocalizedString("This virtual machine cannot be run on this machine.", comment: "UTMDataExtension"))
                }
            }
        }
        if let unwrappedWindow = window {
            vmWindows[vm] = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
            unwrappedWindow.requestAutoStart()
        } else {
            logger.critical("Failed to create window controller.")
        }
    }
    
    func stop(vm: UTMVirtualMachine) throws {
        if vm.viewState.suspended {
            vm.requestVmDeleteState()
        }
        vm.requestVmStop(force: true)
        if let window = vmWindows[vm] {
            DispatchQueue.main.async {
                window.close()
            }
        }
    }
    
    func trySendTextSpice(vm: UTMQemuVirtualMachine, text: String) {
        guard text.count > 0 else { return }
        if let vc = vmWindows[vm] as? VMDisplayMetalWindowController {
            KeyCodeMap.createKeyMapIfNeeded()
            
            func sleep() {
                Thread.sleep(forTimeInterval: 0.05)
            }
            func keyDown(keyCode: Int) {
                if let scanCodes = KeyCodeMap.keyCodeToScanCodes[keyCode] {
                    vc.keyDown(scanCode: Int(scanCodes.down))
                    sleep()
                }
            }
            func keyUp(keyCode: Int) {
                /// Due to how Spice works we need to send keyUp for the .down scan code
                /// instead of sending the key down for the scan code that indicates key up.
                if let scanCodes = KeyCodeMap.keyCodeToScanCodes[keyCode] {
                    vc.keyUp(scanCode: Int(scanCodes.down))
                    sleep()
                }
            }
            func press(keyCode: Int) {
                keyDown(keyCode: keyCode)
                keyUp(keyCode: keyCode)
            }
            
            func simulateKeyPress(_ keyCodeDict: [String: Int]) {
                /// Press modifier keys if necessary
                let optionUsed = keyCodeDict["option"] == 1
                if optionUsed {
                    keyDown(keyCode: kVK_Option)
                    sleep()
                }
                let shiftUsed = keyCodeDict["shift"] == 1
                if shiftUsed {
                    keyDown(keyCode: kVK_Shift)
                    sleep()
                }
                let fnUsed = keyCodeDict["function"] == 1
                if fnUsed {
                    keyDown(keyCode: kVK_Function)
                    sleep()
                }
                let ctrlUsed = keyCodeDict["control"] == 1
                if ctrlUsed {
                    keyDown(keyCode: kVK_Control)
                    sleep()
                }
                let cmdUsed = keyCodeDict["command"] == 1
                if cmdUsed {
                    keyDown(keyCode: kVK_Command)
                    sleep()
                }
                /// Press the key now
                let keyCode = keyCodeDict["virtKeyCode"]!
                press(keyCode: keyCode)
                /// Release modifiers
                if optionUsed {
                    keyUp(keyCode: kVK_Option)
                    sleep()
                }
                if shiftUsed {
                    keyUp(keyCode: kVK_Shift)
                    sleep()
                }
                if fnUsed {
                    keyUp(keyCode: kVK_Function)
                    sleep()
                }
                if ctrlUsed {
                    keyUp(keyCode: kVK_Control)
                    sleep()
                }
                if cmdUsed {
                    keyUp(keyCode: kVK_Command)
                    sleep()
                }
            }
            DispatchQueue.global(qos: .userInitiated).async {
                text.enumerated().forEach { stringItem in
                    let char = stringItem.element
                    /// drop unknown chars
                    if let keyCodeDict = KeyCodeMap.characterToKeyCode(character: char) {
                        simulateKeyPress(keyCodeDict)
                    } else {
                        logger.warning("SendText dropping unknown char: \(char)")
                    }
                }
            }
        }
    }
    
    func tryClickAtPoint(vm: UTMQemuVirtualMachine, point: CGPoint, button: CSInputButton) {
        if let vc = vmWindows[vm] as? VMDisplayMetalWindowController {
            vc.mouseMove(absolutePoint: point, button: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                vc.mouseDown(button: button)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    vc.mouseUp(button: button)
                }
            }
        }
    }
}
