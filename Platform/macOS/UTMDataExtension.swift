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
    func run(vm: VMData, options: UTMVirtualMachineStartOptions = [], startImmediately: Bool = true) {
        var window: Any? = vmWindows[vm]
        if window == nil {
            let close = {
                self.vmWindows.removeValue(forKey: vm)
                window = nil
            }
            if let avm = vm.wrapped as? UTMAppleVirtualMachine {
                if avm.config.system.architecture == UTMAppleConfigurationSystem.currentArchitecture {
                    let primarySerialIndex = avm.config.serials.firstIndex { $0.mode == .builtin }
                    if let primarySerialIndex = primarySerialIndex {
                        window = VMDisplayAppleTerminalWindowController(primaryForIndex: primarySerialIndex, vm: avm, onClose: close)
                    }
                    if #available(macOS 12, *), !avm.config.displays.isEmpty {
                        window = VMDisplayAppleDisplayWindowController(vm: avm, onClose: close)
                    } else if avm.config.displays.isEmpty && window == nil {
                        window = VMHeadlessSessionState(for: avm, onStop: close)
                    }
                }
            }
            if let qvm = vm.wrapped as? UTMQemuVirtualMachine {
                if !qvm.config.displays.isEmpty {
                    window = VMDisplayQemuMetalWindowController(vm: qvm, onClose: close)
                } else if !qvm.config.serials.filter({ $0.mode == .builtin }).isEmpty {
                    window = VMDisplayQemuTerminalWindowController(vm: qvm, onClose: close)
                } else {
                    window = VMHeadlessSessionState(for: qvm, onStop: close)
                }
            }
            if window == nil {
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(NSLocalizedString("This virtual machine cannot be run on this machine.", comment: "UTMDataExtension"))
                }
            }
        }
        if let unwrappedWindow = window as? VMDisplayWindowController {
            vmWindows[vm] = unwrappedWindow
            vm.wrapped!.delegate = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
            if startImmediately {
                unwrappedWindow.requestAutoStart(options: options)
            }
        } else if let unwrappedWindow = window as? VMHeadlessSessionState {
            vmWindows[vm] = unwrappedWindow
            if startImmediately {
                if vm.wrapped!.state == .paused {
                    vm.wrapped!.requestVmResume()
                } else {
                    vm.wrapped!.requestVmStart(options: options)
                }
            }
        } else {
            logger.critical("Failed to create window controller.")
        }
    }
    
    /// Start a remote session and return SPICE server port.
    /// - Parameters:
    ///   - vm: VM to start
    ///   - options: Start options
    ///   - server: Remote server
    /// - Returns: Port number to SPICE server
    func startRemote(vm: VMData, options: UTMVirtualMachineStartOptions, forClient client: UTMRemoteServer.Remote) async throws -> UInt16 {
        guard let wrapped = vm.wrapped as? UTMQemuVirtualMachine, type(of: wrapped).capabilities.supportsRemoteSession else {
            throw UTMDataError.unsupportedBackend
        }
        guard vmWindows[vm] == nil else {
            throw UTMDataError.virtualMachineUnavailable
        }
        let session = VMRemoteSessionState(for: wrapped, client: client) {
            self.vmWindows.removeValue(forKey: vm)
        }
        try await wrapped.start(options: options.union(.remoteSession))
        vmWindows[vm] = session
        return wrapped.config.qemu.spiceServerPort!
    }

    func stop(vm: VMData) {
        guard let wrapped = vm.wrapped else {
            return
        }
        Task {
            if wrapped.registryEntry.isSuspended {
                try? await wrapped.deleteSnapshot(name: nil)
            }
            try? await wrapped.stop(usingMethod: .force)
            await MainActor.run {
                self.close(vm: vm)
            }
        }
    }
    
    func close(vm: VMData) {
        if let window = vmWindows.removeValue(forKey: vm) as? VMDisplayWindowController {
            DispatchQueue.main.async {
                window.close()
            }
        }
    }
    
    func trySendTextSpice(vm: VMData, text: String) {
        guard text.count > 0 else { return }
        if let vc = vmWindows[vm] as? VMDisplayQemuMetalWindowController {
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
        } else if let terminal = vmWindows[vm] as? VMDisplayTerminal {
            terminal.sendString(text)
        }
    }
    
    func tryClickAtPoint(vm: VMData, point: CGPoint, button: CSInputButton) {
        if let vc = vmWindows[vm] as? VMDisplayQemuMetalWindowController {
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
