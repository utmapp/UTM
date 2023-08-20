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
#import "CSInput.h"

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
    VMMouseTypeAbsoluteHideCursor,
    VMMouseTypeMax
};

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController (Gestures) <UIGestureRecognizerDelegate>

@property (nonatomic, readonly) CSInputButton mouseButtonDown;
@property (nonatomic, readonly) VMMouseType touchMouseType;
@property (nonatomic, readonly) VMMouseType pencilMouseType;
@property (nonatomic, readonly) VMMouseType indirectMouseType;

- (void)initTouch;

- (CGPoint)clipCursorToDisplay:(CGPoint)pos;
- (CGPoint)moveMouseAbsolute:(CGPoint)location;
- (CGPoint)moveMouseRelative:(CGPoint)translation;
- (CGPoint)moveMouseScroll:(CGPoint)translation;
- (void)scrollWithInertia:(UIPanGestureRecognizer *)sender;
- (void)mouseClick:(CSInputButton)button location:(CGPoint)location;

@end

NS_ASSUME_NONNULL_END
