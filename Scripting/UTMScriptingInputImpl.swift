//
// Copyright © 2025 Turing Software, LLC. All rights reserved.
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
import CocoaSpice

private let kDelayNs: UInt64 = 20000000

@objc extension UTMScriptingVirtualMachineImpl {
    @nonobjc private var primaryInput: CSInput {
        get throws {
            guard vm.state == .started else {
                throw ScriptingError.notRunning
            }
            guard let ioService = (vm as? any UTMSpiceVirtualMachine)?.ioService else {
                throw ScriptingError.operationNotSupported
            }
            guard let input = ioService.primaryInput else {
                throw ScriptingError.operationNotAvailable
            }
            return input
        }
    }

    @objc func sendScanCode(_ command: NSScriptCommand) {
        let scanCodes = command.evaluatedArguments?["codes"] as? [Int]
        withScriptCommand(command) { [self] in
            guard let scanCodes = scanCodes else {
                throw ScriptingError.invalidParameter
            }
            let input = try self.primaryInput
            for scanCode in scanCodes {
                var _scanCode = scanCode
                if (_scanCode & 0xFF00) == 0xE000 {
                    _scanCode = 0x100 | (_scanCode & 0xFF)
                }
                if (_scanCode & 0x80) == 0x80 {
                    input.send(.release, code: Int32(_scanCode & 0x17F))
                } else {
                    input.send(.press, code: Int32(_scanCode))
                }
                try await Task.sleep(nanoseconds: kDelayNs)
            }
        }
    }

    @objc func sendKeystroke(_ command: NSScriptCommand) {
        let keystrokes = command.evaluatedArguments?["keystrokes"] as? String
        let _modifiers = command.evaluatedArguments?["modifiers"] as? [AEKeyword] ?? []
        let modifiers = _modifiers.compactMap({ UTMScriptingModifierKey(rawValue: $0) })
        withScriptCommand(command) { [self] in
            func scanCodeToSpice(_ scanCode: Int) -> Int32 {
                var keyCode = scanCode
                if (keyCode & 0xFF00) == 0xE000 {
                    keyCode = (keyCode & 0xFF) | 0x100
                }
                return Int32(keyCode)
            }

            guard let keystrokes = keystrokes else {
                throw ScriptingError.invalidParameter
            }
            let input = try self.primaryInput
            for modifier in modifiers {
                input.send(.press, code: modifier.toSpiceKeyCode())
                try await Task.sleep(nanoseconds: kDelayNs)
            }
            let keyboardMap = VMKeyboardMap()
            await keyboardMap.mapText(keystrokes) { scanCode in
                input.send(.release, code: scanCodeToSpice(scanCode))
            } keyDown: { scanCode in
                input.send(.press, code: scanCodeToSpice(scanCode))
            }
            try await Task.sleep(nanoseconds: kDelayNs)
            for modifier in modifiers {
                input.send(.release, code: modifier.toSpiceKeyCode())
                try await Task.sleep(nanoseconds: kDelayNs)
            }
        }
    }

    @objc func sendMouseClick(_ command: NSScriptCommand) {
        let coordinate = command.evaluatedArguments?["coordinate"] as? [Int]
        let _mouseButton = command.evaluatedArguments?["button"] as? AEKeyword ?? UTMScriptingMouseButton.left.rawValue
        let mouseButton = UTMScriptingMouseButton(rawValue: _mouseButton) ?? .left
        let monitorNumber = command.evaluatedArguments?["monitor"] as? Int ?? 1
        withScriptCommand(command) { [self] in
            guard let coordinate = coordinate, coordinate.count == 2 else {
                throw ScriptingError.invalidParameter
            }
            let xPosition = coordinate[0]
            let yPosition = coordinate[1]
            let input = try self.primaryInput
            try await (vm as! UTMQemuVirtualMachine).changeInputTablet(true)
            input.sendMousePosition(mouseButton.toSpiceButton(), absolutePoint: CGPoint(x: xPosition, y: yPosition), forMonitorID: monitorNumber-1)
            try await Task.sleep(nanoseconds: kDelayNs)
            input.sendMouseButton(mouseButton.toSpiceButton(), mask: [], pressed: true)
            try await Task.sleep(nanoseconds: kDelayNs)
            input.sendMouseButton(mouseButton.toSpiceButton(), mask: [], pressed: false)
        }
    }
}

private extension UTMScriptingModifierKey {
    func toSpiceKeyCode() -> Int32 {
        switch self {
        case .capsLock: return 0x3a
        case .shift: return 0x2a
        case .control: return 0x1d
        case .option: return 0x38
        case .command: return 0x15b
        case .escape: return 0x01
        }
    }
}

private extension UTMScriptingMouseButton {
    func toSpiceButton() -> CSInputButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .middle
        }
    }
}
