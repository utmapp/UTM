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

#import "VMDisplayMetalViewController.h"
#import "VMDisplayMetalViewController+Private.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "VMDisplayMetalViewController+Pointer.h"
#import "VMCursor.h"
#import "CSDisplay.h"
#import "VMScroll.h"
#import "UTMLogging.h"
#import "UTM-Swift.h"

@interface VMDisplayMetalViewController ()

- (BOOL)switchMouseType:(VMMouseType)type; // defined in VMDisplayMetalViewController+Touch.m

@end

NS_AVAILABLE_IOS(13.4)
@implementation VMDisplayMetalViewController (Pointer)

#pragma mark - GCMouse

- (void)startGCMouse {
    if (@available(iOS 14.0, *)) {  //if ios 14.0 above, use CGMouse instead
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mouseDidBecomeCurrent:) name:GCMouseDidBecomeCurrentNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mouseDidStopBeingCurrent:) name:GCMouseDidStopBeingCurrentNotification object:nil];
        GCMouse *current = GCMouse.current;
        if (current) {
            // send the current mouse if already connected
            [NSNotificationCenter.defaultCenter postNotificationName:GCMouseDidBecomeCurrentNotification object:current];
        }
    }
}

- (void)stopGCMouse {
    GCMouse *current = GCMouse.current;
    [NSNotificationCenter.defaultCenter removeObserver:self name:GCMouseDidBecomeCurrentNotification object:nil];
    if (current) {
        // send the current mouse if already connected
        [NSNotificationCenter.defaultCenter postNotificationName:GCMouseDidStopBeingCurrentNotification object:current];
    }
    [NSNotificationCenter.defaultCenter removeObserver:self name:GCMouseDidStopBeingCurrentNotification object:nil];
}

- (void)mouseDidBecomeCurrent:(NSNotification *)notification API_AVAILABLE(ios(14)) {
    GCMouse *mouse = notification.object;
    UTMLog(@"mouseDidBecomeCurrent: %p", mouse);
    if (!mouse) {
        UTMLog(@"invalid mouse object!");
        return;
    }
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float deltaX, float deltaY) {
        [self switchMouseType:VMMouseTypeRelative];
        [self.vmInput sendMouseMotion:self.mouseButtonDown relativePoint:CGPointMake(deltaX, -deltaY)];
    };
    mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self.mouseLeftDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonLeft pressed:pressed];
    };
    mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self.mouseRightDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonRight pressed:pressed];

    };
    mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        self.mouseMiddleDown = pressed;
        [self.vmInput sendMouseButton:kCSInputButtonMiddle pressed:pressed];
    };
    for (int i = 0; i < MIN(4, mouse.mouseInput.auxiliaryButtons.count); i++) {
        mouse.mouseInput.auxiliaryButtons[i].pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            switch (i) {
                case 0: [self.vmInput sendMouseButton:kCSInputButtonUp pressed:pressed]; break;
                case 1: [self.vmInput sendMouseButton:kCSInputButtonDown pressed:pressed]; break;
                case 2: [self.vmInput sendMouseButton:kCSInputButtonSide pressed:pressed]; break;
                case 3: [self.vmInput sendMouseButton:kCSInputButtonExtra pressed:pressed]; break;
                default: break;
            }
        };
    }
    // no handler to the gcmouse scroll event, gestureScroll works fine.
}

- (void)mouseDidStopBeingCurrent:(NSNotification *)notification API_AVAILABLE(ios(14)) {
    GCMouse *mouse = notification.object;
    UTMLog(@"mouseDidStopBeingCurrent: %p", mouse);
    mouse.mouseInput.mouseMovedHandler = nil;
    mouse.mouseInput.leftButton.pressedChangedHandler = nil;
    mouse.mouseInput.rightButton.pressedChangedHandler = nil;
    mouse.mouseInput.middleButton.pressedChangedHandler = nil;
    for (int i = 0; i < MIN(4, mouse.mouseInput.auxiliaryButtons.count); i++) {
        mouse.mouseInput.auxiliaryButtons[i].pressedChangedHandler = nil;
    }
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
    return !self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor && self.indirectMouseType != VMMouseTypeRelative;
}

- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
    // Hide cursor while hovering in VM view
    if (interaction.view == self.mtkView && self.hasTouchpadPointer) {
#if TARGET_OS_VISION
        return nil; // FIXME: hidden pointer seems to jump around due to following gaze
#else
        return [UIPointerStyle hiddenPointerStyle];
#endif
    }
    return nil;
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
#if !TARGET_OS_VISION
    if (@available(iOS 14.0, *)) {
        if (self.prefersPointerLocked) {
            return nil;
        }
    }
#endif
    // Requesting region for the VM display?
    if (interaction.view == self.mtkView && self.hasTouchpadPointer) {
        // Then we need to find out if the pointer is in the actual display area or outside
        CGPoint location = [self.mtkView convertPoint:[request location] fromView:nil];
        CGPoint translated = location;
        translated.x = CGPointToPixel(translated.x);
        translated.y = CGPointToPixel(translated.y);
        
        if ([self isPointOnVMDisplay:translated]) {
            // move vm cursor, hide iOS cursor
            [self.cursor updateMovement:location];
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
