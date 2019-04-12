//
// Copyright © 2019 Halts. All rights reserved.
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

- (void)changeState:(VMState)state withScreen:(nullable UIImage *)image {
    [[self screenButton] setImage:image forState:UIControlStateNormal];
    switch (state) {
        case kStopped:
        default: {
            [[self statusIndicator] stopAnimating];
            [[self screenBlurEffect] setHidden:NO];
            [[self playButton] setImage:[UIImage imageNamed:@"Play Icon"] forState:UIControlStateNormal];
            break;
        }
        case kStarting:
        case kPausing:
        case kResuming:
        case kStopping: {
            [[self screenBlurEffect] setHidden:NO];
            [[self statusIndicator] startAnimating];
            [[self playButton] setImage:nil forState:UIControlStateNormal];
            break;
        }
        case kStarted:
        case kResumed: {
            [[self screenBlurEffect] setHidden:YES];
            [[self statusIndicator] stopAnimating];
            [[self playButton] setImage:nil forState:UIControlStateNormal];
            break;
        }
        case kPaused: {
            [[self statusIndicator] stopAnimating];
            [[self screenBlurEffect] setHidden:NO];
            [[self playButton] setImage:[UIImage imageNamed:@"Resume Icon"] forState:UIControlStateNormal];
            break;
        }
    }
}

- (void)changeState:(VMState)state {
    [self changeState:state withScreen:nil];
}

- (void)setName:(NSString *)name {
    [[self nameLabel] setText:name];
}

- (IBAction)playButtonAction:(id)sender {
    NSLog(@"button clicked!\n");
}

- (IBAction)screenButtonAction:(id)sender {
    NSLog(@"button 2 clicked!\n");
}

- (IBAction)editAction:(id)sender {
    NSLog(@"edit clicked!\n");
}

@end
