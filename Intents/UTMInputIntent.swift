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
struct UTMSendScanCodeIntent: UTMIntent {
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
struct UTMMouseClickIntent: UTMIntent {
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
        input.sendMouseButton(mouseButton.toSpiceButton(), pressed: true)
        try await Task.sleep(nanoseconds: kDelayNs)
        input.sendMouseButton(mouseButton.toSpiceButton(), pressed: false)
        return .result()
    }
}
