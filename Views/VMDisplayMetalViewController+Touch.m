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
#import "VMDisplayMetalViewController+Touch.h"
#import "VMCursor.h"
#import "CSDisplayMetal.h"
#import "UTMConfiguration.h"
#import "UTMSpiceIO.h"
#import "UTMVirtualMachine.h"

@implementation VMDisplayMetalViewController (Gestures)

- (void)initTouch {
    // mouse cursor
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    _cursor = [[VMCursor alloc] initWithVMViewController:self];
    
    // Set up gesture recognizers because Storyboards is BROKEN and doing it there crashes!
    _swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeUp:)];
    _swipeUp.numberOfTouchesRequired = 3;
    _swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeUp.delegate = self;
    _swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeDown:)];
    _swipeDown.numberOfTouchesRequired = 3;
    _swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeDown.delegate = self;
    _swipeScrollUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    _swipeScrollUp.numberOfTouchesRequired = 2;
    _swipeScrollUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeScrollUp.delegate = self;
    _swipeScrollDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    _swipeScrollDown.numberOfTouchesRequired = 2;
    _swipeScrollDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeScrollDown.delegate = self;
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePan:)];
    _pan.minimumNumberOfTouches = 1;
    _pan.maximumNumberOfTouches = 1;
    _pan.delegate = self;
    _pan.cancelsTouchesInView = NO;
    _twoPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoPan:)];
    _twoPan.minimumNumberOfTouches = 2;
    _twoPan.maximumNumberOfTouches = 2;
    _twoPan.delegate = self;
    _threePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureThreePan:)];
    _threePan.minimumNumberOfTouches = 3;
    _threePan.maximumNumberOfTouches = 3;
    _threePan.delegate = self;
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    _tap.delegate = self;
    _tap.cancelsTouchesInView = NO;
    _twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoTap:)];
    _twoTap.numberOfTouchesRequired = 2;
    _twoTap.delegate = self;
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(gestureLongPress:)];
    _longPress.delegate = self;
    _pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    _pinch.delegate = self;
    [self.mtkView addGestureRecognizer:_swipeUp];
    [self.mtkView addGestureRecognizer:_swipeDown];
    [self.mtkView addGestureRecognizer:_swipeScrollUp];
    [self.mtkView addGestureRecognizer:_swipeScrollDown];
    [self.mtkView addGestureRecognizer:_pan];
    [self.mtkView addGestureRecognizer:_twoPan];
    [self.mtkView addGestureRecognizer:_threePan];
    [self.mtkView addGestureRecognizer:_tap];
    [self.mtkView addGestureRecognizer:_twoTap];
    [self.mtkView addGestureRecognizer:_longPress];
    [self.mtkView addGestureRecognizer:_pinch];
    
    // Feedback generator for clicks
    _clickFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    _resizeFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] init];
}

#pragma mark - Properties from settings

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

- (VMGestureType)threeFingerPanType {
    return [self gestureTypeForSetting:@"GestureThreePan"];
}

- (VMMouseType)mouseTypeForSetting:(NSString *)key {
    NSInteger integer = [self integerForSetting:key];
    if (integer < VMGestureTypeNone || integer >= VMGestureTypeMax) {
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
    return [self mouseTypeForSetting:@"MouseIndirectType"];
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

static CGFloat CGPointToPixel(CGFloat point) {
    return point * [UIScreen mainScreen].scale; // FIXME: multiple screens?
}

- (CGPoint)clipCursorToDisplay:(CGPoint)pos {
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
    pos.x /= self.vmDisplay.viewportScale;
    pos.y /= self.vmDisplay.viewportScale;
    return pos;
}

- (CGPoint)clipDisplayToView:(CGPoint)target {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmDisplay.displaySize.width * self.vmDisplay.viewportScale,
        self.vmDisplay.displaySize.height * self.vmDisplay.viewportScale
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
        [_cursor startMovement:location];
        [_animator removeAllBehaviors];
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        [_cursor updateMovement:location];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        UIDynamicItemBehavior *behavior = [[UIDynamicItemBehavior alloc] initWithItems:@[ _cursor ]];
        [behavior addLinearVelocity:velocity forItem:_cursor];
        behavior.resistance = 50;
        [_animator addBehavior:behavior];
    }
}

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender {
    if (self.serverModeCursor) {  // otherwise we handle in touchesMoved
        [self moveMouseWithInertia:sender];
    }
}

- (void)moveScreen:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        _lastTwoPanOrigin = self.vmDisplay.viewportOrigin;
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        CGPoint translation = [sender translationInView:sender.view];
        CGPoint viewport = self.vmDisplay.viewportOrigin;
        viewport.x = CGPointToPixel(translation.x) + _lastTwoPanOrigin.x;
        viewport.y = CGPointToPixel(translation.y) + _lastTwoPanOrigin.y;
        self.vmDisplay.viewportOrigin = [self clipDisplayToView:viewport];
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
            [self dragCursor:sender.state];
            [self moveMouseWithInertia:sender];
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
            [self dragCursor:sender.state];
            [self moveMouseWithInertia:sender];
            break;
        default:
            break;
    }
}

