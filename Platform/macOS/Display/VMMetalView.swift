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

class VMMetalView: MTKView {
    weak var inputDelegate: VMMetalViewInputDelegate?
    private var wholeTrackingArea: NSTrackingArea?
    private var lastModifiers = NSEvent.ModifierFlags()
    private var lastKeyDown: Int?
    private(set) var isMouseCaptured = false
    private(set) var isFirstResponder = false
    private(set) var isMouseInWindow = false
    
    /// Returns the scan code for the key code in the `event`, or `0` if scan code is unknown.
    private func getScanCodeForEvent(_ event: NSEvent) -> Int {
        if event.type == .keyDown || event.type == .keyUp {
            /// see KeyCodeMap file for explaination why the .down scan code is used for both key down and up
            return Int(KeyCodeMap.keyCodeToScanCodes[Int(event.keyCode)]?.down ?? 0)
        } else {
            return 0
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        isFirstResponder = true
        if isMouseInWindow {
            NSCursor.hide()
        }
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        isFirstResponder = false
        if let lastKeyDown = lastKeyDown {
            inputDelegate?.keyUp(scanCode: lastKeyDown)
        }
        return super.resignFirstResponder()
    }
    
    override func updateTrackingAreas() {
        let trackingArea = NSTrackingArea(rect: CGRect(origin: .zero, size: frame.size), options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        logger.debug("update tracking area: \(trackingArea.rect)")
        if let oldTrackingArea = wholeTrackingArea {
            logger.debug("remove old tracking area: \(oldTrackingArea.rect)")
            removeTrackingArea(oldTrackingArea)
            NSCursor.unhide()
        }
        wholeTrackingArea = trackingArea
        addTrackingArea(trackingArea)
        super.updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
        logger.debug("mouse entered (first responder: \(isFirstResponder))")
        isMouseInWindow = true
        if isFirstResponder {
            NSCursor.hide()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        logger.debug("mouse exited")
        isMouseInWindow = false
        NSCursor.unhide()
    }
    
    override func mouseDown(with event: NSEvent) {
        logger.trace("mouse down: \(event.buttonNumber)")
        inputDelegate?.mouseDown(button: .left)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        logger.trace("right mouse down: \(event.buttonNumber)")
        inputDelegate?.mouseDown(button: .right)
    }
    
    override func mouseUp(with event: NSEvent) {
        logger.trace("mouse up: \(event.buttonNumber)")
        inputDelegate?.mouseUp(button: .left)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        logger.trace("right mouse up: \(event.buttonNumber)")
        inputDelegate?.mouseUp(button: .right)
    }
    
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        logger.trace("key down: \(event.keyCode)")
        lastKeyDown = getScanCodeForEvent(event)
        inputDelegate?.keyDown(scanCode: lastKeyDown!)
        if !isMouseCaptured {
            super.keyDown(with: event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        logger.trace("key up: \(event.keyCode)")
        lastKeyDown = nil
        inputDelegate?.keyUp(scanCode: getScanCodeForEvent(event))
        if !isMouseCaptured {
            super.keyUp(with: event)
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        let modifiers = event.modifierFlags
        logger.trace("modifers: \(modifiers)")
        if let shouldUseCmdOptForCapture = inputDelegate?.shouldUseCmdOptForCapture {
            let captureKeyPressed: Bool
            if shouldUseCmdOptForCapture {
                captureKeyPressed = modifiers.isSuperset(of: [.command, .option])
            } else {
                captureKeyPressed = modifiers.isSuperset(of: [.control, .option])
            }
            if captureKeyPressed {
                if isMouseCaptured {
                    inputDelegate!.releaseMouse()
                } else {
                    inputDelegate!.captureMouse()
                }
            }
        }
        sendModifiers(lastModifiers.subtracting(modifiers), press: false)
        sendModifiers(modifiers.subtracting(lastModifiers), press: true)
        lastModifiers = modifiers
        if !isMouseCaptured {
            super.flagsChanged(with: event)
        }
    }
    
    private func sendModifiers(_ modifier: NSEvent.ModifierFlags, press: Bool) {
        if modifier.contains(.capsLock) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_CapsLock]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
            }
        }
        if modifier.contains(.command) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_Command]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
            }
        }
        if modifier.contains(.control) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_Control]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
            }
        }
        if modifier.contains(.function) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_Function]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
            }
        }
        if modifier.contains(.option) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_Option]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
            }
        }
        if modifier.contains(.shift) {
            let sc = Int(KeyCodeMap.keyCodeToScanCodes[kVK_Shift]!.down)
            if press {
                inputDelegate?.keyDown(scanCode: sc)
            } else {
                inputDelegate?.keyUp(scanCode: sc)
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
        logger.trace("mouse moved: \(event.deltaX), \(event.deltaY)")
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
        guard event.deltaY != 0 else { return }
        logger.trace("scroll: \(event.deltaY)")
        inputDelegate?.mouseScroll(dy: event.deltaY,
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
        logger.trace("capture cursor")
        CGAssociateMouseAndMouseCursorPosition(0)
        CGWarpMouseCursorPosition(screenCenter ?? .zero)
        isMouseCaptured = true
        NSCursor.hide()
        CGSSetGlobalHotKeyOperatingMode(CGSMainConnectionID(), .disable)
    }
    
    func releaseMouse() {
        logger.trace("release cursor")
        CGAssociateMouseAndMouseCursorPosition(1)
        isMouseCaptured = false
        NSCursor.unhide()
        CGSSetGlobalHotKeyOperatingMode(CGSMainConnectionID(), .enable)
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
