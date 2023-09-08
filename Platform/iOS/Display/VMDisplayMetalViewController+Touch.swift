//
// Copyright © 2023 osy. All rights reserved.
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

let kScrollSpeedReduction: CGFloat = 100.0
let kCursorResistance = 50.0
let kScrollResistance = 10.0

extension VMDisplayMetalViewController: UIGestureRecognizerDelegate {
    var mouseButtonDown: CSInputButton {
        var button = CSInputButton()
        if mouseLeftDown {
            button = CSInputButton(rawValue: button.rawValue | CSInputButton.left.rawValue)
        }
        if mouseRightDown {
            button = CSInputButton(rawValue: button.rawValue | CSInputButton.right.rawValue)
        }
        if mouseMiddleDown {
            button = CSInputButton(rawValue: button.rawValue | CSInputButton.middle.rawValue)
        }
        return button
    }
    
    var longPressType: VMGestureType {
        return gestureTypeForSetting("GestureLongPress")
    }
    
    var twoFingerTapType: VMGestureType {
        return gestureTypeForSetting("GestureTwoTap")
    }
    
    var twoFingerPanType: VMGestureType {
        return gestureTypeForSetting("GestureTwoPan")
    }
    
    var twoFingerScollType: VMGestureType {
        return gestureTypeForSetting("GestureTwoScroll")
    }
    
    var threeFingerPanType: VMGestureType {
        return gestureTypeForSetting("GestureThreePan")
    }
    
    var touchMouseType: VMMouseType {
        return mouseTypeForSetting("MouseTouchType")
    }
    
    var pencilMouseType: VMMouseType {
        return mouseTypeForSetting("MousePencilType")
    }
    
