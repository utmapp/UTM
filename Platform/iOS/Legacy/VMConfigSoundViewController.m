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

#import "VMConfigSoundViewController.h"
#import "UTMConfiguration.h"
#import "VMConfigSwitch.h"

@interface VMConfigSoundViewController ()

@end

@implementation VMConfigSoundViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showSoundOptions:self.soundEnabledSwitch.on animated:NO];
}

- (void)showSoundOptions:(BOOL)visible animated:(BOOL)animated {
    if (!visible) {
        [self hidePickersAnimated:animated];
    }
    [self cells:self.soundEnabledCells setHidden:!visible];
    [self reloadDataAnimated:animated];
}

- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender {
    if (sender == self.soundEnabledSwitch) {
        [self showSoundOptions:sender.on animated:YES];
    }
    [super configSwitchChanged:sender];
}

@end
