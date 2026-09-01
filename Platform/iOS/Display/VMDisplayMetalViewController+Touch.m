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
#import <math.h>

const CGFloat kScrollSpeedReduction = 100.0f;
const CGFloat kCursorResistance = 50.0f;
const CGFloat kScrollResistance = 10.0f;
const CGFloat kMultitouchDragThreshold = 8.0f;
const CGFloat kMultitouchPanStartDistance = 12.0f;
const CGFloat kMultitouchSwipeDistance = 60.0f;
const CGFloat kMultitouchSwipeVelocity = 300.0f;
const CGFloat kMultitouchSwipeAcceleration = 3000.0f;
const NSTimeInterval kMultitouchSwipeCandidateWindow = 0.05;
const CGFloat kMultitouchPinchStartDistance = 16.0f;

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
    self.twoPan.cancelsTouchesInView = NO;
    self.threePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureThreePan:)];
    self.threePan.minimumNumberOfTouches = 3;
    self.threePan.maximumNumberOfTouches = 3;
    self.threePan.delegate = self;
    self.threePan.cancelsTouchesInView = NO;
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    self.tap.delegate = self;
    self.tap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.tap.cancelsTouchesInView = NO;
    self.twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoTap:)];
    self.twoTap.numberOfTouchesRequired = 2;
    self.twoTap.delegate = self;
    self.twoTap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.twoTap.cancelsTouchesInView = NO;
    self.threeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureThreeTap:)];
    self.threeTap.numberOfTouchesRequired = 3;
    self.threeTap.delegate = self;
    self.threeTap.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.threeTap.cancelsTouchesInView = NO;
    self.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(gestureLongPress:)];
    self.longPress.delegate = self;
    self.longPress.allowedTouchTypes = @[ @(UITouchTypeDirect) ];
    self.longPress.cancelsTouchesInView = NO;
    self.pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    self.pinch.delegate = self;
    self.pinch.cancelsTouchesInView = NO;
    [self.tap requireGestureRecognizerToFail:self.longPress];
    [self.twoTap requireGestureRecognizerToFail:self.twoPan];
    [self.threeTap requireGestureRecognizerToFail:self.threePan];
    [self.mtkView addGestureRecognizer:self.swipeScrollUp];
    [self.mtkView addGestureRecognizer:self.swipeScrollDown];
    [self.mtkView addGestureRecognizer:self.pan];
    [self.mtkView addGestureRecognizer:self.twoPan];
    [self.mtkView addGestureRecognizer:self.threePan];
    [self.mtkView addGestureRecognizer:self.tap];
    [self.mtkView addGestureRecognizer:self.twoTap];
    [self.mtkView addGestureRecognizer:self.threeTap];
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

- (VMGestureType)longPressDragType {
    return [self gestureTypeForSetting:@"GestureLongPressDrag"];
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

- (VMGestureType)twoFingerPinchType {
    return [self gestureTypeForSetting:@"GestureTwoPinch"];
}

- (VMGestureType)threeFingerTapType {
    return [self gestureTypeForSetting:@"GestureThreeTap"];
}

- (VMGestureType)threeFingerPanType {
    return [self gestureTypeForSetting:@"GestureThreePan"];
}

- (BOOL)isThreeFingerSwipeEnabled {
    return [self integerForSetting:@"GestureThreeSwipe"] != 0;
}

- (BOOL)isVerticalSwipeForPan:(UIPanGestureRecognizer *)sender accelerationY:(CGFloat)accelerationY {
    CGPoint translation = [sender translationInView:sender.view];
    CGPoint velocity = [sender velocityInView:sender.view];
    BOOL velocityWithGesture = translation.y * velocity.y > 0;
    BOOL acceleratingWithGesture = translation.y * accelerationY > 0;
    return [self isVerticalSwipeDistanceForPan:sender] &&
           ((velocityWithGesture && fabs(velocity.y) >= kMultitouchSwipeVelocity) ||
            (acceleratingWithGesture && fabs(accelerationY) >= kMultitouchSwipeAcceleration)) &&
           fabs(translation.y) > fabs(translation.x) * 1.5f;
}

- (BOOL)isVerticalSwipeDistanceForPan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:sender.view];
    return fabs(translation.y) >= kMultitouchSwipeDistance &&
           fabs(translation.y) > fabs(translation.x);
}

- (CGFloat)verticalAccelerationForPan:(UIPanGestureRecognizer *)sender {
    CGPoint velocity = [sender velocityInView:sender.view];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    CGPoint lastVelocity = CGPointZero;
    NSTimeInterval lastTime = 0;
    if (sender == self.twoPan) {
        lastVelocity = self.multitouchTwoPanLastVelocity;
        lastTime = self.multitouchTwoPanLastTime;
        if (sender.state == UIGestureRecognizerStateBegan) {
            self.multitouchTwoPanBeginTime = now;
        }
        self.multitouchTwoPanLastVelocity = velocity;
        self.multitouchTwoPanLastTime = now;
    } else if (sender == self.threePan) {
        lastVelocity = self.multitouchThreePanLastVelocity;
        lastTime = self.multitouchThreePanLastTime;
        if (sender.state == UIGestureRecognizerStateBegan) {
            self.multitouchThreePanBeginTime = now;
        }
        self.multitouchThreePanLastVelocity = velocity;
        self.multitouchThreePanLastTime = now;
    }
    if (sender.state == UIGestureRecognizerStateBegan || lastTime <= 0 || now <= lastTime) {
        return 0.0f;
    }
    return (velocity.y - lastVelocity.y) / (CGFloat)(now - lastTime);
}

