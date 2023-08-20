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
#import "VMDisplayMetalViewController+Private.h"
#import "VMDisplayMetalViewController+Pencil.h"
#import "VMDisplayMetalViewController+Touch.h"

NS_AVAILABLE_IOS(12.1)
@implementation VMDisplayMetalViewController (Pencil)

- (void)initPencilInteraction {
    self.tapPencil = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pencilGestureTap:)];
    self.tapPencil.delegate = self;
    self.tapPencil.allowedTouchTypes = @[ @(UITouchTypePencil) ];
    self.tapPencil.cancelsTouchesInView = NO;
    [self.mtkView addGestureRecognizer:self.tapPencil];
    UIPencilInteraction *interaction = [[UIPencilInteraction alloc] init];
    interaction.delegate = self;
    [self.mtkView addInteraction:interaction];
}

#pragma mark - UIPencilInteractionDelegate implementation
- (void)pencilInteractionDidTap:(UIPencilInteraction *)interaction {
    // ignore interaction type as we only support one action:
    // switching to right click for the next click
    self.pencilForceRightClickOnce = true;
}

#pragma mark - UITapGestureRecognizer

- (IBAction)pencilGestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded &&
        self.serverModeCursor) { // otherwise we handle in touchesBegan
        
        CSInputButton button = kCSInputButtonLeft;
        
        if (@available(iOS 12.1, *)) {
            if (self.pencilForceRightClickOnce) {
                button = kCSInputButtonRight;
                self.pencilForceRightClickOnce = false;
            }
        }
        
        [self mouseClick:button location:[sender locationInView:sender.view]];
    }
}

- (BOOL)pencilGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.tapPencil && otherGestureRecognizer == self.twoTap) {
        return YES;
    }
    if (gestureRecognizer == self.longPress && otherGestureRecognizer == self.tapPencil) {
        return YES;
    }
    return NO;
}

- (BOOL)pencilRightClickForTouch:(UITouch *)touch {
    if (touch.type == UITouchTypePencil) {
        BOOL hasRightClick = self.pencilForceRightClickOnce;
        self.pencilForceRightClickOnce = NO;
        return hasRightClick;
    } else {
        return NO;
    }
}

@end
