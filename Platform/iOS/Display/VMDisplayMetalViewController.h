//
// Copyright © 2019 osy. All rights reserved.
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

#import <UIKit/UIKit.h>
#import "VMDisplayViewController.h"
#if !defined(WITH_USB)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

@class VMKeyboardView;
@class VMKeyboardButton;

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController : VMDisplayViewController

@property (strong, nonatomic) IBOutlet UIInputView *inputAccessoryView;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyModifierButtons;

@property (nonatomic) IBOutlet CSMTKView *mtkView;
@property (nonatomic) IBOutlet VMKeyboardView *keyboardView;

@property (nonatomic, nullable) CSInput *vmInput;
@property (nonatomic) CSDisplay *vmDisplay;

@property (nonatomic, readonly) BOOL serverModeCursor;

@property (nonatomic, strong) NSMutableArray<UIKeyCommand *> *mutableKeyCommands;

@property (nonatomic) BOOL isDynamicResolutionSupported;

- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithDisplay:(CSDisplay *)display input:(nullable CSInput *)input NS_DESIGNATED_INITIALIZER;

- (void)sendExtendedKey:(CSInputKey)type code:(int)code;
- (void)setDisplayScaling:(CGFloat)scaling origin:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