- (BOOL)shouldDeferPan:(UIPanGestureRecognizer *)sender forSwipeEnabled:(BOOL)swipeEnabled decided:(BOOL *)decided candidate:(BOOL *)candidate accelerationY:(CGFloat)accelerationY {
    if ([self isTerminalGestureState:sender.state]) {
        return NO;
    }
    CGPoint translation = [sender translationInView:sender.view];
    if (!swipeEnabled) {
        return hypot(translation.x, translation.y) < kMultitouchPanStartDistance;
    }
    NSTimeInterval beginTime = 0;
    if (sender == self.twoPan) {
        beginTime = self.multitouchTwoPanBeginTime;
    } else if (sender == self.threePan) {
        beginTime = self.multitouchThreePanBeginTime;
    }
    if (!*decided) {
        NSTimeInterval elapsed = beginTime > 0 ? [NSDate timeIntervalSinceReferenceDate] - beginTime : 0;
        if (elapsed < kMultitouchSwipeCandidateWindow) {
            return YES;
        }
        *decided = YES;
        *candidate = [self isVerticalSwipeForPan:sender accelerationY:accelerationY];
        return *candidate;
    }
    if (*candidate) {
        return YES;
    }
    return hypot(translation.x, translation.y) < kMultitouchPanStartDistance;
}

- (CGFloat)pinchTouchDistance:(UIPinchGestureRecognizer *)sender {
    if (sender.numberOfTouches < 2) {
        return 0.0f;
    }
    CGPoint first = [sender locationOfTouch:0 inView:sender.view];
    CGPoint second = [sender locationOfTouch:1 inView:sender.view];
    return hypot(first.x - second.x, first.y - second.y);
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
    if (@available(iOS 14.0, *)) {
        return VMMouseTypeRelative;
    } else {
        return VMMouseTypeAbsolute; // legacy iOS 13.4 mouse handling requires absolute
    }
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

- (BOOL)dragButtonsForGestureType:(VMGestureType)type primary:(BOOL *)primary secondary:(BOOL *)secondary middle:(BOOL *)middle {
    *primary = NO;
    *secondary = NO;
    *middle = NO;
    switch (type) {
        case VMGestureTypeDragCursor:
            *primary = YES;
            return YES;
        case VMGestureTypeRightDrag:
            *secondary = YES;
            return YES;
        case VMGestureTypeMiddleDrag:
            *middle = YES;
            return YES;
        default:
            return NO;
    }
}

- (void)dragFromPrimaryTouchForPan:(UIPanGestureRecognizer *)sender gestureType:(VMGestureType)type state:(UIGestureRecognizerState)state {
    BOOL primary = NO;
    BOOL secondary = NO;
    BOOL middle = NO;
    if ([self dragButtonsForGestureType:type primary:&primary secondary:&secondary middle:&middle]) {
        [self dragCursor:state primary:primary secondary:secondary middle:middle];
        CGPoint translation = [sender translationInView:sender.view];
        CGPoint location = CGPointMake(self.multitouchPrimaryTouchLocation.x + translation.x,
                                       self.multitouchPrimaryTouchLocation.y + translation.y);
        if (state == UIGestureRecognizerStateBegan) {
            [self.cursor startMovement:self.multitouchPrimaryTouchLocation];
        }
        if (state != UIGestureRecognizerStateCancelled &&
            state != UIGestureRecognizerStateFailed) {
            [self.cursor updateMovement:location];
        }
        if (state == UIGestureRecognizerStateEnded) {
            CGPoint velocity = [sender velocityInView:sender.view];
            [self.cursor endMovementWithVelocity:velocity resistance:kCursorResistance];
        }
    } else if ([self isTerminalGestureState:state]) {
        [self dragCursor:state primary:YES secondary:YES middle:YES];
    }
}

- (void)performMultitouchPan:(UIPanGestureRecognizer *)sender gestureType:(VMGestureType)type actionStarted:(BOOL *)actionStarted {
    if ([self isTerminalGestureState:sender.state]) {
        return;
    }
    if (!*actionStarted) {
        [self dragFromPrimaryTouchForPan:sender gestureType:type state:UIGestureRecognizerStateBegan];
        *actionStarted = YES;
    }
    if (sender.state != UIGestureRecognizerStateBegan) {
        [self dragFromPrimaryTouchForPan:sender gestureType:type state:sender.state];
    }
}

- (void)dragCursor:(UIGestureRecognizerState)state gestureType:(VMGestureType)type {
    BOOL primary = NO;
    BOOL secondary = NO;
    BOOL middle = NO;
    if ([self dragButtonsForGestureType:type primary:&primary secondary:&secondary middle:&middle]) {
        [self dragCursor:state primary:primary secondary:secondary middle:middle];
    }
}

- (void)showLongPressIndicatorAtLocation:(CGPoint)location {
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    CGFloat diameter = 88.0f;
    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, diameter, diameter)];
    indicator.center = location;
    indicator.userInteractionEnabled = NO;
    indicator.backgroundColor = UIColor.clearColor;

    CGRect ringRect = CGRectInset(indicator.bounds, 4.0f, 4.0f);
    UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];
    CAShapeLayer *outlineLayer = [CAShapeLayer layer];
    outlineLayer.path = ringPath.CGPath;
    outlineLayer.fillColor = UIColor.clearColor.CGColor;
    outlineLayer.strokeColor = UIColor.whiteColor.CGColor;
    outlineLayer.lineWidth = 6.0f;
    [indicator.layer addSublayer:outlineLayer];
    CAShapeLayer *strokeLayer = [CAShapeLayer layer];
    strokeLayer.path = ringPath.CGPath;
    strokeLayer.fillColor = UIColor.clearColor.CGColor;
    strokeLayer.strokeColor = UIColor.blackColor.CGColor;
    strokeLayer.lineWidth = 2.0f;
    [indicator.layer addSublayer:strokeLayer];

    indicator.layer.shadowColor = UIColor.blackColor.CGColor;
    indicator.layer.shadowOpacity = 0.35f;
    indicator.layer.shadowRadius = 4.0f;
    indicator.layer.shadowOffset = CGSizeZero;
    indicator.alpha = 1.0f;
    [self.mtkView addSubview:indicator];
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        indicator.alpha = 0.0f;
        indicator.transform = CGAffineTransformMakeScale(1.35f, 1.35f);
    } completion:^(BOOL finished) {
        (void)finished;
        [indicator removeFromSuperview];
    }];
