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

#import "VMDisplayViewController.h"
#import "UTM-Swift.h"

@implementation VMDisplayViewController

#pragma mark - Properties

@synthesize prefersHomeIndicatorAutoHidden = _prefersHomeIndicatorAutoHidden;
@synthesize prefersPointerLocked = _prefersPointerLocked;

- (BOOL)prefersHomeIndicatorAutoHidden {
    return _prefersHomeIndicatorAutoHidden;
}

- (void)setPrefersHomeIndicatorAutoHidden:(BOOL)prefersHomeIndicatorAutoHidden {
    _prefersHomeIndicatorAutoHidden = prefersHomeIndicatorAutoHidden;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

- (BOOL)prefersPointerLocked {
    return _prefersPointerLocked;
}

- (void)setPrefersPointerLocked:(BOOL)prefersPointerLocked {
    _prefersPointerLocked = prefersPointerLocked;
    [self setNeedsUpdateOfPrefersPointerLocked];
}

- (void)showKeyboard {
    [self.view.window makeKeyWindow];
}

- (void)hideKeyboard {
    [self.view.window resignKeyWindow];
}

@end
