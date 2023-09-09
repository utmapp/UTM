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
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
#import "VMDisplayMetalViewController+Pencil.h"
#endif
#import "VMCursor.h"
#import "VMScroll.h"
#import "CSDisplay.h"
#import "UTM-Swift.h"

@implementation VMDisplayMetalViewController (Gestures)

- (void)initTouch {
    // mouse cursor
    self.cursor = [[VMCursor alloc] initWithVMViewController:self];
    self.scroll = [[VMScroll alloc] initWithVMViewController:self];
    
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    // we only support pan and tap on visionOS
    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePan:)];
    self.pan.minimumNumberOfTouches = 1;
    self.pan.maximumNumberOfTouches = 1;
    self.pan.delegate = self;
    self.pan.cancelsTouchesInView = NO;
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    self.tap.delegate = self;
    self.tap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.tap.cancelsTouchesInView = NO;
    [self.mtkView addGestureRecognizer:self.pan];
    [self.mtkView addGestureRecognizer:self.tap];
#else
    // Set up gesture recognizers because Storyboards is BROKEN and doing it there crashes!
    self.swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeUp:)];
    self.swipeUp.numberOfTouchesRequired = 3;
    self.swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    self.swipeUp.delegate = self;
    self.swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeDown:)];
    self.swipeDown.numberOfTouchesRequired = 3;
    self.swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    self.swipeDown.delegate = self;
    self.swipeScrollUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    self.swipeScrollUp.numberOfTouchesRequired = 2;
    self.swipeScrollUp.direction = UISwipeGestureRecognizerDirectionUp;
    self.swipeScrollUp.delegate = self;
    self.swipeScrollDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    self.swipeScrollDown.numberOfTouchesRequired = 2;
    self.swipeScrollDown.direction = UISwipeGestureRecognizerDirectionDown;
    self.swipeScrollDown.delegate = self;
    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePan:)];
    self.pan.minimumNumberOfTouches = 1;
    self.pan.maximumNumberOfTouches = 1;
    self.pan.delegate = self;
    self.pan.cancelsTouchesInView = NO;
    self.twoPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoPan:)];
    self.twoPan.minimumNumberOfTouches = 2;
    self.twoPan.maximumNumberOfTouches = 2;
    self.twoPan.delegate = self;
    self.threePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureThreePan:)];
    self.threePan.minimumNumberOfTouches = 3;
    self.threePan.maximumNumberOfTouches = 3;
    self.threePan.delegate = self;
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    self.tap.delegate = self;
    self.tap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.tap.cancelsTouchesInView = NO;
    self.twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoTap:)];
    self.twoTap.numberOfTouchesRequired = 2;
    self.twoTap.delegate = self;
    self.twoTap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(gestureLongPress:)];
    self.longPress.delegate = self;
    self.longPress.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    self.pinch.delegate = self;
    [self.mtkView addGestureRecognizer:self.swipeUp];
    [self.mtkView addGestureRecognizer:self.swipeDown];
    [self.mtkView addGestureRecognizer:self.swipeScrollUp];
    [self.mtkView addGestureRecognizer:self.swipeScrollDown];
    [self.mtkView addGestureRecognizer:self.pan];
    [self.mtkView addGestureRecognizer:self.twoPan];
    [self.mtkView addGestureRecognizer:self.threePan];
    [self.mtkView addGestureRecognizer:self.tap];
    [self.mtkView addGestureRecognizer:self.twoTap];
    [self.mtkView addGestureRecognizer:self.longPress];
    [self.mtkView addGestureRecognizer:self.pinch];
    
    // Feedback generator for clicks
    self.clickFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
#endif
}

#pragma mark - Touch type

- (VMMouseType)touchTypeToMouseType:(UITouchType)type {
    switch (type) {
        case UITouchTypeDirect: {
            return self.touchMouseType;
        }
        case UITouchTypePencil: {
            return self.pencilMouseType;
        }
        case UITouchTypeIndirect: {
            return self.indirectMouseType;
        }
        default: {
            if (@available(iOS 13.4, *)) {
                if (type == UITouchTypeIndirectPointer) {
                    return self.indirectMouseType;
                }
            }
            return self.touchMouseType; // compatibility with future values
        }
    }
}

- (BOOL)switchMouseType:(VMMouseType)type {
    BOOL shouldHideCursor = (type == VMMouseTypeAbsoluteHideCursor);
    BOOL shouldUseServerMouse = (type == VMMouseTypeRelative);
    self.vmDisplay.cursor.isInhibited = shouldHideCursor;
    if (shouldUseServerMouse != self.vmInput.serverModeCursor) {
        // UTMLog(@"Switching mouse mode to server:%d for type:%ld", shouldUseServerMouse, type);
        [self.delegate requestInputTablet:!shouldUseServerMouse];
        return YES;
    }
    return NO;
}

#pragma mark - Touch event handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.delegate.qemuInputLegacy) {
        for (UITouch *touch in touches) {
            VMMouseType type = [self touchTypeToMouseType:touch.type];
            if ([self switchMouseType:type]) {
                [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES]; // reset drag
            } else if (!self.vmInput.serverModeCursor) { // start click for client mode
                BOOL primary = YES;
                BOOL secondary = NO;
                BOOL middle = NO;
                CGPoint pos = [touch locationInView:self.mtkView];
                // iOS 13.4+ Pointing device support
                if (@available(iOS 13.4, *)) {
                    if (touch.type == UITouchTypeIndirectPointer) {
                        primary = (event.buttonMask & UIEventButtonMaskPrimary) != 0;
                        secondary = (event.buttonMask & UIEventButtonMaskSecondary) != 0;
                        middle = (event.buttonMask & 0x4) != 0; // undocumented mask
                    }
                }
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
                // Apple Pencil 2 right click mode
                if (@available(iOS 12.1, *)) {
                    if ([self pencilRightClickForTouch:touch]) {
                        primary = NO;
                        secondary = YES;
                    }
                }
#endif
                [self.cursor startMovement:pos];
                [self.cursor updateMovement:pos];
                [self dragCursor:UIGestureRecognizerStateBegan primary:primary secondary:secondary middle:middle];
            }
            break; // handle a single touch only
        }
    } else {
        [self switchMouseType:VMMouseTypeRelative];
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // move cursor in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor) {
        for (UITouch *touch in touches) {
            [self.cursor updateMovement:[touch locationInView:self.mtkView]];
            break; // handle single touch
        }
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor) {
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
    }
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor) {
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
    }
    [super touchesEnded:touches withEvent:event];
}

@end