#else
    (void)location;
#endif
}

- (void)resetMultitouchSequence {
    self.multitouchPrimaryTouch = nil;
    self.multitouchTwoPanConsumed = NO;
    self.multitouchThreePanConsumed = NO;
    self.multitouchTwoPanActionStarted = NO;
    self.multitouchThreePanActionStarted = NO;
    self.multitouchTwoSwipeDecided = NO;
    self.multitouchThreeSwipeDecided = NO;
    self.multitouchTwoSwipeCandidate = NO;
    self.multitouchThreeSwipeCandidate = NO;
    self.multitouchTwoPanLastVelocity = CGPointZero;
    self.multitouchThreePanLastVelocity = CGPointZero;
    self.multitouchTwoPanLastTime = 0;
    self.multitouchThreePanLastTime = 0;
    self.multitouchTwoPanBeginTime = 0;
    self.multitouchThreePanBeginTime = 0;
    self.multitouchPinchActive = NO;
    self.multitouchPinchInitialDistance = 0.0f;
    self.multitouchActiveDirectTouchCount = 0;
    self.multitouchLongPressRecognized = NO;
    self.multitouchLongPressPending = NO;
    self.multitouchLongPressDragging = NO;
    self.multitouchLongPressTouchActive = NO;
    self.multitouchLongPressCancelledByMovement = NO;
    self.multitouchScrollVelocity = CGPointZero;
}

- (void)cancelMultitouchLongPress {
    BOOL shouldResetRecognizer = !self.multitouchLongPressCancelledByMovement ||
                                 self.multitouchLongPressRecognized ||
                                 self.multitouchLongPressPending ||
                                 self.multitouchLongPressDragging;
    if (self.multitouchLongPressDragging) {
        [self dragCursor:UIGestureRecognizerStateCancelled gestureType:self.longPressDragType];
    }
    self.multitouchLongPressRecognized = NO;
    self.multitouchLongPressPending = NO;
    self.multitouchLongPressDragging = NO;
    self.multitouchLongPressTouchActive = NO;
    self.multitouchLongPressCancelledByMovement = YES;

    // Reset only the long-press recognizer so a second finger cannot later
    // complete a single-finger right-click while a 2F/3F pan is in progress.
    if (shouldResetRecognizer && self.longPress.enabled) {
        self.longPress.enabled = NO;
        self.longPress.enabled = YES;
    }
}

- (BOOL)isTerminalGestureState:(UIGestureRecognizerState)state {
    return state == UIGestureRecognizerStateEnded ||
           state == UIGestureRecognizerStateCancelled ||
           state == UIGestureRecognizerStateFailed;
}

