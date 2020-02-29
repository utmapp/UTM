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

#import "VMSoftKeyboardView.h"

const int kLargeAccessoryViewHeight = 68;
const int kSmallAccessoryViewHeight = 45;
const int kSafeAreaHeight = 25;

@implementation VMSoftKeyboardView

- (UIView *)inputView {
    return nil; // default keyboard
}

- (void)setSoftKeyboardVisible:(BOOL)softKeyboardVisible {
    _softKeyboardVisible = softKeyboardVisible;
    [self updateAccessoryViewHeight];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAccessoryViewHeight];
}

- (void)updateAccessoryViewHeight {
    CGRect currentFrame = self.inputAccessoryView.frame;
    CGFloat height;
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
        // we want large keys
        height = kLargeAccessoryViewHeight;
    } else {
        height = kSmallAccessoryViewHeight;
    }
    if (self.softKeyboardVisible) {
        height += kSafeAreaHeight;
    }
    if (height != currentFrame.size.height) {
        currentFrame.size.height = height;
        self.inputAccessoryView.frame = currentFrame;
        [self reloadInputViews];
    }
}

@end
