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
        guard vm.deleteSaveVM() else {
            throw NSLocalizedString("Failed to delete saved state.", comment: "UTMDataExtension")
        }
        if let window = vmWindows[vm] {
            DispatchQueue.main.async {
                window.close()
            }
        }
    }
    
    func trySendTextSpice(vm: UTMVirtualMachine, text: String) {
        guard text.count > 0 else { return }
        if let vc = vmWindows[vm] as? VMDisplayMetalWindowController {
            func sleep() {
                Thread.sleep(forTimeInterval: 0.05)
            }
            func press(keyCode: UInt16) {
                vc.keyDown(keyCode: Int(keyCode))
                sleep()
                vc.keyUp(keyCode: Int(keyCode))
                sleep()
            }
            func simulateKeyPress(_ keyCodeDict: [String: UInt16]) {
                /// Press modifier keys if necessary
                let optionUsed = keyCodeDict["option"] == 1
                if optionUsed {
                    vc.keyDown(keyCode: kVK_Option)
                    sleep()
                }
                let shiftUsed = keyCodeDict["shift"] == 1
                if shiftUsed {
                    vc.keyDown(keyCode: kVK_Shift)
                    sleep()
                }
                let fnUsed = keyCodeDict["function"] == 1
                if fnUsed {
                    vc.keyDown(keyCode: kVK_Function)
                    sleep()
                }
                let ctrlUsed = keyCodeDict["control"] == 1
                if ctrlUsed {
                    vc.keyDown(keyCode: kVK_Control)
                    sleep()
                }
                let cmdUsed = keyCodeDict["command"] == 1
                if cmdUsed {
                    vc.keyDown(keyCode: kVK_Command)
                    sleep()
                }
                /// Press the key now
                let actualKeyCode = keyCodeDict["virtKeyCode"]!
                press(keyCode: actualKeyCode)
                /// Release modifiers
                if optionUsed {
                    vc.keyUp(keyCode: kVK_Option)
                    sleep()
                }
                if shiftUsed {
                    vc.keyUp(keyCode: kVK_Shift)
                    sleep()
                }
                if fnUsed {
                    vc.keyUp(keyCode: kVK_Function)
                    sleep()
                }
                if ctrlUsed {
                    vc.keyUp(keyCode: kVK_Control)
                    sleep()
                }
                if cmdUsed {
                    vc.keyUp(keyCode: kVK_Command)
                    sleep()
                }
            }
            UTF8ToKeyCode.createKeyMapIfNeeded()
            DispatchQueue.global(qos: .userInitiated).async {
                text.enumerated().forEach { stringItem in
                    let char = stringItem.element
                    let keyCodeDict = UTF8ToKeyCode.characterToKeyCode(character: char)
                    simulateKeyPress(keyCodeDict)
                }
            }
        }
    }
    
    func tryClickAtPoint(vm: UTMVirtualMachine, point: CGPoint, button: CSInputButton) {
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
