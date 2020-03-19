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

#import "VMListViewCell.h"

@implementation VMListViewCell

- (void)changeState:(UTMVMState)state image:(nullable UIImage *)image {
    [[self screenButton] setImage:image forState:UIControlStateNormal];
    switch (state) {
        case kVMStopped:
        case kVMError:
        default: {
            [[self statusIndicator] stopAnimating];
            [[self screenBlurEffect] setHidden:NO];
            [[self playButton] setImage:[UIImage imageNamed:@"Play Icon"] forState:UIControlStateNormal];
            break;
        }
        case kVMStarting:
        case kVMPausing:
        case kVMResuming:
        case kVMStopping: {
            [[self screenBlurEffect] setHidden:NO];
            [[self statusIndicator] startAnimating];
            [[self playButton] setImage:nil forState:UIControlStateNormal];
            break;
        }
        case kVMStarted: {
            [[self screenBlurEffect] setHidden:YES];
            [[self statusIndicator] stopAnimating];
            [[self playButton] setImage:nil forState:UIControlStateNormal];
            break;
        }
        case kVMSuspended:
        case kVMPaused: {
            [[self statusIndicator] stopAnimating];
            [[self screenBlurEffect] setHidden:NO];
            [[self playButton] setImage:[UIImage imageNamed:@"Resume Icon"] forState:UIControlStateNormal];
            break;
        }
    }
}

#pragma mark - Context Menu Actions

- (void)sendAction:(id)sender action:(SEL)action {
    // find my collection view
    UIView* v = self;
    do {
        v = v.superview;
    } while (![v isKindOfClass:[UICollectionView class]]);
    UICollectionView* cv = (UICollectionView*) v;
    // ask it what index path we are
    NSIndexPath* ip = [cv indexPathForCell:self];
    // talk to its delegate
    if (cv.delegate &&
        [cv.delegate respondsToSelector:
         @selector(collectionView:performAction:forItemAtIndexPath:withSender:)]) {
        [cv.delegate collectionView:cv performAction:action
                 forItemAtIndexPath:ip withSender:sender];
    }
}

- (void)deleteAction:(id)sender {
    [self sendAction:sender action:_cmd];
}

- (void)cloneAction:(id)sender {
    [self sendAction:sender action:_cmd];
}

@end
