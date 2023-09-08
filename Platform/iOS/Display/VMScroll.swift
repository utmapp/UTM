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

class VMScroll: NSObject, UIDynamicItem {
    private var _start: CGPoint
    private var _lastCenter: CGPoint
    private var _center: CGPoint
    private var _controller: VMDisplayMetalViewController
    private var _animator: UIDynamicAnimator
    var center: CGPoint {
        get {
            return _center
        }
        set {
            var diff = CGPointMake(center.x - _lastCenter.x, center.y - _lastCenter.y)
            _controller.moveMouseScroll(diff)
            _lastCenter = _center
            _center = newValue
        }
    }
    var bounds: CGRect
    var transform: CGAffineTransform
    
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
        _animator.removeAllBehaviors()
    }
    
    public func updateMovement(_ point: CGPoint) {
        // Translate point to relative to last center
        var adj = CGPoint(x: point.x - _start.x, y: point.y - _start.y)
        _start = point
        center = CGPoint(x: center.x + adj.x, y: center.y + adj.y)
    }
    
    public func endMovementWithVelocity(_ velocity: CGPoint, resistance: CGFloat) {
        var behavior = UIDynamicItemBehavior(items: [self])
        behavior.addLinearVelocity(velocity, for: self)
        behavior.resistance = resistance
        _animator.addBehavior(behavior)
    }
}
