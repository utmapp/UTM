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

#import "VMConfigSharingViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Sharing.h"
#import "VMConfigSwitch.h"

@interface VMConfigSharingViewController ()

@end

@implementation VMConfigSharingViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showShareDirectoryOptions:self.shareDirectoryEnabledSwitch.on animated:NO];
}

- (void)showShareDirectoryOptions:(BOOL)visible animated:(BOOL)animated {
    [self cells:self.directorySharingCells setHidden:!visible];
    if (self.configuration.shareDirectoryName.length == 0) {
        self.shareDirectoryNameLabel.text = NSLocalizedString(@"Browse...", @"VMConfigSharingViewController");
    }
    [self reloadDataAnimated:animated];
}

- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender {
    if (sender == self.shareDirectoryEnabledSwitch) {
        [self showShareDirectoryOptions:sender.on animated:YES];
        if (!sender.on) {
            self.configuration.shareDirectoryName = @"";
            self.configuration.shareDirectoryBookmark = [NSData data];
        }
    }
    [super configSwitchChanged:sender];
}

@end