- (CGPoint)moveMouseAbsolute:(CGPoint)location {
    CGPoint translated = location;
    translated.x = CGPointToPixel(translated.x);
    translated.y = CGPointToPixel(translated.y);
    translated = [self clipCursorToDisplay:translated];
    if (!self.vmInput.serverModeCursor) {
        [self.vmInput sendMouseMotion:(_mouseDown ? SEND_BUTTON_LEFT : SEND_BUTTON_NONE) point:translated];
        [self.vmInput forceCursorPosition:translated]; // required to show cursor on screen
    } else {
        NSLog(@"Warning: ignored mouse set (%f, %f) while mouse is in server mode", translated.x, translated.y);
    }
    return translated;
}

- (CGPoint)moveMouseRelative:(CGPoint)translation {
    translation.x = CGPointToPixel(translation.x) / self.vmDisplay.viewportScale;
    translation.y = CGPointToPixel(translation.y) / self.vmDisplay.viewportScale;
    if (self.vmInput.serverModeCursor) {
        [self.vmInput sendMouseMotion:(_mouseDown ? SEND_BUTTON_LEFT : SEND_BUTTON_NONE) point:translation];
    } else {
        NSLog(@"Warning: ignored mouse motion (%f, %f) while mouse is in client mode", translation.x, translation.y);
    }
    return translation;
}

- (void)mouseClick:(SendButtonType)button location:(CGPoint)location {
    if (!self.serverModeCursor) {
        _cursor.center = location;
    }
    [self.vmInput sendMouseButton:button pressed:YES point:CGPointZero];
    [self onDelay:0.05f action:^{
        self->_mouseDown = NO;
        [self.vmInput sendMouseButton:button pressed:NO point:CGPointZero];
    }];
    [_clickFeedbackGenerator selectionChanged];
}

- (void)dragCursor:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan) {
        [_clickFeedbackGenerator selectionChanged];
        _mouseDown = YES;
        [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:YES point:CGPointZero];
    } else if (state == UIGestureRecognizerStateEnded) {
        _mouseDown = NO;
        [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:NO point:CGPointZero];
    }
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.serverModeCursor) { // otherwise we handle in touchesBegan
        [self mouseClick:SEND_BUTTON_LEFT location:[sender locationInView:sender.view]];
    }
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.twoFingerTapType == VMGestureTypeRightClick) {
        [self mouseClick:SEND_BUTTON_RIGHT location:[sender locationInView:sender.view]];
    }
}

- (IBAction)gestureLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.longPressType == VMGestureTypeRightClick) {
        [self mouseClick:SEND_BUTTON_RIGHT location:[sender locationInView:sender.view]];
    } else if (self.longPressType == VMGestureTypeDragCursor) {
        [self dragCursor:sender.state];
    }
}

- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender {
    self.vmDisplay.viewportScale *= sender.scale;
    sender.scale = 1.0;
}

- (IBAction)gestureSwipeUp:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.toolbarVisible) {
            self.toolbarVisible = NO;
        } else if (!self.keyboardVisible) {
            self.keyboardVisible = YES;
        }
    }
}