- (NSUInteger)activeDirectTouchCountForEvent:(UIEvent *)event currentTouches:(NSSet<UITouch *> *)touches {
    NSSet<UITouch *> *eventTouches = event.allTouches ?: touches;
    NSUInteger count = 0;
    for (UITouch *touch in eventTouches) {
        if (touch.type != UITouchTypeDirect) {
            continue;
        }
        if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            continue;
        }
        count++;
    }
    return count;
}

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender {
    if (self.serverModeCursor) {  // otherwise we handle in touchesMoved
        [self moveMouseWithInertia:sender];
    } else if (self.touchMouseType == VMMouseTypeMultitouch) {
        // In multitouch mode we process single-finger drag directly in touchesMoved
        // to avoid UIPan recognition delay and improve gesture responsiveness.
        (void)sender;
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
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        CGFloat accelerationY = [self verticalAccelerationForPan:sender];
        BOOL swipeEnabled = self.twoFingerScrollType == VMGestureTypeMouseWheel;
        if (sender.state == UIGestureRecognizerStateBegan ||
            sender.state == UIGestureRecognizerStateChanged ||
            sender.state == UIGestureRecognizerStateEnded) {
            self.multitouchTwoPanConsumed = YES;
        }
        if (self.multitouchPinchActive) {
            if ([self isTerminalGestureState:sender.state]) {
                [self dragCursor:sender.state primary:YES secondary:YES middle:YES];
            }
            return;
        }
        if (self.multitouchTwoPanActionStarted) {
            if ([self isTerminalGestureState:sender.state]) {
                [self dragCursor:sender.state gestureType:self.twoFingerPanType];
                self.multitouchTwoPanActionStarted = NO;
                return;
            }
            BOOL actionStarted = YES;
            [self performMultitouchPan:sender
                           gestureType:self.twoFingerPanType
                         actionStarted:&actionStarted];
            self.multitouchTwoPanActionStarted = actionStarted;
            return;
        }
        if (sender.state == UIGestureRecognizerStateEnded &&
            swipeEnabled &&
            !self.multitouchTwoSwipeDecided) {
            self.multitouchTwoSwipeDecided = YES;
            self.multitouchTwoSwipeCandidate = [self isVerticalSwipeForPan:sender accelerationY:accelerationY];
        }
        if (sender.state == UIGestureRecognizerStateEnded &&
            swipeEnabled &&
            self.multitouchTwoSwipeCandidate) {
            [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
            CGPoint translation = [sender translationInView:sender.view];
            if (translation.y < 0) {
                [self.vmInput sendMouseScroll:kCSInputScrollUp buttonMask:self.mouseButtonDown dy:0];
            } else {
                [self.vmInput sendMouseScroll:kCSInputScrollDown buttonMask:self.mouseButtonDown dy:0];
            }
            return;
        }
        BOOL swipeCandidate = self.multitouchTwoSwipeCandidate;
        BOOL swipeDecided = self.multitouchTwoSwipeDecided;
        if ([self shouldDeferPan:sender
                 forSwipeEnabled:swipeEnabled
                          decided:&swipeDecided
                       candidate:&swipeCandidate
                   accelerationY:accelerationY]) {
            self.multitouchTwoSwipeDecided = swipeDecided;
            self.multitouchTwoSwipeCandidate = swipeCandidate;
            return;
        }
        self.multitouchTwoSwipeDecided = swipeDecided;
        self.multitouchTwoSwipeCandidate = swipeCandidate;
        BOOL actionStarted = self.multitouchTwoPanActionStarted;
        [self performMultitouchPan:sender
                       gestureType:self.twoFingerPanType
                     actionStarted:&actionStarted];
        self.multitouchTwoPanActionStarted = actionStarted;
        if (self.multitouchTwoPanActionStarted) {
            self.multitouchTwoSwipeDecided = YES;
            self.multitouchTwoSwipeCandidate = NO;
        }
        return;
    }
    switch (self.twoFingerPanType) {
        case VMGestureTypeMoveScreen:
            [self moveScreen:sender];
            break;
        case VMGestureTypeDragCursor:
            [self dragCursor:sender.state primary:YES secondary:NO middle:NO];
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
    CGFloat accelerationY = [self verticalAccelerationForPan:sender];
    BOOL swipeEnabled = [self isThreeFingerSwipeEnabled];
    if (self.touchMouseType == VMMouseTypeMultitouch &&
        (sender.state == UIGestureRecognizerStateBegan ||
         sender.state == UIGestureRecognizerStateChanged ||
         sender.state == UIGestureRecognizerStateEnded)) {
        self.multitouchThreePanConsumed = YES;
    }
    if (self.touchMouseType == VMMouseTypeMultitouch &&
        self.multitouchThreePanActionStarted) {
        if ([self isTerminalGestureState:sender.state]) {
            [self dragCursor:sender.state gestureType:self.threeFingerPanType];
            self.multitouchThreePanActionStarted = NO;
            return;
        }
        BOOL actionStarted = YES;
        [self performMultitouchPan:sender
                       gestureType:self.threeFingerPanType
                     actionStarted:&actionStarted];
        self.multitouchThreePanActionStarted = actionStarted;
        return;
    }
    if (sender.state == UIGestureRecognizerStateEnded && swipeEnabled) {
        if (!self.multitouchThreeSwipeDecided) {
            self.multitouchThreeSwipeDecided = YES;
            self.multitouchThreeSwipeCandidate = [self isVerticalSwipeForPan:sender accelerationY:accelerationY];
        }
        if (self.multitouchThreeSwipeCandidate) {
            CGPoint translation = [sender translationInView:sender.view];
            [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
            if (translation.y < 0) {
                [self showKeyboard];
            } else {
                [self hideKeyboard];
            }
            return;
        }
    }
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        BOOL swipeCandidate = self.multitouchThreeSwipeCandidate;
        BOOL swipeDecided = self.multitouchThreeSwipeDecided;
        if ([self shouldDeferPan:sender
                 forSwipeEnabled:swipeEnabled
                          decided:&swipeDecided
                       candidate:&swipeCandidate
                   accelerationY:accelerationY]) {
            self.multitouchThreeSwipeDecided = swipeDecided;
            self.multitouchThreeSwipeCandidate = swipeCandidate;
            return;
        }
        self.multitouchThreeSwipeDecided = swipeDecided;
        self.multitouchThreeSwipeCandidate = swipeCandidate;
        BOOL actionStarted = self.multitouchThreePanActionStarted;
        [self performMultitouchPan:sender
                       gestureType:self.threeFingerPanType
                     actionStarted:&actionStarted];
        self.multitouchThreePanActionStarted = actionStarted;
        if (self.multitouchThreePanActionStarted) {
            self.multitouchThreeSwipeDecided = YES;
            self.multitouchThreeSwipeCandidate = NO;
        }
        return;
    }
    switch (self.threeFingerPanType) {
        case VMGestureTypeMoveScreen:
            [self moveScreen:sender];
            break;
        case VMGestureTypeDragCursor:
            [self dragCursor:sender.state primary:YES secondary:NO middle:NO];
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
    if ((button == kCSInputButtonLeft && self.mouseLeftDown) ||
        (button == kCSInputButtonRight && self.mouseRightDown) ||
        (button == kCSInputButtonMiddle && self.mouseMiddleDown)) {
        return;
    }
    if (!self.serverModeCursor) {
        self.cursor.center = location;
    }
    [self.vmInput sendMouseButton:button mask:kCSInputButtonNone pressed:YES];
    [self onDelay:0.05f action:^{
        if (button == kCSInputButtonLeft && self.mouseLeftDown) {
            return;
        }
        if (button == kCSInputButtonRight && self.mouseRightDown) {
            return;
        }
        if (button == kCSInputButtonMiddle && self.mouseMiddleDown) {
            return;
        }
        [self.vmInput sendMouseButton:button mask:kCSInputButtonNone pressed:NO];
    }];
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    [self.clickFeedbackGenerator selectionChanged];
#endif
}

- (void)dragCursor:(UIGestureRecognizerState)state primary:(BOOL)primary secondary:(BOOL)secondary middle:(BOOL)middle {
    if (state == UIGestureRecognizerStateBegan) {
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
    } else if (state == UIGestureRecognizerStateEnded ||
               state == UIGestureRecognizerStateCancelled ||
               state == UIGestureRecognizerStateFailed) {
        if (primary && self.mouseLeftDown) {
            self.mouseLeftDown = NO;
            [self.vmInput sendMouseButton:kCSInputButtonLeft mask:self.mouseButtonDown pressed:NO];
        }
        if (secondary && self.mouseRightDown) {
            self.mouseRightDown = NO;
            [self.vmInput sendMouseButton:kCSInputButtonRight mask:self.mouseButtonDown pressed:NO];
        }
        if (middle && self.mouseMiddleDown) {
            self.mouseMiddleDown = NO;
            [self.vmInput sendMouseButton:kCSInputButtonMiddle mask:self.mouseButtonDown pressed:NO];
        }
    }
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (self.serverModeCursor || self.touchMouseType == VMMouseTypeMultitouch) {
        [self mouseClick:kCSInputButtonLeft location:[sender locationInView:sender.view]];
    }
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (self.touchMouseType == VMMouseTypeMultitouch && self.multitouchTwoPanConsumed) {
        return;
    }
    CGPoint panTranslation = [self.twoPan translationInView:self.twoPan.view];
    if (self.touchMouseType == VMMouseTypeMultitouch &&
        hypot(panTranslation.x, panTranslation.y) >= kMultitouchDragThreshold) {
        return;
    }
    CGPoint clickLocation = [sender locationInView:sender.view];
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        clickLocation = self.multitouchPrimaryTouchLocation;
    }
    switch (self.twoFingerTapType) {
        case VMGestureTypeRightClick:
            [self mouseClick:kCSInputButtonRight location:clickLocation];
            break;
        case VMGestureTypeMiddleClick:
            [self mouseClick:kCSInputButtonMiddle location:clickLocation];
            break;
        default:
            break;
    }
}

- (IBAction)gestureThreeTap:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (self.touchMouseType == VMMouseTypeMultitouch && self.multitouchThreePanConsumed) {
        return;
    }
    CGPoint panTranslation = [self.threePan translationInView:self.threePan.view];
    if (self.touchMouseType == VMMouseTypeMultitouch &&
        hypot(panTranslation.x, panTranslation.y) >= kMultitouchDragThreshold) {
        return;
    }
    CGPoint clickLocation = [sender locationInView:sender.view];
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        clickLocation = self.multitouchPrimaryTouchLocation;
    }
    switch (self.threeFingerTapType) {
        case VMGestureTypeRightClick:
            [self mouseClick:kCSInputButtonRight location:clickLocation];
            break;
        case VMGestureTypeMiddleClick:
            [self mouseClick:kCSInputButtonMiddle location:clickLocation];
            break;
        default:
            break;
    }
}

