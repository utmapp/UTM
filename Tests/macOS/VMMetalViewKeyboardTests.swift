//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

import XCTest
import Carbon.HIToolbox
@testable import UTM

/// While a key is held, macOS sends repeated key-down events. A guest on QEMU's PS/2
/// keyboard (DOS, Windows 9x/XP) gets no repeat unless these reach it as more presses,
/// because QEMU's PS/2 keyboard has no typematic repeat of its own.
@MainActor
final class VMMetalViewKeyboardTests: XCTestCase {
    private final class RecordingInputDelegate: VMMetalViewInputDelegate {
        var keyDowns: [Int] = []
        var keyUps: [Int] = []

        var shouldUseCmdOptForCapture: Bool { false }
        func mouseMove(absolutePoint: CGPoint, buttonMask: CSInputButton) {}
        func mouseMove(relativePoint: CGPoint, buttonMask: CSInputButton) {}
        func mouseDown(button: CSInputButton, mask: CSInputButton) {}
        func mouseUp(button: CSInputButton, mask: CSInputButton) {}
        func mouseScroll(dy: CGFloat, buttonMask: CSInputButton) {}
        func keyDown(scanCode: Int) { keyDowns.append(scanCode) }
        func keyUp(scanCode: Int) { keyUps.append(scanCode) }
        func syncCapsLock(with modifier: NSEvent.ModifierFlags?) {}
        func captureMouse() {}
        func releaseMouse() {}
        func didUseNumericPad() {}
    }

    private func keyEvent(_ type: NSEvent.EventType, keyCode: Int, isARepeat: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: type,
                         location: .zero,
                         modifierFlags: [],
                         timestamp: ProcessInfo.processInfo.systemUptime,
                         windowNumber: 0,
                         context: nil,
                         characters: "a",
                         charactersIgnoringModifiers: "a",
                         isARepeat: isARepeat,
                         keyCode: UInt16(keyCode))!
    }

    func testHeldKeyRepeatsReachTheGuest() {
        let view = VMMetalView(frame: .zero, device: nil)
        let delegate = RecordingInputDelegate()
        view.inputDelegate = delegate
        let scanCodeA = Int(KeyCodeMap.keyCodeToScanCodes[kVK_ANSI_A]!.down)

        view.keyDown(with: keyEvent(.keyDown, keyCode: kVK_ANSI_A))
        for _ in 0..<3 {
            view.keyDown(with: keyEvent(.keyDown, keyCode: kVK_ANSI_A, isARepeat: true))
        }
        view.keyUp(with: keyEvent(.keyUp, keyCode: kVK_ANSI_A))

        XCTAssertEqual(delegate.keyDowns, Array(repeating: scanCodeA, count: 4),
                       "the first press and each of the 3 repeats should be sent as a press")
        XCTAssertEqual(delegate.keyUps, [scanCodeA])
    }
}
