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
#import "VMKeyboardViewDelegate.h"

extern const int kLargeAccessoryViewHeight;
extern const int kSmallAccessoryViewHeight;
extern const int kSafeAreaHeight;

NS_ASSUME_NONNULL_BEGIN

@interface VMKeyboardView : UIView <UITextInputTraits, UIKeyInput>

@property (nonatomic, weak) IBOutlet id<VMKeyboardViewDelegate> delegate;
@property (nonatomic, readwrite, strong) IBOutlet UIView *inputAccessoryView;
@property (nonatomic, assign) BOOL softKeyboardVisible;

@end

NS_ASSUME_NONNULL_END
