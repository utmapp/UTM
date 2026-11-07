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
import Carbon.HIToolbox

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

    /// The input of an Apple VM: through its display window, which must be open.
    @nonobjc @MainActor private var appleInput: UTMAppleInputProvider? {
        get throws {
            guard let appleVM = vm as? UTMAppleVirtualMachine else {
                return nil
            }
            guard vm.state == .started else {
                throw ScriptingError.notRunning
            }
            guard let input = appleVM.inputDelegate else {
                throw ScriptingError.operationNotAvailable
            }
            return input
        }
    }

    /// Press or release a key given by its PC scan code (set 1 make code, 0xE0xx for extended keys).
    @nonobjc @MainActor private func sendAppleScanCode(_ scanCode: Int, isDown: Bool, to input: UTMAppleInputProvider) throws {
        guard let keyCode = AppleKeyCodes.fromScanCode[scanCode] else {
            throw ScriptingError.invalidParameter
        }
        guard input.sendKey(keyCode, isDown: isDown) else {
            throw ScriptingError.operationNotAvailable
        }
    }

    @objc func sendScanCode(_ command: NSScriptCommand) {
        let scanCodes = command.evaluatedArguments?["codes"] as? [Int]
        withScriptCommand(command) { [self] in
            guard let scanCodes = scanCodes else {
                throw ScriptingError.invalidParameter
            }
            if let appleInput = try self.appleInput {
                for scanCode in scanCodes {
                    // a break code is the make code with 0x80 set (0xE0 prefix kept for extended keys)
                    let isExtended = (scanCode & 0xFF00) == 0xE000
                    let isDown = (scanCode & 0x80) == 0
                    let makeCode = (isExtended ? 0xE000 : 0) | (scanCode & 0x7F)
                    try sendAppleScanCode(makeCode, isDown: isDown, to: appleInput)
                    try await Task.sleep(nanoseconds: kDelayNs)
                }
                return
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
            if let appleInput = try self.appleInput {
                // the keyboard map calls back with make codes; replay them in order on this actor
                let recorded = RecordedKeys()
                let keyboardMap = VMKeyboardMap()
                await keyboardMap.mapText(keystrokes) { scanCode in
                    recorded.append(Int(scanCode), isDown: false)
                } keyDown: { scanCode in
                    recorded.append(Int(scanCode), isDown: true)
                }
                var pressed: [Int] = []
                do {
                    for modifier in modifiers {
                        let scanCode = Int(modifier.toSpiceKeyCode()).toScanCode
                        try sendAppleScanCode(scanCode, isDown: true, to: appleInput)
                        pressed.append(scanCode)
                        try await Task.sleep(nanoseconds: kDelayNs)
                    }
                    for (scanCode, isDown) in recorded.keys {
                        try sendAppleScanCode(scanCode, isDown: isDown, to: appleInput)
                        try await Task.sleep(nanoseconds: kDelayNs)
                    }
                } catch {
                    // don't leave modifiers held for the next command
                    for scanCode in pressed.reversed() {
                        try? sendAppleScanCode(scanCode, isDown: false, to: appleInput)
                    }
                    throw error
                }
                for scanCode in pressed.reversed() {
                    try sendAppleScanCode(scanCode, isDown: false, to: appleInput)
                    try await Task.sleep(nanoseconds: kDelayNs)
                }
                return
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
            if let appleInput = try self.appleInput {
                guard monitorNumber == 1 else {
                    throw ScriptingError.invalidParameter
                }
                let button = switch mouseButton {
                case .left: 0
                case .right: 1
                case .middle: 2
                }
                guard appleInput.sendMouseClick(at: CGPoint(x: xPosition, y: yPosition), button: button) else {
                    throw ScriptingError.operationNotAvailable
                }
                return
            }
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

// MARK: - Display capture
@objc extension UTMScriptingVirtualMachineImpl {
    @objc func captureScreen(_ command: NSScriptCommand) {
        let file = command.evaluatedArguments?["file"] as? URL
        withScriptCommand(command) { [self] in
            guard let file = file else {
                throw ScriptingError.invalidParameter
            }
            guard vm.state == .started else {
                throw ScriptingError.notRunning
            }
            // an Apple VM can only take a screenshot from its open window
            if let appleVM = vm as? UTMAppleVirtualMachine, appleVM.screenshotDelegate == nil {
                throw ScriptingError.operationNotAvailable
            }
            // the previous screenshot stays in place when capturing fails: never save that one
            let previous = vm.screenshot?.image
            guard await vm.takeScreenshot(), let screenshot = vm.screenshot, screenshot.image !== previous, let pngData = screenshot.pngData else {
                throw ScriptingError.operationNotAvailable
            }
            _ = file.startAccessingSecurityScopedResource()
            defer {
                file.stopAccessingSecurityScopedResource()
            }
            try pngData.write(to: file)
        }
    }
}

// MARK: - Apple VM key codes

/// Key events recorded from the keyboard map's callbacks, which may run on any thread.
private final class RecordedKeys: @unchecked Sendable {
    private let lock = NSLock()
    private var _keys: [(Int, Bool)] = []

    func append(_ scanCode: Int, isDown: Bool) {
        lock.lock()
        _keys.append((scanCode, isDown))
        lock.unlock()
    }

    var keys: [(Int, Bool)] {
        lock.lock()
        defer { lock.unlock() }
        return _keys
    }
}

private extension Int {
    /// A SPICE key code (extended keys as 0x1xx) as a scan code (0xE0xx).
    var toScanCode: Int {
        (self & 0x100) != 0 ? 0xE000 | (self & 0xFF) : self
    }
}

private enum AppleKeyCodes {
    /// PC scan codes (set 1 make codes) to macOS virtual key codes, the reverse of the display's own map
    static let fromScanCode: [Int: UInt16] = {
        var map: [Int: UInt16] = [:]
        for (keyCode, scanCodes) in KeyCodeMap.keyCodeToScanCodes {
            // the first key wins where two share a scan code
            if map[Int(scanCodes.down)] == nil || keyCode < Int(map[Int(scanCodes.down)]!) {
                map[Int(scanCodes.down)] = UInt16(keyCode)
            }
        }
        return map
    }()
}
