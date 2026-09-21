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
#import "UTMSpiceIO.h"
#import "UTMLogging.h"
#import "UTM-Swift.h"

const CGFloat kScrollSpeedReduction = 100.0f;
const CGFloat kCursorResistance = 50.0f;
const CGFloat kScrollResistance = 10.0f;
const CGFloat kLongPressDragThreshold = 10.0f;
const CGFloat kRepeatTapDistance = 24.0f;
const NSTimeInterval kRepeatTapInterval = 0.5;

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

#pragma mark - Properties from instance

- (CSInputButton)mouseButtonDown {
    CSInputButton button = kCSInputButtonNone;
    if (self.mouseLeftDown) {
        button |= kCSInputButtonLeft;
    }
    if (self.mouseRightDown) {
        button |= kCSInputButtonRight;
    }
    if (self.mouseMiddleDown) {
        button |= kCSInputButtonMiddle;
    }
    if (self.mouseSideDown) {
        button |= kCSInputButtonSide;
    }
    if (self.mouseExtraDown) {
        button |= kCSInputButtonExtra;
    }
    return button;
}

#pragma mark - Properties from settings

- (BOOL)isInvertScroll {
    return [self boolForSetting:@"InvertScroll"];
}

- (VMGestureType)gestureTypeForSetting:(NSString *)key {
    NSInteger integer = [self integerForSetting:key];
    if (integer < VMGestureTypeNone || integer >= VMGestureTypeMax) {
        return VMGestureTypeNone;
    } else {
        return (VMGestureType)integer;
    }
}

- (VMGestureType)longPressType {
    return [self gestureTypeForSetting:@"GestureLongPress"];
}

- (VMGestureType)twoFingerTapType {
    return [self gestureTypeForSetting:@"GestureTwoTap"];
}

- (VMGestureType)twoFingerPanType {
    return [self gestureTypeForSetting:@"GestureTwoPan"];
}

- (VMGestureType)twoFingerScrollType {
    return [self gestureTypeForSetting:@"GestureTwoScroll"];
}

/// A two finger swipe must be told apart from a two finger pan unless both scroll
- (BOOL)isTwoFingerSwipeExclusive {
    return self.twoFingerScrollType != VMGestureTypeNone && self.twoFingerPanType != VMGestureTypeMouseWheel;
}

- (VMGestureType)threeFingerPanType {
    return [self gestureTypeForSetting:@"GestureThreePan"];
}

- (VMMouseType)mouseTypeForSetting:(NSString *)key {
    NSInteger integer = [self integerForSetting:key];
    if (integer < VMMouseTypeRelative || integer >= VMMouseTypeMax) {
        return VMMouseTypeRelative;
    } else {
        return (VMMouseType)integer;
    }
}

- (VMMouseType)touchMouseType {
    return [self mouseTypeForSetting:@"MouseTouchType"];
}

- (VMMouseType)pencilMouseType {
    return [self mouseTypeForSetting:@"MousePencilType"];
}

- (VMMouseType)indirectMouseType {
#if TARGET_OS_VISION
    return VMMouseTypeAbsolute;
#else
    return VMMouseTypeRelative;
#endif
}

#pragma mark - Converting view points to VM display points

static CGRect CGRectClipToBounds(CGRect rect1, CGRect rect2) {
    if (rect2.origin.x < rect1.origin.x) {
        rect2.origin.x = rect1.origin.x;
    } else if (rect2.origin.x + rect2.size.width > rect1.origin.x + rect1.size.width) {
        rect2.origin.x = rect1.origin.x + rect1.size.width - rect2.size.width;
    }
    if (rect2.origin.y < rect1.origin.y) {
        rect2.origin.y = rect1.origin.y;
    } else if (rect2.origin.y + rect2.size.height > rect1.origin.y + rect1.size.height) {
        rect2.origin.y = rect1.origin.y + rect1.size.height - rect2.size.height;
    }
    return rect2;
}

