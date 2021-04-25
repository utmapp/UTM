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

import Carbon.HIToolbox

private let macVkToScancode = [
    kVK_ANSI_A: 0x1E,
    kVK_ANSI_S: 0x1F,
    kVK_ANSI_D: 0x20,
    kVK_ANSI_F: 0x21,
    kVK_ANSI_H: 0x23,
    kVK_ANSI_G: 0x22,
    kVK_ANSI_Z: 0x2C,
    kVK_ANSI_X: 0x2D,
    kVK_ANSI_C: 0x2E,
    kVK_ANSI_V: 0x2F,
    kVK_ANSI_B: 0x30,
    kVK_ANSI_Q: 0x10,
    kVK_ANSI_W: 0x11,
    kVK_ANSI_E: 0x12,
    kVK_ANSI_R: 0x13,
    kVK_ANSI_Y: 0x15,
    kVK_ANSI_T: 0x14,
    kVK_ANSI_1: 0x02,
    kVK_ANSI_2: 0x03,
    kVK_ANSI_3: 0x04,
    kVK_ANSI_4: 0x05,
    kVK_ANSI_6: 0x07,
    kVK_ANSI_5: 0x06,
    kVK_ANSI_Equal: 0x0D,
    kVK_ANSI_9: 0x0A,
    kVK_ANSI_7: 0x08,
    kVK_ANSI_Minus: 0x0C,
    kVK_ANSI_8: 0x09,
    kVK_ANSI_0: 0x0B,
    kVK_ANSI_RightBracket: 0x1B,
    kVK_ANSI_O: 0x18,
    kVK_ANSI_U: 0x16,
    kVK_ANSI_LeftBracket: 0x1A,
    kVK_ANSI_I: 0x17,
    kVK_ANSI_P: 0x19,
    kVK_ANSI_L: 0x26,
    kVK_ANSI_J: 0x24,
    kVK_ANSI_Quote: 0x28,
    kVK_ANSI_K: 0x25,
    kVK_ANSI_Semicolon: 0x27,
    kVK_ANSI_Backslash: 0x2B,
    kVK_ANSI_Comma: 0x33,
    kVK_ANSI_Slash: 0x35,
    kVK_ANSI_N: 0x31,
    kVK_ANSI_M: 0x32,
    kVK_ANSI_Period: 0x34,
    kVK_ANSI_Grave: 0x29,
    kVK_ANSI_KeypadDecimal: 0x53,
    kVK_ANSI_KeypadMultiply: 0x37,
    kVK_ANSI_KeypadPlus: 0x4E,
    kVK_ANSI_KeypadClear: 0x45,
    kVK_ANSI_KeypadDivide: 0xE035,
    kVK_ANSI_KeypadEnter: 0xE01C,
    kVK_ANSI_KeypadMinus: 0x4A,
    kVK_ANSI_KeypadEquals: 0x59,
    kVK_ANSI_Keypad0: 0x52,
    kVK_ANSI_Keypad1: 0x4F,
    kVK_ANSI_Keypad2: 0x50,
    kVK_ANSI_Keypad3: 0x51,
    kVK_ANSI_Keypad4: 0x4B,
    kVK_ANSI_Keypad5: 0x4C,
    kVK_ANSI_Keypad6: 0x4D,
    kVK_ANSI_Keypad7: 0x47,
    kVK_ANSI_Keypad8: 0x48,
    kVK_ANSI_Keypad9: 0x49,
    kVK_Return: 0x1C,
    kVK_Tab: 0x0F,
    kVK_Space: 0x39,
    kVK_Delete: 0x0E,
    kVK_Escape: 0x01,
    kVK_Command: 0xE05B,
    kVK_Shift: 0x2A,
    kVK_CapsLock: 0x3A,
    kVK_Option: 0x38,
    kVK_Control: 0x1D,
    kVK_RightCommand: 0xE05C,
    kVK_RightShift: 0x36,
    kVK_RightOption: 0xE038,
    kVK_RightControl: 0xE01D,
    kVK_Function: 0x00,
    kVK_F17: 0x68,
    kVK_VolumeUp: 0xE030,
    kVK_VolumeDown: 0xE02E,
    kVK_Mute: 0xE020,
    kVK_F18: 0x69,
    kVK_F19: 0x6A,
    kVK_F20: 0x6B,
    kVK_F5: 0x3F,
    kVK_F6: 0x40,
    kVK_F7: 0x41,
    kVK_F3: 0x3D,
    kVK_F8: 0x42,
    kVK_F9: 0x43,
    kVK_F11: 0x57,
    kVK_F13: 0x64,
    kVK_F16: 0x67,
    kVK_F14: 0x65,
    kVK_F10: 0x44,
    kVK_F12: 0x58,
    kVK_F15: 0x66,
    kVK_Help: 0x00,
    kVK_Home: 0xE047,
    kVK_PageUp: 0xE049,
    kVK_ForwardDelete: 0xE053,
    kVK_F4: 0x3E,
    kVK_End: 0xE04F,
    kVK_F2: 0x3C,
    kVK_PageDown: 0xE051,
    kVK_F1: 0x3B,
    kVK_LeftArrow: 0xE04B,
    kVK_RightArrow: 0xE04D,
    kVK_DownArrow: 0xE050,
    kVK_UpArrow: 0xE048,
    kVK_ISO_Section: 0x00,
    kVK_JIS_Yen: 0x7D,
    kVK_JIS_Underscore: 0x73,
    kVK_JIS_KeypadComma: 0x5C,
    kVK_JIS_Eisu: 0x73,
    kVK_JIS_Kana: 0x70,
]