- (IBAction)gestureSwipeDown:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.keyboardVisible) {
            self.keyboardVisible = NO;
        } else if (!self.toolbarVisible) {
            self.toolbarVisible = YES;
        }
    }
}

- (IBAction)gestureSwipeScroll:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.twoFingerScrollType == VMGestureTypeMouseWheel) {
        if (sender == _swipeScrollUp) {
            [self.vmInput sendMouseScroll:SEND_SCROLL_UP button:SEND_BUTTON_NONE dy:0];
        } else if (sender == _swipeScrollDown) {
            [self.vmInput sendMouseScroll:SEND_SCROLL_DOWN button:SEND_BUTTON_NONE dy:0];
        } else {
            NSAssert(0, @"Invalid call to gestureSwipeScroll");
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeScrollUp) {
        return YES;
    }
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeScrollDown) {
        return YES;
    }
    if (gestureRecognizer == _twoTap && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _twoTap && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _tap && otherGestureRecognizer == _twoTap) {
        return YES;
    }
    if (gestureRecognizer == _longPress && otherGestureRecognizer == _tap) {
        return YES;
    }
    if (gestureRecognizer == _longPress && otherGestureRecognizer == _twoTap) {
        return YES;
    }
    if (gestureRecognizer == _pinch && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _pinch && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _pan && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _pan && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _threePan && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _threePan && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _pinch) {
        if (self.twoFingerPanType == VMGestureTypeMoveScreen) {
            return YES;
        } else {
            return NO;
        }
    } else if (gestureRecognizer == _pan && otherGestureRecognizer == _longPress) {
        return YES;
    } else {
        return NO;
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
        case UITouchTypeIndirect:
        default: { // covers UITouchTypeIndirectPointer
            return self.indirectMouseType;
        }
    }
}

- (BOOL)switchMouseType:(VMMouseType)type {
    BOOL shouldHideCursor = (type == VMMouseTypeAbsoluteHideCursor);
    BOOL shouldUseServerMouse = (type == VMMouseTypeRelative);
    self.vmInput.inhibitCursor = shouldHideCursor;
    if (shouldUseServerMouse != self.vmInput.serverModeCursor) {
        NSLog(@"Switching mouse mode to server:%d for type:%ld", shouldUseServerMouse, type);
        [self.vm requestInputTablet:!shouldUseServerMouse completion:^(NSString *res, NSError *err) {
            if (err) {
                NSLog(@"input select returned error: %@", err);
            } else {
                [self.spiceIO.primaryInput requestMouseMode:shouldUseServerMouse];
            }
        }];
        return YES;
    }
    return NO;
}

#pragma mark - Touch event handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.vmConfiguration.inputLegacy) {
        for (UITouch *touch in [event touchesForView:self.mtkView]) {
            VMMouseType type = [self touchTypeToMouseType:touch.type];
            if ([self switchMouseType:type]) {
                [self dragCursor:UIGestureRecognizerStateEnded]; // reset drag
            } else if (!self.vmInput.serverModeCursor) { // start click for client mode
                CGPoint pos = [touch locationInView:self.mtkView];
                [_cursor startMovement:pos];
                [_cursor updateMovement:pos];
                [self dragCursor:UIGestureRecognizerStateBegan];
            }
            break; // handle a single touch only
        }
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // move cursor in client mode, in server mode we handle in gesturePan
    if (!self.vmConfiguration.inputLegacy && !self.vmInput.serverModeCursor) {
        for (UITouch *touch in [event touchesForView:self.mtkView]) {
            [_cursor updateMovement:[touch locationInView:self.mtkView]];
            break; // handle single touch
        }
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.vmConfiguration.inputLegacy && !self.vmInput.serverModeCursor) {
        [self dragCursor:UIGestureRecognizerStateEnded];
    }
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // release click in client mode, in server mode we handle in gesturePan
    if (!self.vmConfiguration.inputLegacy && !self.vmInput.serverModeCursor) {
        [self dragCursor:UIGestureRecognizerStateEnded];
    }
    [super touchesEnded:touches withEvent:event];
}

@end