- (CGPoint)clipCursorToDisplay:(CGPoint)pos {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmDisplay.displaySize.width * self.renderer.viewportScale,
        self.vmDisplay.displaySize.height * self.renderer.viewportScale
    };
    CGRect drawRect = CGRectMake(
        self.renderer.viewportOrigin.x + screenSize.width/2 - scaledSize.width/2,
        self.renderer.viewportOrigin.y + screenSize.height/2 - scaledSize.height/2,
        scaledSize.width,
        scaledSize.height
    );
    pos.x -= drawRect.origin.x;
    pos.y -= drawRect.origin.y;
    if (pos.x < 0) {
        pos.x = 0;
    } else if (pos.x > scaledSize.width) {
        pos.x = scaledSize.width;
    }
    if (pos.y < 0) {
        pos.y = 0;
    } else if (pos.y > scaledSize.height) {
        pos.y = scaledSize.height;
    }
    pos.x /= self.renderer.viewportScale;
    pos.y /= self.renderer.viewportScale;
    return pos;
}

- (CGPoint)clipDisplayToView:(CGPoint)target {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmDisplay.displaySize.width * self.renderer.viewportScale,
        self.vmDisplay.displaySize.height * self.renderer.viewportScale
    };
    CGRect drawRect = CGRectMake(
        target.x + screenSize.width/2 - scaledSize.width/2,
        target.y + screenSize.height/2 - scaledSize.height/2,
        scaledSize.width,
        scaledSize.height
    );
    CGRect boundRect = {
        {
            screenSize.width - MAX(screenSize.width, scaledSize.width),
            screenSize.height - MAX(screenSize.height, scaledSize.height)
            
        },
        {
            2*MAX(screenSize.width, scaledSize.width) - screenSize.width,
            2*MAX(screenSize.height, scaledSize.height) - screenSize.height
        }
    };
    CGRect clippedRect = CGRectClipToBounds(boundRect, drawRect);
    clippedRect.origin.x -= (screenSize.width/2 - scaledSize.width/2);
    clippedRect.origin.y -= (screenSize.height/2 - scaledSize.height/2);
    return CGPointMake(clippedRect.origin.x, clippedRect.origin.y);
}

#pragma mark - Gestures

- (void)moveMouseWithInertia:(UIPanGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:sender.view];
    CGPoint velocity = [sender velocityInView:sender.view];
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.cursor startMovement:location];
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        [self.cursor updateMovement:location];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.cursor endMovementWithVelocity:velocity resistance:kCursorResistance];
    }
}

- (void)scrollWithInertia:(UIPanGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:sender.view];
    CGPoint velocity = [sender velocityInView:sender.view];
    if (sender == self.pan) { // one finger drags the content along with it, the opposite of turning a wheel
        location.y = -location.y;
        velocity.y = -velocity.y;
    }
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.scroll startMovement:location];
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        [self.scroll updateMovement:location];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.scroll endMovementWithVelocity:velocity resistance:kScrollResistance];
    }
}

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender {
    if (self.serverModeCursor) {  // otherwise we handle in touchesMoved
        [self moveMouseWithInertia:sender];
    } else if (self.isTouchScrolling) {
        [self scrollWithInertia:sender];
    }
}

- (void)moveScreen:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        self.lastTwoPanOrigin = self.renderer.viewportOrigin;
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        CGPoint translation = [sender translationInView:sender.view];
        CGPoint viewport = self.renderer.viewportOrigin;
        viewport.x = CGPointToPixel(self.view, translation.x) + self.lastTwoPanOrigin.x;
        viewport.y = CGPointToPixel(self.view, translation.y) + self.lastTwoPanOrigin.y;
        self.renderer.viewportOrigin = [self clipDisplayToView:viewport];
        // persist this change in viewState
        self.delegate.displayOrigin = self.renderer.viewportOrigin;
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        // TODO: decelerate
    }
}

