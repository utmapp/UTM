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
#if !defined(WITH_USB)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

@class VMCursor;
@class VMScroll;
@class GCController;

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController ()

@property (nonatomic, nullable) CSMetalRenderer *renderer;

// cursor handling
@property (nonatomic) CGPoint lastTwoPanOrigin;
@property (nonatomic) CGPoint lastLongPressOrigin;
@property (nonatomic) CGPoint lastTapLocation;
@property (nonatomic) NSTimeInterval lastTapTime;
@property (nonatomic) BOOL isTouchScrolling;
@property (nonatomic) BOOL mouseLeftDown;
@property (nonatomic) BOOL mouseRightDown;
@property (nonatomic) BOOL mouseMiddleDown;
@property (nonatomic) BOOL mouseSideDown;
@property (nonatomic) BOOL mouseExtraDown;
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

#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
/// The native scale of the screen the view is on, which can differ from the trait's scale on downsampled displays.
///
/// A device can have more than one screen so the view's own traits are used until it is in a window.
static inline CGFloat CGViewNativeScale(UIView * _Nonnull view) {
    UIScreen *screen = view.window.windowScene.screen;
    if (screen) {
        return screen.nativeScale;
    } else {
        return view.traitCollection.displayScale;
    }
}
#endif

static inline CGFloat CGPointToPixel(UIView * _Nonnull view, CGFloat point) {
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    return point * 2.0;
#else
    return point * CGViewNativeScale(view);
#endif
}

static inline CGFloat CGPixelToPoint(UIView * _Nonnull view, CGFloat pixel) {
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    return pixel / 2.0;
#else
    return pixel / CGViewNativeScale(view);
#endif
}
