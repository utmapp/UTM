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

#import "VMCursor.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "CSDisplay.h"

@interface VMCursor ()

@property (nonatomic, readonly) CGFloat cursorSpeedMultiplier;

@end

@implementation VMCursor {
    CGPoint _start;
    CGPoint _lastCenter;
    CGPoint _center;
    __weak VMDisplayMetalViewController *_controller;
    UIDynamicAnimator *_animator;
}

@synthesize bounds;

@synthesize transform;


- (CGFloat)cursorSpeedMultiplier {
    NSInteger multiplier = [[NSUserDefaults standardUserDefaults] integerForKey:@"DragCursorSpeed"];
    CGFloat fraction = multiplier / 100.0f;
    if (fraction > 0) {
        return fraction;
    } else {
        return 1.0f;
    }
}

- (id)init {
    if (self = [super init]) {
        self.bounds = CGRectMake(0, 0, 1, 1);
        _animator = [[UIDynamicAnimator alloc] init];
    }
    return self;
}

- (id)initWithVMViewController:(VMDisplayMetalViewController *)controller {
    if (self = [self init]) {
        _controller = controller;
    }
    return self;
}

- (CGRect)bounds {
    CGRect bounds = CGRectZero;
    bounds.size.width = MAX(1, _controller.vmDisplay.cursor.cursorSize.width);
    bounds.size.height = MAX(1, _controller.vmDisplay.cursor.cursorSize.height);
    return bounds;
}

- (CGPoint)center {
    return _center;
}

- (void)setCenter:(CGPoint)center {
    if (_controller.serverModeCursor) {
        CGPoint diff = CGPointMake((center.x - _lastCenter.x) * self.cursorSpeedMultiplier,
                                   (center.y - _lastCenter.y) * self.cursorSpeedMultiplier);
        [_controller moveMouseRelative:diff];
    } else {
        [_controller moveMouseAbsolute:center];
    }
    _lastCenter = _center;
    _center = center;
}

- (void)startMovement:(CGPoint)startPoint {
    _start = startPoint;
    if (!_controller.serverModeCursor) {
        _lastCenter = startPoint;
        _center = startPoint;
    }
    [_animator removeAllBehaviors];
}

- (void)updateMovement:(CGPoint)point {
    if (_controller.serverModeCursor) {
        // translate point to relative to last center
        CGPoint adj = CGPointMake(point.x - _start.x, point.y - _start.y);
        _start = point;
        point = CGPointMake(self.center.x + adj.x, self.center.y + adj.y);
    }
    self.center = point;
}

- (void)endMovementWithVelocity:(CGPoint)velocity resistance:(CGFloat)resistance {
    UIDynamicItemBehavior *behavior = [[UIDynamicItemBehavior alloc] initWithItems:@[ self ]];
    [behavior addLinearVelocity:velocity forItem:self];
    behavior.resistance = resistance;
    [_animator addBehavior:behavior];
}

@end