- (IBAction)gestureTwoPan:(UIPanGestureRecognizer *)sender {
    switch (self.twoFingerPanType) {
        case VMGestureTypeMoveScreen:
            [self moveScreen:sender];
            break;
        case VMGestureTypeDragCursor:
        case VMGestureTypeRightDrag:
        case VMGestureTypeMiddleDrag:
            [self dragCursor:sender.state gestureType:self.twoFingerPanType];
            [self moveMouseWithInertia:sender];
            break;
        case VMGestureTypeMouseWheel:
            [self scrollWithInertia:sender];
            break;
        default:
            break;
    }
}

- (IBAction)gestureThreePan:(UIPanGestureRecognizer *)sender {
    switch (self.threeFingerPanType) {
        case VMGestureTypeMoveScreen:
            [self moveScreen:sender];
            break;
        case VMGestureTypeDragCursor:
        case VMGestureTypeRightDrag:
        case VMGestureTypeMiddleDrag:
            [self dragCursor:sender.state gestureType:self.threeFingerPanType];
            [self moveMouseWithInertia:sender];
            break;
        case VMGestureTypeMouseWheel:
            [self scrollWithInertia:sender];
            break;
        default:
            break;
    }
}

- (CGPoint)moveMouseAbsolute:(CGPoint)location {
    CGPoint translated = location;
    translated.x = CGPointToPixel(self.view, translated.x);
    translated.y = CGPointToPixel(self.view, translated.y);
    translated = [self clipCursorToDisplay:translated];
    if (!self.vmInput.serverModeCursor) {
        [self.vmInput sendMousePosition:self.mouseButtonDown absolutePoint:translated];
        [self.vmDisplay.cursor moveTo:translated]; // required to show cursor on screen
    } else {
        UTMLog(@"Warning: ignored mouse set (%f, %f) while mouse is in server mode", translated.x, translated.y);
    }
    return translated;
}

- (CGPoint)moveMouseRelative:(CGPoint)translation {
    translation.x = CGPointToPixel(self.view, translation.x) / self.renderer.viewportScale;
    translation.y = CGPointToPixel(self.view, translation.y) / self.renderer.viewportScale;
    if (self.vmInput.serverModeCursor) {
        [self.vmInput sendMouseMotion:self.mouseButtonDown relativePoint:translation];
    } else {
        UTMLog(@"Warning: ignored mouse motion (%f, %f) while mouse is in client mode", translation.x, translation.y);
    }
    return translation;
}

- (CGPoint)moveMouseScroll:(CGPoint)translation {
    translation.y = CGPointToPixel(self.view, translation.y) / kScrollSpeedReduction;
    if (self.isInvertScroll) {
        translation.y = -translation.y;
    }
    [self.vmInput sendMouseScroll:kCSInputScrollSmooth buttonMask:self.mouseButtonDown dy:translation.y];
    return translation;
}

- (void)mouseClick:(CSInputButton)button location:(CGPoint)location {
    if (!self.serverModeCursor) {
        self.cursor.center = location;
    }
    [self.vmInput sendMouseButton:button mask:kCSInputButtonNone pressed:YES];
    [self onDelay:0.05f action:^{
        self.mouseLeftDown = NO;
        self.mouseRightDown = NO;
        self.mouseMiddleDown = NO;
        [self.vmInput sendMouseButton:button mask:kCSInputButtonNone pressed:NO];
    }];
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    [self.clickFeedbackGenerator selectionChanged];
#endif
}

- (void)dragCursor:(UIGestureRecognizerState)state primary:(BOOL)primary secondary:(BOOL)secondary middle:(BOOL)middle {
    CSInputButton button = kCSInputButtonNone;
    if (middle) {
        button = kCSInputButtonMiddle;
    }
    if (secondary) {
        button = kCSInputButtonRight;
    }
    if (primary) {
        button = kCSInputButtonLeft;
    }
    if (state == UIGestureRecognizerStateBegan) {
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
        [self.clickFeedbackGenerator selectionChanged];
#endif
        if (primary) {
            self.mouseLeftDown = YES;
        }
        if (secondary) {
            self.mouseRightDown = YES;
        }
        if (middle) {
            self.mouseMiddleDown = YES;
        }
        [self.vmInput sendMouseButton:button mask:self.mouseButtonDown pressed:YES];
    } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
        self.mouseLeftDown = NO;
        self.mouseRightDown = NO;
        self.mouseMiddleDown = NO;
        [self.vmInput sendMouseButton:button mask:self.mouseButtonDown pressed:NO];
    }
}

