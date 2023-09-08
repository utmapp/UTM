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

class VMCursor: NSObject, UIDynamicItem {
    var bounds: CGRect
    var transform: CGAffineTransform
    private var _start: CGPoint = CGPoint()
    private var _lastCenter: CGPoint = CGPoint()
    private var _center: CGPoint = CGPoint()
    private var _controller: VMDisplayMetalViewController = VMDisplayMetalViewController()
    private var _animator: UIDynamicAnimator
    
    public var center: CGPoint {
        get {
            return _center
        }
        set {
            if _controller.serverModeCursor {
                var diff = CGPoint(x: (newValue.x - _lastCenter.x) * cursorSpeedMultiplier, y: (newValue.y - _lastCenter.y) * cursorSpeedMultiplier)
                _controller.moveMouseRelative(diff)
            } else {
                _controller.moveMouseAbsolute(newValue)
            }
            _lastCenter = _center
            _center = newValue
        }
    }
    
    public var cursorSpeedMultiplier: CGFloat {
        var multiplier = UserDefaults.standard.integer(forKey: "DragCursorSpeed")
        var fraction = CGFloat(multiplier) / 100.0
        if fraction > 0 {
            return fraction
        } else {
            return 1.0
        }
    }
    
    override init() {
        super.init()
        bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        _animator = UIDynamicAnimator()
    }
    
    init(_ controller: VMDisplayMetalViewController) {
        super.init()
        _controller = controller
    }
        
    public func startMovement(_ startPoint: CGPoint) {
        _start = startPoint
        if !_controller.serverModeCursor {
            _lastCenter = startPoint
            _center = startPoint
        }
        _animator.removeAllBehaviors()
    }
    
    public func updateMovement(_ point: CGPoint) {
        if !_controller.serverModeCursor {
            // Translate point to relative to last center
            var adj = CGPoint(x: point.x - _start.x, y: point.y - _start.y)
            _start = point
            var point = CGPoint(x: center.x + adj.x, y: center.y + adj.y)
        }
        center = point
    }
    
    public func endMovementWithVelocity(_ velocity: CGPoint, resistance: CGFloat) {
        var behavior = UIDynamicItemBehavior(items: [self])
        behavior.addLinearVelocity(velocity, for: self)
        behavior.resistance = resistance
        _animator.addBehavior(behavior)
    }
}