class VMMetalView: MTKView {
    weak var inputDelegate: VMMetalViewInputDelegate?
    private var wholeTrackingArea: NSTrackingArea?
    private var lastModifiers = NSEvent.ModifierFlags()
    private(set) var isMouseCaptured = false
    
    override var acceptsFirstResponder: Bool { true }
    
    override func updateTrackingAreas() {
        logger.debug("update tracking area")
        let trackingArea = NSTrackingArea(rect: CGRect(origin: .zero, size: frame.size), options: [.mouseMoved, .mouseEnteredAndExited, .activeWhenFirstResponder], owner: self, userInfo: nil)
        if let oldTrackingArea = wholeTrackingArea {
            removeTrackingArea(oldTrackingArea)
            NSCursor.unhide()
        }
        wholeTrackingArea = trackingArea
        addTrackingArea(trackingArea)
        super.updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
        logger.debug("mouse entered")
        NSCursor.hide()
    }
    
    override func mouseExited(with event: NSEvent) {
        logger.debug("mouse exited")
        NSCursor.unhide()
    }
    
    override func mouseDown(with event: NSEvent) {
        logger.debug("mouse down: \(event.buttonNumber)")
        inputDelegate?.mouseDown(button: .left)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        logger.debug("right mouse down: \(event.buttonNumber)")
        inputDelegate?.mouseDown(button: .right)
    }
    
    override func mouseUp(with event: NSEvent) {
        logger.debug("mouse up: \(event.buttonNumber)")
        inputDelegate?.mouseUp(button: .left)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        logger.debug("right mouse up: \(event.buttonNumber)")
        inputDelegate?.mouseUp(button: .right)
    }
    
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        logger.debug("key down: \(event.keyCode)")
        inputDelegate?.keyDown(keyCode: macVkToScancode[Int(event.keyCode)] ?? 0)
    }
    
    override func keyUp(with event: NSEvent) {
        logger.debug("key up: \(event.keyCode)")
        inputDelegate?.keyUp(keyCode: macVkToScancode[Int(event.keyCode)] ?? 0)
    }
    
    override func flagsChanged(with event: NSEvent) {
        let modifiers = event.modifierFlags
        logger.debug("modifers: \(modifiers)")
        if modifiers.isSuperset(of: [.option, .control]) {
            logger.debug("release cursor")
            inputDelegate?.requestReleaseCapture()
        }
        sendModifiers(lastModifiers.subtracting(modifiers), press: false)
        sendModifiers(modifiers.subtracting(lastModifiers), press: true)
        lastModifiers = modifiers
    }
    
    private func sendModifiers(_ modifier: NSEvent.ModifierFlags, press: Bool) {
        if modifier.contains(.capsLock) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_CapsLock]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_CapsLock]!)
            }
        }
        if modifier.contains(.command) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Command]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Command]!)
            }
        }
        if modifier.contains(.control) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Control]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Control]!)
            }
        }
        if modifier.contains(.function) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Function]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Function]!)
            }
        }
        if modifier.contains(.help) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Help]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Help]!)
            }
        }
        if modifier.contains(.option) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Option]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Option]!)
            }
        }
        if modifier.contains(.shift) {
            if press {
                inputDelegate?.keyDown(keyCode: macVkToScancode[kVK_Shift]!)
            } else {
                inputDelegate?.keyUp(keyCode: macVkToScancode[kVK_Shift]!)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }
    
    override func otherMouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        logger.debug("mouse moved: \(event.deltaX), \(event.deltaY)")
        if isMouseCaptured {
            inputDelegate?.mouseMove(relativePoint: CGPoint(x: event.deltaX, y: -event.deltaY),
                                     button: NSEvent.pressedMouseButtons.inputButtons())
        } else {
            let location = event.locationInWindow
            let converted = convert(location, from: nil)
            inputDelegate?.mouseMove(absolutePoint: converted,
                                     button: NSEvent.pressedMouseButtons.inputButtons())
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard event.scrollingDeltaY != 0 else { return }
        logger.debug("scroll: \(event.scrollingDeltaY)")
        inputDelegate?.mouseScroll(dy: event.scrollingDeltaY,
                                   button: NSEvent.pressedMouseButtons.inputButtons())
    }
}

extension VMMetalView {
    private var screenCenter: CGPoint? {
        guard let window = self.window else { return nil }
        guard let screen = window.screen else { return nil }
        let centerView = CGPoint(x: frame.size.width / 2, y: frame.size.height / 2)
        let centerWindow = convert(centerView, to: nil)
        var centerScreen = window.convertPoint(toScreen: centerWindow)
        let screenHeight = screen.frame.height
        centerScreen.y = screenHeight - centerScreen.y
        logger.debug("screen \(centerScreen.x), \(centerScreen.y)")
        return centerScreen
    }
    
    func captureMouse() {
        CGAssociateMouseAndMouseCursorPosition(0)
        CGWarpMouseCursorPosition(screenCenter ?? .zero)
        isMouseCaptured = true
        NSCursor.hide()
    }
    
    func releaseMouse() {
        CGAssociateMouseAndMouseCursorPosition(1)
        isMouseCaptured = false
        NSCursor.unhide()
    }
}

private extension Int {
    func inputButtons() -> CSInputButton {
        var pressed = CSInputButton()
        if self & (1 << 0) != 0 {
            pressed.formUnion(.left)
        }
        if self & (1 << 1) != 0 {
            pressed.formUnion(.right)
        }
        if self & (1 << 2) != 0 {
            pressed.formUnion(.middle)
        }
        return pressed
    }
}