- (CSInputButton)buttonForGestureType:(VMGestureType)type {
    switch (type) {
        case VMGestureTypeDragCursor:
            return kCSInputButtonLeft;
        case VMGestureTypeRightClick:
        case VMGestureTypeRightDrag:
            return kCSInputButtonRight;
        case VMGestureTypeMiddleClick:
        case VMGestureTypeMiddleDrag:
            return kCSInputButtonMiddle;
        default:
            return kCSInputButtonNone;
    }
}

- (void)dragCursor:(UIGestureRecognizerState)state gestureType:(VMGestureType)type {
    CSInputButton button = [self buttonForGestureType:type];
    [self dragCursor:state
             primary:button == kCSInputButtonLeft
           secondary:button == kCSInputButtonRight
              middle:button == kCSInputButtonMiddle];
}

/// A finger never lands on the same spot twice and the guest only counts clicks on the same spot as a double click
- (BOOL)isRepeatTapAtLocation:(CGPoint)location {
    CGFloat distance = hypot(location.x - self.lastTapLocation.x, location.y - self.lastTapLocation.y);
    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - self.lastTapTime;
    return elapsed < kRepeatTapInterval && distance < kRepeatTapDistance;
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint location = [sender locationInView:sender.view];
    if (self.isTouchScrolling) {
        if ([self isRepeatTapAtLocation:location]) {
            location = self.lastTapLocation;
        }
        self.lastTapLocation = location;
        self.lastTapTime = NSProcessInfo.processInfo.systemUptime;
        [self mouseClick:kCSInputButtonLeft location:location];
    } else if (self.serverModeCursor) { // otherwise we handle in touchesBegan
        [self mouseClick:kCSInputButtonLeft location:location];
    }
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    CSInputButton button = [self buttonForGestureType:self.twoFingerTapType];
    if (sender.state == UIGestureRecognizerStateEnded && button != kCSInputButtonNone) {
        [self mouseClick:button location:[sender locationInView:sender.view]];
    }
}

- (void)showLongPressIndicatorAtLocation:(CGPoint)location {
    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    indicator.center = location;
    indicator.userInteractionEnabled = NO;
    indicator.layer.cornerRadius = 40;
    indicator.layer.borderWidth = 3;
    indicator.layer.borderColor = UIColor.whiteColor.CGColor;
    indicator.layer.shadowOpacity = 0.5f;
    indicator.layer.shadowRadius = 3;
    indicator.layer.shadowOffset = CGSizeZero;
    [self.mtkView addSubview:indicator];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        indicator.alpha = 0;
        indicator.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
    } completion:^(BOOL finished) {
        [indicator removeFromSuperview];
    }];
}

/// A touch does not hold the button when it scrolls so a long press that moves becomes the drag
- (void)touchScrollLongPress:(UILongPressGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:sender.view];
    if (sender.state == UIGestureRecognizerStateBegan) {
        self.lastLongPressOrigin = location;
        [self.cursor startMovement:location];
        [self.cursor updateMovement:location];
        [self showLongPressIndicatorAtLocation:location];
        if (self.longPressType == VMGestureTypeDragCursor) {
            [self dragCursor:sender.state gestureType:VMGestureTypeDragCursor];
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        CGFloat distance = hypot(location.x - self.lastLongPressOrigin.x, location.y - self.lastLongPressOrigin.y);
        if (!self.mouseLeftDown && distance >= kLongPressDragThreshold) {
            [self dragCursor:UIGestureRecognizerStateBegan gestureType:VMGestureTypeDragCursor];
        }
        if (self.mouseLeftDown) {
            [self.cursor updateMovement:location];
        }
    } else if (self.mouseLeftDown) {
        [self dragCursor:UIGestureRecognizerStateEnded gestureType:VMGestureTypeDragCursor];
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        CSInputButton button = [self buttonForGestureType:self.longPressType];
        if (button != kCSInputButtonNone) {
            [self mouseClick:button location:self.lastLongPressOrigin];
        }
    }
}