- (IBAction)gestureLongPress:(UILongPressGestureRecognizer *)sender {
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        if (sender.numberOfTouches != 1 && ![self isTerminalGestureState:sender.state]) {
            return;
        }
        CGPoint location = [sender locationInView:sender.view];
        if (sender.state == UIGestureRecognizerStateBegan) {
            self.multitouchLongPressRecognized = YES;
            self.multitouchLongPressPending = YES;
            self.multitouchLongPressDragging = NO;
            self.multitouchLongPressOrigin = location;
            self.multitouchPrimaryTouchLocation = location;
            [self.cursor startMovement:location];
            [self.cursor updateMovement:location];
            [self showLongPressIndicatorAtLocation:location];
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
            [self.clickFeedbackGenerator selectionChanged];
#endif
        } else if (sender.state == UIGestureRecognizerStateChanged) {
            if (self.multitouchLongPressPending && !self.multitouchLongPressDragging) {
                CGPoint delta = CGPointMake(location.x - self.multitouchLongPressOrigin.x,
                                            location.y - self.multitouchLongPressOrigin.y);
                if (hypot(delta.x, delta.y) >= kMultitouchDragThreshold) {
                    self.multitouchLongPressPending = NO;
                    self.multitouchLongPressDragging = YES;
                    [self dragCursor:UIGestureRecognizerStateBegan gestureType:self.longPressDragType];
                }
            }
            if (self.multitouchLongPressDragging) {
                [self.cursor updateMovement:location];
            }
        } else if (sender.state == UIGestureRecognizerStateEnded) {
            if (self.multitouchLongPressDragging) {
                [self dragCursor:UIGestureRecognizerStateEnded gestureType:self.longPressDragType];
            } else if (self.multitouchLongPressPending) {
                switch (self.longPressType) {
                    case VMGestureTypeRightClick:
                        [self mouseClick:kCSInputButtonRight location:self.multitouchLongPressOrigin];
                        break;
                    case VMGestureTypeMiddleClick:
                        [self mouseClick:kCSInputButtonMiddle location:self.multitouchLongPressOrigin];
                        break;
                    default:
                        break;
                }
            }
            self.multitouchLongPressRecognized = NO;
            self.multitouchLongPressPending = NO;
            self.multitouchLongPressDragging = NO;
        } else if (sender.state == UIGestureRecognizerStateCancelled ||
                   sender.state == UIGestureRecognizerStateFailed) {
            [self dragCursor:sender.state gestureType:self.longPressDragType];
            self.multitouchLongPressRecognized = NO;
            self.multitouchLongPressPending = NO;
            self.multitouchLongPressDragging = NO;
        }
        return;
    }
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.longPressType == VMGestureTypeRightClick) {
        [self mouseClick:kCSInputButtonRight location:[sender locationInView:sender.view]];
    } else if (self.longPressType == VMGestureTypeDragCursor) {
        [self dragCursor:sender.state primary:YES secondary:NO middle:NO];
    }
}

- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender {
    if (self.twoFingerPinchType != VMGestureTypeScaleDisplay) {
        return;
    }
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        if (sender.numberOfTouches != 2 && ![self isTerminalGestureState:sender.state]) {
            return;
        }
        if (sender.state == UIGestureRecognizerStateBegan) {
            self.multitouchPinchInitialDistance = [self pinchTouchDistance:sender];
            sender.scale = 1.0;
            return;
        } else if ([self isTerminalGestureState:sender.state]) {
            self.multitouchPinchActive = NO;
            self.multitouchPinchInitialDistance = 0.0f;
            return;
        }
        if (!self.multitouchPinchActive) {
            if (self.multitouchTwoPanActionStarted || self.multitouchThreePanConsumed) {
                return;
            }
            CGFloat distance = [self pinchTouchDistance:sender];
            if (self.multitouchPinchInitialDistance <= 0.0f) {
                self.multitouchPinchInitialDistance = distance;
                sender.scale = 1.0;
                return;
            }
            if (fabs(distance - self.multitouchPinchInitialDistance) < kMultitouchPinchStartDistance) {
                sender.scale = 1.0;
                return;
            }
            self.multitouchPinchActive = YES;
            self.multitouchTwoPanConsumed = YES;
            [self cancelMultitouchLongPress];
            [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
        }
    }
    if (sender.state == UIGestureRecognizerStateBegan ||
        sender.state == UIGestureRecognizerStateChanged) {
        NSAssert(sender.scale > 0, @"sender.scale cannot be 0");
        CGFloat scaling;
        if (!self.delegate.qemuDisplayIsNativeResolution) {
            scaling = CGPixelToPoint(self.view, CGPointToPixel(self.view, self.delegate.displayScale) * sender.scale);
        } else {
            scaling = self.delegate.displayScale * sender.scale;
        }
        self.delegate.displayIsZoomLocked = false;
        self.delegate.displayScale = scaling;
        sender.scale = 1.0;
    }
}

