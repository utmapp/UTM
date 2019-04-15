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

#import "VMConfigInputViewController.h"
#import "UTMConfiguration.h"

@interface VMConfigInputViewController ()

@end

@implementation VMConfigInputViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.inputTouchscreenMode = self.configuration.inputTouchscreenMode;
    self.inputDirect = self.configuration.inputDirect;
}

#pragma mark - Properties

- (void)setInputTouchscreenMode:(BOOL)inputTouchscreenMode {
    _inputTouchscreenMode = inputTouchscreenMode;
    self.configuration.inputTouchscreenMode = inputTouchscreenMode;
    if (inputTouchscreenMode) {
        [self.pointerStyleTouchscreenCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.pointerStyleTrackpadCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.pointerStyleTouchscreenCell setSelected:NO animated:YES];
    } else {
        [self.pointerStyleTouchscreenCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.pointerStyleTrackpadCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.pointerStyleTrackpadCell setSelected:NO animated:YES];
    }
}

- (void)setInputDirect:(BOOL)inputDirect {
    _inputDirect = inputDirect;
    self.configuration.inputDirect = inputDirect;
    if (inputDirect) {
        [self.inputReceiverDirectCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.inputReceiverServerCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.inputReceiverDirectCell setSelected:NO animated:YES];
    } else {
        [self.inputReceiverDirectCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.inputReceiverServerCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.inputReceiverServerCell setSelected:NO animated:YES];
    }
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.pointerStyleTouchscreenCell) {
        self.inputTouchscreenMode = YES;
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.pointerStyleTrackpadCell) {
        self.inputTouchscreenMode = NO;
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.inputReceiverDirectCell) {
        self.inputDirect = YES;
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.inputReceiverServerCell) {
        self.inputDirect = NO;
    }
}

@end