- (IBAction)gestureLongPress:(UILongPressGestureRecognizer *)sender {
    if (self.isTouchScrolling) {
        [self touchScrollLongPress:sender];
    } else if (self.longPressType == VMGestureTypeDragCursor) {
        [self dragCursor:sender.state gestureType:self.longPressType];
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        CSInputButton button = [self buttonForGestureType:self.longPressType];
        if (button != kCSInputButtonNone) {
            [self mouseClick:button location:[sender locationInView:sender.view]];
        }
    }
}

- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender {
    // disable pinch if move screen on pan is disabled
    if (!(self.twoFingerPanType == VMGestureTypeMoveScreen || self.threeFingerPanType == VMGestureTypeMoveScreen)) {
        return;
    }
    if (sender.state == UIGestureRecognizerStateBegan ||
        sender.state == UIGestureRecognizerStateChanged ||
        sender.state == UIGestureRecognizerStateEnded) {
        NSAssert(sender.scale > 0, @"sender.scale cannot be 0");
        CGFloat scaling;
        if (!self.delegate.qemuDisplayIsNativeResolution) {
            // will be undo in `-setDisplayScaling:origin:`
            scaling = CGPixelToPoint(self.view, CGPointToPixel(self.view, self.delegate.displayScale) * sender.scale);
        } else {
            scaling = self.delegate.displayScale * sender.scale;
        }
        self.delegate.displayIsZoomLocked = false;
        self.delegate.displayScale = scaling;
        sender.scale = 1.0;
    }
}

- (IBAction)gestureSwipeUp:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self showKeyboard];
    }
}

- (IBAction)gestureSwipeDown:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideKeyboard];
    }
}

- (IBAction)gestureSwipeScroll:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.twoFingerScrollType == VMGestureTypeMouseWheel) {
        // same direction as the pan that may be scrolling along with the swipe
        CSInputScroll up = self.isInvertScroll ? kCSInputScrollDown : kCSInputScrollUp;
        CSInputScroll down = self.isInvertScroll ? kCSInputScrollUp : kCSInputScrollDown;
        if (sender == self.swipeScrollUp) {
            [self.vmInput sendMouseScroll:up buttonMask:self.mouseButtonDown dy:0];
        } else if (sender == self.swipeScrollDown) {
            [self.vmInput sendMouseScroll:down buttonMask:self.mouseButtonDown dy:0];
        } else {
            NSAssert(0, @"Invalid call to gestureSwipeScroll");
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.twoTap && otherGestureRecognizer == self.swipeDown) {
        return YES;
    }
    if (gestureRecognizer == self.twoTap && otherGestureRecognizer == self.swipeUp) {
        return YES;
    }
    if (gestureRecognizer == self.tap && otherGestureRecognizer == self.twoTap) {
        return YES;
    }
    if (gestureRecognizer == self.tap && otherGestureRecognizer == self.longPress) {
        return YES;
    }
    // a swipe can take half a second to fail so a pan only waits for one that matches the same number of touches
    if (gestureRecognizer == self.threePan && otherGestureRecognizer == self.swipeUp) {
        return YES;
    }
    if (gestureRecognizer == self.threePan && otherGestureRecognizer == self.swipeDown) {
        return YES;
    }
    if (self.isTwoFingerSwipeExclusive) {
        if (gestureRecognizer == self.twoPan && otherGestureRecognizer == self.swipeScrollUp) {
            return YES;
        }
        if (gestureRecognizer == self.twoPan && otherGestureRecognizer == self.swipeScrollDown) {
            return YES;
        }
    }
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    return [self pencilGestureRecognizer:gestureRecognizer shouldRequireFailureOfGestureRecognizer:otherGestureRecognizer];
#else
    return NO;
#endif
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.pinch) {
        // before iOS 18 a pinch begins with two of three fingers and takes them from the three finger gestures
        return self.threePan.numberOfTouches < 3;
    }
    if (gestureRecognizer == self.longPress) {
        // otherwise a disabled long press would swallow the tap waiting on it
        return self.longPressType != VMGestureTypeNone;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.twoPan && otherGestureRecognizer == self.pinch) {
        if (self.twoFingerPanType == VMGestureTypeMoveScreen) {
            return YES;
        } else {
            return NO;
        }
    } else if (gestureRecognizer == self.pan && otherGestureRecognizer == self.longPress) {
        return !self.isTouchScrolling; // there the pan scrolls and the long press moves the cursor itself
    } else if (!self.isTwoFingerSwipeExclusive && otherGestureRecognizer == self.twoPan) {
        if (gestureRecognizer == self.swipeScrollUp) {
            return YES;
        } else if (gestureRecognizer == self.swipeScrollDown) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTransform) {
        UTMLog(@"ignoring UIEventTypeTransform");
        return NO;
    } else {
        return YES;
    }
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
            if (type == UITouchTypeIndirectPointer) {
                return self.indirectMouseType;
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
        UTMLog(@"Switching mouse mode to server:%d for type:%ld", shouldUseServerMouse, type);
        [self.delegate requestInputTablet:!shouldUseServerMouse];
        return YES;
    }
    return NO;
}

