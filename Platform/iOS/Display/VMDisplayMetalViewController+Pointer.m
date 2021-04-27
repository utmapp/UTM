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

@interface VMDisplayMetalViewController ()

- (BOOL)switchMouseType:(VMMouseType)type; // defined in VMDisplayMetalViewController+Touch.m

@end

NS_AVAILABLE_IOS(13.4)
@implementation VMDisplayMetalViewController (Pointer)

#pragma mark - GCMouse

- (void)initGCMouse {
    if (@available(iOS 14.0, *)) {  //if ios 14.0 above, use CGMouse instead
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mouseDidBecomeCurrent:) name:GCMouseDidBecomeCurrentNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mouseDidStopBeingCurrent:) name:GCMouseDidStopBeingCurrentNotification object:nil];
    }
}

- (BOOL)prefersPointerLocked {
    return _mouseCaptured;
}

- (void)mouseDidBecomeCurrent:(NSNotification *)notification API_AVAILABLE(ios(14)) {
    GCMouse *mouse = notification.object;
    UTMLog(@"mouseDidBecomeCurrent: %p", mouse);
    if (!mouse) {
        UTMLog(@"invalid mouse object!");
        return;
    }
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float deltaX, float deltaY) {
        [self.vmInput sendMouseMotion:self.mouseButtonDown point:CGPointMake(deltaX, -deltaY)];
    };
    mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self->_mouseLeftDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonLeft pressed:pressed point:CGPointZero];
    };
    mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self->_mouseRightDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonRight pressed:pressed point:CGPointZero];

    };
    mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self->_mouseMiddleDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonMiddle pressed:pressed point:CGPointZero];
    };
    // no handler to the gcmouse scroll event, gestureScroll works fine.
    [self switchMouseType:VMMouseTypeRelative];
    _mouseCaptured = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsUpdateOfPrefersPointerLocked];
    });
}

- (void)mouseDidStopBeingCurrent:(NSNotification *)notification API_AVAILABLE(ios(14)) {
    GCMouse *mouse = notification.object;
    UTMLog(@"mouseDidStopBeingCurrent: %p", mouse);
    mouse.mouseInput.mouseMovedHandler = nil;
    mouse.mouseInput.leftButton.pressedChangedHandler = nil;
    mouse.mouseInput.rightButton.pressedChangedHandler = nil;
    mouse.mouseInput.middleButton.pressedChangedHandler = nil;
    _mouseCaptured = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsUpdateOfPrefersPointerLocked];
    });
}

#pragma mark - UIPointerInteractionDelegate

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

- (BOOL)hasTouchpadPointer {
    return !self.vmConfiguration.inputLegacy && !self.vmInput.serverModeCursor && self.indirectMouseType != VMMouseTypeRelative;
}

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
