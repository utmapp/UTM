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

#import "VMDisplayMetalViewController.h"
#import <TargetConditionals.h>

@class VMCursor;
@class VMScroll;
@class GCController;

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController ()

// cursor handling
@property (nonatomic) CGPoint lastTwoPanOrigin;
@property (nonatomic) BOOL mouseLeftDown;
@property (nonatomic) BOOL mouseRightDown;
@property (nonatomic) BOOL mouseMiddleDown;
@property (nonatomic) BOOL pencilForceRightClickOnce;
@property (nonatomic, nullable) VMCursor *cursor;
@property (nonatomic, nullable) VMScroll *scroll;

// Gestures
@property (nonatomic, nullable) UISwipeGestureRecognizer *swipeUp;
@property (nonatomic, nullable) UISwipeGestureRecognizer *swipeDown;
@property (nonatomic, nullable) UISwipeGestureRecognizer *swipeScrollUp;
@property (nonatomic, nullable) UISwipeGestureRecognizer *swipeScrollDown;
@property (nonatomic, nullable) UIPanGestureRecognizer *pan;
@property (nonatomic, nullable) UIPanGestureRecognizer *twoPan;
@property (nonatomic, nullable) UIPanGestureRecognizer *threePan;
@property (nonatomic, nullable) UITapGestureRecognizer *tap;
@property (nonatomic, nullable) UITapGestureRecognizer *tapPencil;
@property (nonatomic, nullable) UITapGestureRecognizer *twoTap;
@property (nonatomic, nullable) UILongPressGestureRecognizer *longPress;
@property (nonatomic, nullable) UIPinchGestureRecognizer *pinch;

//Gamepad
@property (nonatomic, nullable) GCController *controller;

#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
// Feedback generators
@property (nonatomic, nullable) UISelectionFeedbackGenerator *clickFeedbackGenerator;
#endif

@end

NS_ASSUME_NONNULL_END

static inline CGFloat CGPointToPixel(CGFloat point) {
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    return point * 2.0;
#else
    return point * [UIScreen mainScreen].nativeScale; // FIXME: multiple screens?
#endif
}

static inline CGFloat CGPixelToPoint(CGFloat pixel) {
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    return pixel / 2.0;
#else
    return pixel / [UIScreen mainScreen].nativeScale; // FIXME: multiple screens?
#endif
}
