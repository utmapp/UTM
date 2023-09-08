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
import GameController

extension VMDisplayMetalViewController: UIPointerInteractionDelegate {
    var hasTouchpadPointer: Bool {
        return !delegate.qemuInputLegacy && !vmInput?.serverModeCursor && indirectMouseType != VMMouseType.relative
    }
    
    init() {
        mtkView?.addInteraction(UIPointerInteraction(delegate: self))
        
        if #available(iOS 13.4, *) {
            var scroll = UIPanGestureRecognizer(target: self, action: #selector(gestureScroll))
            scroll.allowedScrollTypesMask = UIScrollTypeMask.all
            scroll.minimumNumberOfTouches = 0
            scroll.maximumNumberOfTouches = 0
            mtkView?.addGestureRecognizer(scroll)
        }
    }
    
    public func startGCMouse() {
        // If iOS 14 or above, use CGMouse instead
        if #available(iOS 14.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(mouseDidBecomeCurrent), name: .GCMouseDidBecomeCurrent, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mouseDidStopBeingCurrent), name: .GCMouseDidStopBeingCurrent, object: nil)
            var current = GCMouse.current
            if current != nil {
                NotificationCenter.default.post(name: .GCMouseDidBecomeCurrent, object: current)
            }
        }
    }
    
    public func stopGCMouse() {
        var current = GCMouse.current
        NotificationCenter.default.removeObserver(self, name: .GCMouseDidBecomeCurrent, object: nil)
        if current != nil {
            NotificationCenter.default.post(name: .GCMouseDidStopBeingCurrent, object: current)
        }
        NotificationCenter.default.removeObserver(self, name: .GCMouseDidStopBeingCurrent, object: nil)
    }
    
    @available(iOS 14.0, *)
    @objc public func mouseDidBecomeCurrent(_ notification: NSNotification) {
        var mouse = notification.object as! GCMouse?
        logger.debug("mouseDidBecomeCurrent: \(String(describing: mouse))")
        if mouse == nil {
            logger.error("Invalid mouse object!")
            return
        }
        mouse!.mouseInput?.mouseMovedHandler = { mouse, deltaX, deltaY in
            switchMouseType(VMMouseType.Relative)
            vmInput?.sendMouseMotion(.down, relativePoint: CGPoint(x: deltaX, y: -deltaY))
        }
        mouse!.mouseInput?.leftButton.pressedChangedHandler = { button, value, pressed in
            mouseLeftDown = pressed
            vmInput?.sendMouseButton(.left, pressed: pressed)
        }
        mouse!.mouseInput?.rightButton?.pressedChangedHandler = { button, value, pressed in
            mouseRightDown = pressed
            vmInput?.sendMouseButton(.right, pressed: pressed)
        }
        mouse!.mouseInput?.middleButton?.pressedChangedHandler = { button, value, pressed in
            mouseMiddleDown = pressed
            vmInput?.sendMouseButton(.middle, pressed: pressed)
        }
        for i in 0...min(4, mouse?.mouseInput?.auxiliaryButtons?.count ?? 0) {
            mouse?.mouseInput?.auxiliaryButtons![i].pressedChangedHandler = { button, value, pressed in
                switch i {
                case 0:
                    self.vmInput?.sendMouseButton(.up, pressed: pressed)
                    break
                case 1:
                    self.vmInput?.sendMouseButton(.down, pressed: pressed)
                    break
                case 2:
                    self.vmInput?.sendMouseButton(.side, pressed: pressed)
                    break
                case 3:
                    self.vmInput?.sendMouseButton(.extra, pressed: pressed)
                    break
                default:
                    break
                }
            }
        }
        // No handler to the gcmouse scroll event, gestureScroll works fine.
    }
    
    public func isPointOnVMDisplay(pos: CGPoint) -> Bool {
        var pos = pos
        var screenSize = mtkView?.drawableSize
        var scaledSize = (
            width: self.vmDisplay.displaySize.width * self.vmDisplay.viewportScale,
            height: self.vmDisplay.displaySize.height * self.vmDisplay.viewportScale
        )
        var drawRect = CGRect(
            x: vmDisplay.viewportOrigin.x + screenSize!.width / 2,
            y: vmDisplay.viewportOrigin.y + screenSize!.height / 2,
            width: scaledSize.width,
            height: scaledSize.height)
        pos.x -= drawRect.origin.x
        pos.y -= drawRect.origin.y
        return 0 <= pos.x && pos.x <= scaledSize.width && 0 <= pos.y && pos.y <= scaledSize.height
    }
    
    @available(iOS 14.0, *)
    @objc public func mouseDidStopBeingCurrent(_ notification: NSNotification) {
        var mouse = notification.object as! GCMouse
        mouse.mouseInput?.mouseMovedHandler = nil
        mouse.mouseInput?.leftButton.pressedChangedHandler = nil
        mouse.mouseInput?.rightButton?.pressedChangedHandler = nil
        mouse.mouseInput?.middleButton?.pressedChangedHandler = nil
    }
    
    public func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        if #available(iOS 14.0, *) {
            if prefersPointerLocked {
                return nil
            }
        }
        // Requesting region for the VM display?
        if interaction.view == mtkView && hasTouchpadPointer {
            var location = mtkView!.convert(request.location, from: nil)
            var translated = location
            translated.x = CGPointToPixel(translated.x)
            translated.y = CGPointToPixel(translated.y)
            
            if isPointOnVMDisplay(translated) {
                // Move VM cursor, hide iOS cursor
                cursor.updateMovement(location)
                return UIPointerRegion(rect: mtkView?.bounds, identifier: "vm view")
            } else {
                // Don't move VM cursor, show iOS cursor
                return nil
            }
        } else {
            return nil
        }
    }
    
    @available(iOS 13.4, *)
    @IBAction @objc public func gestureScroll(sender: UIPanGestureRecognizer) {
        scroll(withInertia: sender)
    }
}
