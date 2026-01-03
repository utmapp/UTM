//
// Copyright © 2025 osy. All rights reserved.
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

import AppIntents

private let kDelayNs: UInt64 = 20000000

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMSendScanCodeIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Send Scan Code"
    static let description = IntentDescription("Send a sequence of raw keyboard scan codes to the virtual machine. Only supported on QEMU backend.")
    static var parameterSummary: some ParameterSummary {
        Summary("Send scan code to \(\.$vmEntity)") {
            \.$scanCodes
        }
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "Scan Code", description: "List of PC AT scan codes in decimal (0-65535 inclusive).", controlStyle: .field, inclusiveRange: (0, 0xFFFF))
    var scanCodes: [Int]

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        guard let vm = vm as? any UTMSpiceVirtualMachine else {
            throw UTMIntentError.unsupportedBackend
        }
        guard let input = vm.ioService?.primaryInput else {
            throw UTMIntentError.inputHandlerNotAvailable
        }
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
        return .result()
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMSendKeystrokesIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Send Keystrokes"
    static let description = IntentDescription("Send text as a sequence of keystrokes to the virtual machine. Only supported on QEMU backend.")
    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$keystrokes) to \(\.$vmEntity)") {
            \.$modifiers
        }
    }

    enum Modifier: Int, CaseIterable, AppEnum {
        case capsLock
        case shift
        case control
        case option
        case command
        case escape

        static let typeDisplayRepresentation: TypeDisplayRepresentation =
            TypeDisplayRepresentation(
                name: "Modifier Key"
            )

        static let caseDisplayRepresentations: [Modifier: DisplayRepresentation] = [
            .capsLock: DisplayRepresentation(title: "Caps Lock (⇪)"),
            .shift: DisplayRepresentation(title: "Shift (⇧)"),
            .control: DisplayRepresentation(title: "Control (⌃)"),
            .option: DisplayRepresentation(title: "Option (⌥)"),
            .command: DisplayRepresentation(title: "Command (⌘)"),
            .escape: DisplayRepresentation(title: "Escape (⎋)"),
        ]

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

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "Keystrokes", description: "Text will be converted to a sequence of keystrokes.")
    var keystrokes: String

    @Parameter(title: "Modifiers", description: "The modifier keys will be held down while the keystroke sequence is sent.", default: [])
    var modifiers: [Modifier]

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        guard let vm = vm as? any UTMSpiceVirtualMachine else {
            throw UTMIntentError.unsupportedBackend
        }
        guard let input = vm.ioService?.primaryInput else {
            throw UTMIntentError.inputHandlerNotAvailable
        }
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
        return .result()
    }

    private func scanCodeToSpice(_ scanCode: Int) -> Int32 {
        var keyCode = scanCode
        if (keyCode & 0xFF00) == 0xE000 {
            keyCode = (keyCode & 0xFF) | 0x100
        }
        return Int32(keyCode)
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMMouseClickIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Send Mouse Click"
    static let description = IntentDescription("Send a mouse position and click to the virtual machine. Only supported on QEMU backend.")
    static var parameterSummary: some ParameterSummary {
        Summary("Send mouse click at (\(\.$xPosition), \(\.$yPosition)) to \(\.$vmEntity)") {
            \.$mouseButton
            \.$monitorNumber
        }
    }

    enum MouseButton: Int, CaseIterable, AppEnum {
        case left
        case right
        case middle

        static let typeDisplayRepresentation: TypeDisplayRepresentation =
            TypeDisplayRepresentation(
                name: "Mouse Button"
            )

        static let caseDisplayRepresentations: [MouseButton: DisplayRepresentation] = [
            .left: DisplayRepresentation(title: "Left"),
            .right: DisplayRepresentation(title: "Right"),
            .middle: DisplayRepresentation(title: "Middle"),
        ]

        func toSpiceButton() -> CSInputButton {
            switch self {
            case .left: return .left
            case .right: return .right
            case .middle: return .middle
            }
        }
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "X Position", description: "X coordinate of the absolute position.", default: 0, controlStyle: .field)
    var xPosition: Int

    @Parameter(title: "Y Position", description: "Y coordinate of the absolute position.", default: 0, controlStyle: .field)
    var yPosition: Int

    @Parameter(title: "Mouse Button", description: "Mouse button to click.", default: .left)
    var mouseButton: MouseButton

    @Parameter(title: "Monitor Number", description: "Which monitor to target (starting at 1).", default: 1, controlStyle: .stepper)
    var monitorNumber: Int

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        guard let vm = vm as? UTMQemuVirtualMachine else {
            throw UTMIntentError.unsupportedBackend
        }
        guard let input = vm.ioService?.primaryInput else {
            throw UTMIntentError.inputHandlerNotAvailable
        }
        try await vm.changeInputTablet(true)
        input.sendMousePosition(mouseButton.toSpiceButton(), absolutePoint: CGPoint(x: xPosition, y: yPosition), forMonitorID: monitorNumber-1)
        try await Task.sleep(nanoseconds: kDelayNs)
        input.sendMouseButton(mouseButton.toSpiceButton(), mask: [], pressed: true)
        try await Task.sleep(nanoseconds: kDelayNs)
        input.sendMouseButton(mouseButton.toSpiceButton(), mask: [], pressed: false)
        return .result()
    }
}