    var indirectMouseType: VMMouseType {
        if #available(iOS 14.0, *) {
            return .relative
        } else {
            // Legacy iOS 13.4 mouse handeling requires absolute
            return .absolute
        }
    }
    
    var isInvertScroll: Bool {
        return boolForSetting("InvertScroll")
    }
    
    init() {
        
    }
    
    public func gestureTypeForSetting(_ key: String) -> VMGestureType {
        var integer = integerForSetting(key)
        if integer < VMGestureType.none.rawValue || integer >= VMGestureType.max.rawValue {
            return .none
        } else {
            return VMGestureType(rawValue: integer)!
        }
    }
    
    public func mouseTypeForSetting(_ key: String) -> VMMouseType {
        var integer = integerForSetting(key)
        if integer < VMMouseType.relative.rawValue || integer >= VMMouseType.max.rawValue {
            return .relative
        } else {
            return VMMouseType(rawValue: integer)!
        }
    }
    
    public static func CGRectClipToBounds(_ rect1: CGRect, _ rect2: CGRect) -> CGRect {
        var rect2 = rect2
        if rect2.origin.x < rect1.origin.x {
            rect2.origin.x = rect1.origin.x
        } else if rect2.origin.x + rect2.size.width > rect1.origin.x + rect1.size.width {
            rect2.origin.x = rect1.origin.x + rect1.size.width - rect2.size.width
        }
        if rect2.origin.y < rect1.origin.y {
            rect2.origin.y = rect1.origin.y
        } else if rect2.origin.y + rect2.size.height > rect1.origin.y + rect1.size.height {
            rect2.origin.y = rect1.origin.y + rect1.size.height - rect2.size.height
        }
        return rect2
    }
    
    public func clipCursorToDisplay(_ pos: CGPoint) -> CGPoint {
        var pos = pos
        var screenSize = mtkView!.drawableSize
        var scaledSize = (
            width: vmDisplay.displaySize.width * vmDisplay.viewportScale,
            height: vmDisplay.displaySize.height * vmDisplay.viewportScale
        )
        var drawRect = CGRect(
            x: vmDisplay.viewportOrigin.x + screenSize.width / 2 - scaledSize.width / 2,
            y: vmDisplay.viewportOrigin.y + screenSize.height / 2 - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height)
        pos.x -= drawRect.origin.x
        pos.y -= drawRect.origin.y
        if pos.x < 0 {
            pos.x = 0
        } else if pos.x > scaledSize.width {
            pos.x = scaledSize.width
        }
        if pos.y < 0 {
            pos.y = 0
        } else if pos.y > scaledSize.height {
            pos.y = scaledSize.height
        }
        pos.x /= vmDisplay.viewportScale
        pos.y /= vmDisplay.viewportScale
        return pos
    }
    
    public func clipDisplayToView(_ target: CGPoint) -> CGPoint {
        var screenSize = mtkView!.drawableSize
        var scaledSize = (
            width: vmDisplay.displaySize.width * vmDisplay.viewportScale,
            height: vmDisplay.displaySize.height * vmDisplay.viewportScale
        )
        var drawRect = CGRect(
            x: target.x + screenSize.width / 2 - scaledSize.width / 2,
            y: target.y + screenSize.height / 2 - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height)
        var boundRect = CGRect(
            origin: CGPoint(
                x: screenSize.width - max(screenSize.width, scaledSize.width),
                y: screenSize.height - max(screenSize.height, scaledSize.height)
            ), size: CGSize(
                width: 2 * max(screenSize.width, scaledSize.width) - screenSize.width,
                height: 2 * max(screenSize.height, scaledSize.height) - screenSize.height
            ))
        var clippedRect = VMDisplayMetalViewController.CGRectClipToBounds(boundRect, drawRect)
    }
    
    public func moveMouseWithInertia(_ sender: UIPanGestureRecognizer) {
        var location = sender.location(in: sender.view)
        var velocity = sender.location(in: sender.view)
        if sender.state == .began {
            cursor.startMovement(location)
        }
        if sender.state != .cancelled {
            cursor.updateMovement(location)
        }
        if sender.state == .ended {
            cursor.endMovementWithVelocity(velocity, resistance: kCursorResistance)
        }
    }
    
    public func scrollWithInertia(_ sender: UIPanGestureRecognizer) {
        var location = sender.location(in: sender.view)
        var velocity = sender.location(in: sender.view)
        if sender.state == .began {
            scroll.startMovement(location)
        }
        if sender.state != .cancelled {
            scroll.updateMovement(location)
        }
        if sender.state == .ended {
            scroll.endMovementWithVelocity(velocity, resistance: kScrollResistance)
        }
    }
    
    @IBAction public func gesturePan(_ sender: UIPanGestureRecognizer) {
        // Otherwise we handle in touchesMoved
        if serverModeCursor {
            moveMouseWithInertia(sender)
        }
    }
    
    public func moveScreen(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            lastTwoPanOrigin = vmDisplay.viewportOrigin
        }
        if sender.state != .cancelled {
            var translation = sender.translation(in: sender.view)
            var viewport = vmDisplay.viewportOrigin
            viewport.x = CGPointToPixel(translation.x) + lastTwoPanOrigin.x
            viewport.y = CGPointToPixel(translation.y) + lastTwoPanOrigin.y
            vmDisplay.viewportOrigin = clipDisplayToView(viewport)
            // Persist this change in viewState
            delegate.displayOrigin = vmDisplay.viewportOrigin
        }
        if sender.state == .ended {
            // TODO: Decelerate
        }
    }
    
    @IBAction public func gestureTwoPan(_ sender: UIPanGestureRecognizer) {
        switch twoFingerPanType {
        case .moveScreen:
            moveScreen(sender)
            break
        case .dragCursor:
            dragCursor(sender.state, primary: true, secondary: false, middle: false)
            moveMouseWithInertia(sender)
            break
        case .mouseWheel:
            scrollWithInertia(sender)
            break
        default:
            break
        }
    }
    
    @IBAction public func gestureThreePan(_ sender: UIPanGestureRecognizer) {
        switch threeFingerPanType {
        case .moveScreen:
            moveScreen(sender)
            break
        case .dragCursor:
            dragCursor(sender.state, primary: true, secondary: false, middle: false)
            moveMouseWithInertia(sender)
            break
        case .mouseWheel:
            scrollWithInertia(sender)
            break
        default:
            break
        }
    }
    
    public func moveMouseAbosolute(_ location: CGPoint) -> CGPoint {
        var translated = location
        translated.x = CGPointToPixel(translated.x)
        translated.y = CGPointToPixel(translated.y)
        translated = clipCursorToDisplay(translated)
        if !vmInput!.serverModeCursor {
            vmInput!.sendMousePosition(mouseButtonDown, absolutePoint: translated)
            // Required to show cursor on screen
            vmInput!.cursor.moveTo(translated)
        } else {
            logger.warning("Ignored mouse set (\(translated.x), \(translated.y)) while mouse is in server mode")
        }
        return translated
    }
    
    public func moveMouseRelative(_ translation: CGPoint) -> CGPoint {
        
    }
    
    public func moveMouseScroll(_ translation: CGPoint) -> CGFloat {
        
    }
    
    public func mouseClick(button: CSInputButton, location: CGPoint) {
        
    }
    
    public func dragCursor(_ state: UIGestureRecognizer.State, primary: Bool, secondary: Bool, middle: Bool) {
        if state == .began {
            #if os(visionOS)
            clickFeedbackGenerator.selectionChanged()
            #endif
            if primary {
                mouseLeftDown = true
            }
            if secondary {
                mouseRightDown = true
            }
            if middle {
                mouseMiddleDown = true
            }
            vmInput!.sendMouseButton(mouseButtonDown, pressed: true)
        } else if state == .ended {
            mouseLeftDown = false
            mouseRightDown = false
            mouseMiddleDown = false
            vmInput!.sendMouseButton(mouseButtonDown, pressed: false)
        }
    }
}

enum VMGestureType: Int {
    case none
    case dragCursor
    case rightClick
    case moveScreen
    case mouseWheel
    case max
}

enum VMMouseType: Int {
    case relative
    case absolute
    case absoluteHideCursor
    case max
}
