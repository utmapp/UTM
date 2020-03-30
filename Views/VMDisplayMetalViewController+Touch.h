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

typedef NS_ENUM(NSInteger, VMGestureType) {
    VMGestureTypeNone,
    VMGestureTypeDragCursor,
    VMGestureTypeRightClick,
    VMGestureTypeMoveScreen,
    VMGestureTypeMouseWheel,
    VMGestureTypeMax
};

typedef NS_ENUM(NSInteger, VMMouseType) {
    VMMouseTypeRelative,
    VMMouseTypeAbsolute,
    VMMouseTypeAbsoluteHideCursor
};

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController (Gestures)

@property (nonatomic, readonly) VMGestureType longPressType;
@property (nonatomic, readonly) VMGestureType twoFingerTapType;
@property (nonatomic, readonly) VMGestureType twoFingerPanType;
@property (nonatomic, readonly) VMGestureType twoFingerScrollType;
@property (nonatomic, readonly) VMGestureType threeFingerPanType;
@property (nonatomic, readonly) VMMouseType touchMouseType;
@property (nonatomic, readonly) VMMouseType pencilMouseType;
@property (nonatomic, readonly) VMMouseType indirectMouseType;

- (void)initTouch;

- (CGPoint)clipCursorToDisplay:(CGPoint)pos;
- (CGPoint)moveMouseAbsolute:(CGPoint)location;
- (CGPoint)moveMouseRelative:(CGPoint)translation;

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender;
- (IBAction)gestureTwoPan:(UIPanGestureRecognizer *)sender;
- (IBAction)gestureThreePan:(UIPanGestureRecognizer *)sender;
- (IBAction)gestureTap:(UITapGestureRecognizer *)sender;
- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender;
- (IBAction)gestureLongPress:(UILongPressGestureRecognizer *)sender;
- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender;
- (IBAction)gestureSwipeUp:(UISwipeGestureRecognizer *)sender;
- (IBAction)gestureSwipeDown:(UISwipeGestureRecognizer *)sender;
- (IBAction)gestureSwipeScroll:(UISwipeGestureRecognizer *)sender;

@end

NS_ASSUME_NONNULL_END