- (IBAction)gestureSwipeScroll:(UISwipeGestureRecognizer *)sender {
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        return;
    }
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.twoFingerScrollType == VMGestureTypeMouseWheel) {
        if (sender == self.swipeScrollUp) {
            [self.vmInput sendMouseScroll:kCSInputScrollUp buttonMask:self.mouseButtonDown dy:0];
        } else if (sender == self.swipeScrollDown) {
            [self.vmInput sendMouseScroll:kCSInputScrollDown buttonMask:self.mouseButtonDown dy:0];
        } else {
            NSAssert(0, @"Invalid call to gestureSwipeScroll");
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.tap && otherGestureRecognizer == self.twoTap) {
        return YES;
    }
    if (gestureRecognizer == self.tap && otherGestureRecognizer == self.threeTap) {
        return YES;
    }
    if (gestureRecognizer == self.twoTap && otherGestureRecognizer == self.twoPan) {
        return YES;
    }
    if (gestureRecognizer == self.threeTap && otherGestureRecognizer == self.threePan) {
        return YES;
    }
    if (gestureRecognizer == self.tap && otherGestureRecognizer == self.longPress) {
        return YES;
    }
    if (gestureRecognizer == self.pinch && otherGestureRecognizer == self.threePan) {
        return YES;
    }
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    return [self pencilGestureRecognizer:gestureRecognizer shouldRequireFailureOfGestureRecognizer:otherGestureRecognizer];
#else
    return NO;
#endif
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.pinch) {
        if (self.touchMouseType == VMMouseTypeMultitouch && self.pinch.numberOfTouches != 2) {
            return NO;
        }
        if (self.touchMouseType == VMMouseTypeMultitouch &&
            (self.multitouchTwoPanActionStarted ||
             self.threePan.state == UIGestureRecognizerStateBegan ||
             self.threePan.state == UIGestureRecognizerStateChanged)) {
            return NO;
        }
        return self.twoFingerPinchType == VMGestureTypeScaleDisplay;
    }
    if (self.touchMouseType == VMMouseTypeMultitouch) {
        if (gestureRecognizer == self.swipeScrollUp ||
            gestureRecognizer == self.swipeScrollDown) {
            return NO;
        }
        if (gestureRecognizer == self.longPress) {
            return self.longPress.numberOfTouches == 1 &&
                   self.multitouchLongPressTouchActive &&
                   (self.longPressType != VMGestureTypeNone ||
                    self.longPressDragType != VMGestureTypeNone);
        }
        if (gestureRecognizer == self.twoTap) {
            CGPoint panTranslation = [self.twoPan translationInView:self.twoPan.view];
            return !self.multitouchTwoPanConsumed &&
                   hypot(panTranslation.x, panTranslation.y) < kMultitouchDragThreshold;
        }
        if (gestureRecognizer == self.threeTap) {
            CGPoint panTranslation = [self.threePan translationInView:self.threePan.view];
            return !self.multitouchThreePanConsumed &&
                   hypot(panTranslation.x, panTranslation.y) < kMultitouchDragThreshold;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.pan && otherGestureRecognizer == self.longPress) {
        return YES;
    } else if (gestureRecognizer == self.longPress && otherGestureRecognizer == self.pan) {
        return YES;
    } else if (self.touchMouseType == VMMouseTypeMultitouch &&
               self.twoFingerPinchType == VMGestureTypeScaleDisplay &&
               ((gestureRecognizer == self.twoPan && otherGestureRecognizer == self.pinch) ||
                (gestureRecognizer == self.pinch && otherGestureRecognizer == self.twoPan))) {
        if (self.multitouchTwoPanActionStarted) {
            return NO;
        }
        return YES;
    } else if (self.twoFingerScrollType == VMGestureTypeNone && otherGestureRecognizer == self.twoPan) {
        // if two finger swipe is disabled, we can also recognize two finger pans
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveEvent:(UIEvent *)event API_AVAILABLE(ios(13.4)) {
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
        NSUInteger activeDirectTouches = [self activeDirectTouchCountForEvent:event currentTouches:touches];
        if (self.touchMouseType == VMMouseTypeMultitouch &&
            activeDirectTouches == touches.count &&
            !self.vmInput.serverModeCursor) {
            [self resetMultitouchSequence];
        }
        if (self.touchMouseType == VMMouseTypeMultitouch &&
            !self.vmInput.serverModeCursor) {
            self.multitouchActiveDirectTouchCount = activeDirectTouches;
        }
        if (self.touchMouseType == VMMouseTypeMultitouch &&
            activeDirectTouches > 1 &&
            !self.vmInput.serverModeCursor) {
            [self cancelMultitouchLongPress];
        }
        for (UITouch *touch in touches) {
            VMMouseType type = [self touchTypeToMouseType:touch.type];
#if TARGET_OS_VISION
            if ([self isTouchGazeGesture:touch]) {
                type = VMMouseTypeRelative;
            }
#endif
            if ([self switchMouseType:type]) {
                [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES]; // reset drag
            } else if (!self.vmInput.serverModeCursor) { // start click for client mode
                if (type == VMMouseTypeMultitouch && touch.type == UITouchTypeDirect) {
                    CGPoint pos = [touch locationInView:self.mtkView];
                    if (!self.multitouchPrimaryTouch) {
                        self.multitouchPrimaryTouch = touch;
                        self.multitouchPrimaryTouchLocation = pos;
                        self.multitouchLongPressOrigin = pos;
                        self.multitouchLongPressTouchActive = activeDirectTouches == 1;
                        self.multitouchLongPressPending = NO;
                        self.multitouchLongPressDragging = NO;
                        self.multitouchLongPressCancelledByMovement = activeDirectTouches > 1;
                        [self.cursor startMovement:pos];
                        [self.cursor updateMovement:pos];
                        [self.scroll startMovement:pos];
                        self.multitouchScrollLastLocation = pos;
                        self.multitouchScrollVelocity = CGPointZero;
                        self.multitouchScrollLastTime = touch.timestamp;
                    }
                    break;
                }
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
        if (self.touchMouseType == VMMouseTypeMultitouch) {
            NSUInteger activeDirectTouches = [self activeDirectTouchCountForEvent:event currentTouches:touches];
            if (self.multitouchTwoPanConsumed ||
                self.multitouchThreePanConsumed ||
                self.multitouchPinchActive) {
                [super touchesMoved:touches withEvent:event];
                return;
            }
            if (activeDirectTouches != 1) {
                if (activeDirectTouches > 1) {
                    [self cancelMultitouchLongPress];
                }
                [super touchesMoved:touches withEvent:event];
                return;
            }
            for (UITouch *touch in touches) {
                if (touch.type != UITouchTypeDirect) {
                    continue;
                }
                if (self.multitouchPrimaryTouch && touch != self.multitouchPrimaryTouch) {
                    continue;
                }
                CGPoint pos = [touch locationInView:self.mtkView];
                if (!self.multitouchLongPressRecognized &&
                    !self.multitouchLongPressPending &&
                    !self.multitouchLongPressDragging) {
                    NSTimeInterval elapsed = touch.timestamp - self.multitouchScrollLastTime;
                    if (elapsed > 0) {
                        self.multitouchScrollVelocity = CGPointMake((pos.x - self.multitouchScrollLastLocation.x) / elapsed,
                                                                    (pos.y - self.multitouchScrollLastLocation.y) / elapsed);
                    }
                    self.multitouchScrollLastLocation = pos;
                    self.multitouchScrollLastTime = touch.timestamp;
                    [self.scroll updateMovement:pos];
                }
                break;
            }
            [super touchesMoved:touches withEvent:event];
            return;
        }
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
        [super touchesCancelled:touches withEvent:event];
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
        [self resetMultitouchSequence];
        return;
    }
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.delegate.qemuInputLegacy && !self.vmInput.serverModeCursor) {
        if (self.touchMouseType == VMMouseTypeMultitouch) {
            NSUInteger remainingDirectTouches = [self activeDirectTouchCountForEvent:event currentTouches:touches];
            NSUInteger endedDirectTouches = 0;
            for (UITouch *touch in touches) {
                if (touch.type == UITouchTypeDirect) {
                    endedDirectTouches++;
                }
            }
            if (endedDirectTouches >= self.multitouchActiveDirectTouchCount) {
                self.multitouchActiveDirectTouchCount = 0;
            } else {
                self.multitouchActiveDirectTouchCount -= endedDirectTouches;
            }
            if (event.allTouches) {
                remainingDirectTouches = MIN(remainingDirectTouches, self.multitouchActiveDirectTouchCount);
            } else {
                remainingDirectTouches = self.multitouchActiveDirectTouchCount;
            }
            [super touchesEnded:touches withEvent:event];
            if (self.multitouchTwoPanActionStarted &&
                (remainingDirectTouches == 0 || [self isTerminalGestureState:self.twoPan.state])) {
                [self dragCursor:UIGestureRecognizerStateEnded gestureType:self.twoFingerPanType];
                self.multitouchTwoPanActionStarted = NO;
            }
            if (self.multitouchThreePanActionStarted &&
                (remainingDirectTouches == 0 || [self isTerminalGestureState:self.threePan.state])) {
                [self dragCursor:UIGestureRecognizerStateEnded gestureType:self.threeFingerPanType];
                self.multitouchThreePanActionStarted = NO;
            }
            if (self.multitouchLongPressDragging && remainingDirectTouches == 0) {
                [self dragCursor:UIGestureRecognizerStateEnded gestureType:self.longPressDragType];
            }
            if (!self.multitouchLongPressRecognized &&
                !self.multitouchLongPressPending &&
                !self.multitouchLongPressDragging &&
                !self.multitouchTwoPanConsumed &&
                !self.multitouchThreePanConsumed) {
                [self.scroll endMovementWithVelocity:self.multitouchScrollVelocity resistance:kScrollResistance];
            }
            if (remainingDirectTouches == 0) {
                [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self resetMultitouchSequence];
                });
            }
            return;
        }
        [self dragCursor:UIGestureRecognizerStateEnded primary:YES secondary:YES middle:YES];
    }
    [super touchesEnded:touches withEvent:event];
}

@end
