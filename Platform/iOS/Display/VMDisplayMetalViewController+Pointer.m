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

#import "UTMConfiguration.h"
#import "UTMConfiguration+Miscellaneous.h"
#import "VMDisplayMetalViewController.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "VMDisplayMetalViewController+Pointer.h"
#import "VMCursor.h"
#import "CSDisplayMetal.h"
#import "VMScroll.h"
#import "UTMVirtualMachine.h"
#import "UTMVirtualMachine+SPICE.h"
#import "UTMLogging.h"

NS_AVAILABLE_IOS(13.4)
@implementation VMDisplayMetalViewController (Pointer)

// Add pointer interaction to VM view
-(void)initPointerInteraction {
    [self.mtkView addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
    
    if (@available(iOS 13.4, *)) {
        UIPanGestureRecognizer *scroll = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureScroll:)];
        scroll.allowedScrollTypesMask = UIScrollTypeMaskAll;
        scroll.minimumNumberOfTouches = 0;
        scroll.maximumNumberOfTouches = 0;
        [self.mtkView addGestureRecognizer:scroll];
    }
}

- (BOOL)switchMouseType:(VMMouseType)type {
    BOOL shouldUseServerMouse = YES;
    self.vmInput.inhibitCursor = NO;
    if (shouldUseServerMouse != self.vmInput.serverModeCursor) {
        UTMLog(@"Switching mouse mode to server:%d for type:%ld", shouldUseServerMouse, type);
        [self.vm requestInputTablet:!shouldUseServerMouse];
        return YES;
    }
    return NO;
}

- (void) initGCMouse {
    if (@available(iOS 14.0, *)) {  //if ios 14.0 above, use CGMouse instead
        GCMouse *mouse = GCMouse.current;
        __weak typeof(self) _self = self;
        VMDisplayMetalViewController *s = _self;
        mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float deltaX, float deltaY) {
            [self switchMouseType:VMMouseTypeRelative];
            [self.vmInput sendMouseMotion:self.mouseButtonDown point:CGPointMake(deltaX, -deltaY)];
        };
        mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            s->_mouseLeftDown = pressed;
            [s.vmInput sendMouseButton:kCSInputButtonLeft pressed:pressed point:CGPointZero];
        };

        mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            s->_mouseRightDown = pressed;
            [s.vmInput sendMouseButton:kCSInputButtonRight pressed:pressed point:CGPointZero];

        };

        mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            s->_mouseMiddleDown = pressed;
            [s.vmInput sendMouseButton:kCSInputButtonMiddle pressed:pressed point:CGPointZero];

        };
        
        // no handler to the gcmouse scroll event, gestureScroll works fine.
    }
}

- (BOOL) prefersPointerLocked {
    if (self.indirectMouseType == VMMouseTypeAbsolute || self.indirectMouseType == VMMouseTypeAbsoluteHideCursor) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)hasTouchpadPointer {
    return !self.vmConfiguration.inputLegacy && !self.vmInput.serverModeCursor && self.indirectMouseType != VMMouseTypeRelative;
}

#pragma mark - UIPointerInteractionDelegate
- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
    // Hide cursor while hovering in VM view
    if (interaction.view == self.mtkView && self.hasTouchpadPointer) {
        return [UIPointerStyle hiddenPointerStyle];
    }
    return nil;
}

static CGFloat CGPointToPixel(CGFloat point) {
    return point * [UIScreen mainScreen].scale; // FIXME: multiple screens?
}

- (bool)isPointOnVMDisplay:(CGPoint)pos {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmDisplay.displaySize.width * self.vmDisplay.viewportScale,
        self.vmDisplay.displaySize.height * self.vmDisplay.viewportScale
    };
    CGRect drawRect = CGRectMake(
        self.vmDisplay.viewportOrigin.x + screenSize.width/2 - scaledSize.width/2,
        self.vmDisplay.viewportOrigin.y + screenSize.height/2 - scaledSize.height/2,
        scaledSize.width,
        scaledSize.height
    );
    pos.x -= drawRect.origin.x;
    pos.y -= drawRect.origin.y;
    return 0 <= pos.x && pos.x <= scaledSize.width && 0 <= pos.y && pos.y <= scaledSize.height;
}


- (UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction regionForRequest:(UIPointerRegionRequest *)request defaultRegion:(UIPointerRegion *)defaultRegion {
    if (@available(iOS 14.0, *)) {
        if (self.prefersPointerLocked) {
            return nil;
        }
    }
    // Requesting region for the VM display?
    if (interaction.view == self.mtkView && self.hasTouchpadPointer) {
        // Then we need to find out if the pointer is in the actual display area or outside
        CGPoint location = [self.mtkView convertPoint:[request location] fromView:nil];
        CGPoint translated = location;
        translated.x = CGPointToPixel(translated.x);
        translated.y = CGPointToPixel(translated.y);
        
        if ([self isPointOnVMDisplay:translated]) {
            // move vm cursor, hide iOS cursor
            [_cursor updateMovement:location];
            return [UIPointerRegion regionWithRect:[self.mtkView bounds] identifier:@"vm view"];
        } else {
            // don't move vm cursor, show iOS cursor
            return nil;
        }
    } else {
        return nil;
    }
}

#pragma mark - Scroll Gesture

- (IBAction)gestureScroll:(UIPanGestureRecognizer *)sender API_AVAILABLE(ios(13.4)) {
    [self scrollWithInertia:sender];
}

@end