#if TARGET_OS_VISION
- (BOOL)isTouchGazeGesture:(UITouch *)touch {
    id manipulator = [touch valueForKey:@"_manipulator"];
    SEL selector = NSSelectorFromString(@"_type");
    if ([manipulator respondsToSelector:selector]) {
        IMP imp = [manipulator methodForSelector:selector];
        if (imp) {
            return ((NSInteger (*)(id, SEL))imp)(manipulator, selector) == 2;
        }
    }
    return NO;
}
#endif

#pragma mark - Touch event handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.delegate.qemuInputLegacy) {
        for (UITouch *touch in touches) {
            VMMouseType type = [self touchTypeToMouseType:touch.type];
#if TARGET_OS_VISION
            if ([self isTouchGazeGesture:touch]) {
                type = VMMouseTypeRelative;
            }
#endif
            if (event.allTouches.count == touches.count) { // a touch joining later does not change the gesture
                self.isTouchScrolling = (type == VMMouseTypeAbsoluteScroll);
            }
            if ([self switchMouseType:type]) {
                self.isTouchScrolling = NO; // the cursor mode changes under this touch
                [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES]; // reset drag
            } else if (!self.vmInput.serverModeCursor) { // start click for client mode
                if (self.isTouchScrolling) { // clicks come from the gestures instead
                    if (event.allTouches.count == 1) {
                        CGPoint pos = [touch locationInView:self.mtkView];
                        if (![self isRepeatTapAtLocation:pos]) { // else leave the cursor for the double click
                            [self.cursor startMovement:pos];
                            [self.cursor updateMovement:pos];
                        }
                        [self.scroll startMovement:pos]; // stop a fling like a touch screen does
                    }
                    break;
                }
                BOOL primary = YES;
                BOOL secondary = NO;
                BOOL middle = NO;
                CGPoint pos = [touch locationInView:self.mtkView];
                if (touch.type == UITouchTypeIndirectPointer) {
                    primary = (event.buttonMask & UIEventButtonMaskPrimary) != 0;
                    secondary = (event.buttonMask & UIEventButtonMaskSecondary) != 0;
                    middle = (event.buttonMask & 0x4) != 0; // undocumented mask
                }
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
                // Apple Pencil 2 right click mode
                if ([self pencilRightClickForTouch:touch]) {
                    primary = NO;
                    secondary = YES;
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
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor && !self.isTouchScrolling) {
        for (UITouch *touch in touches) {
            [self.cursor updateMovement:[touch locationInView:self.mtkView]];
            break; // handle single touch
        }
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor && !self.isTouchScrolling) {
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
    }
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor && !self.isTouchScrolling) {
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
    }
    [super touchesEnded:touches withEvent:event];
}

@end
