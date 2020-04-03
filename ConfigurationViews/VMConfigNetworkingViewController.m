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

#import "VMConfigNetworkingViewController.h"
#import "VMConfigSwitch.h"

@interface VMConfigNetworkingViewController ()

@end

@implementation VMConfigNetworkingViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showNetworkOptions:self.networkEnabledSwitch.on animated:NO];
}

- (void)showNetworkOptions:(BOOL)visible animated:(BOOL)animated {
    if (!visible) {
        [self hidePickersAnimated:animated];
    }
    [self cells:self.networkEnabledCells setHidden:!visible];
    [self reloadDataAnimated:animated];
}

- (IBAction)configTextFieldEditEnd:(VMConfigTextField *)sender {
    // TODO: validate user input
    [super configTextFieldEditEnd:sender];
}

- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender {
    if (sender == self.networkEnabledSwitch) {
        [self showNetworkOptions:sender.on animated:YES];
    }
    [super configSwitchChanged:sender];
}

@end
