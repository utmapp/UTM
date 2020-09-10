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

#import "UIKit/UIKit.h"
#import "VMDisplayMetalViewController.h"
#import "VMDisplayMetalViewController+Pencil.h"

NS_AVAILABLE_IOS(12.1)
@implementation VMDisplayMetalViewController (Pencil)

- (void)initPencilInteraction {
    UIPencilInteraction *interaction = [[UIPencilInteraction alloc] init];
    interaction.delegate = self;
    [self.mtkView addInteraction:interaction];
}

#pragma mark - UIPencilInteractionDelegate implementation
- (void)pencilInteractionDidTap:(UIPencilInteraction *)interaction {
    // ignore interaction type as we only support one action:
    // switching to right click for the next click
    _pencilForceRightClickOnce = true;
}

@end
