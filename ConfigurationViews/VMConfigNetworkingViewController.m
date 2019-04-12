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

#import "VMConfigNetworkingViewController.h"

@interface VMConfigNetworkingViewController ()

@end

@implementation VMConfigNetworkingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.networkingEnabledSwitch.on = self.configuration.networkEnabled;
    self.localAccessOnlySwitch.on = self.configuration.networkLocalhostOnly;
    self.networkAddressField.text = self.configuration.networkIPSubnet;
    self.dhcpStartField.text = self.configuration.networkDHCPStart;
}

#pragma mark - Event handlers

- (IBAction)networkingEnabledSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.networkingEnabledSwitch, @"Invalid sender");
    self.configuration.networkEnabled = sender.on;
}

- (IBAction)localAccessOnlySwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.localAccessOnlySwitch, @"Invalid sender");
    self.configuration.networkLocalhostOnly = sender.on;
}

- (IBAction)networkAddressFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.networkAddressField, @"Invalid sender");
    self.configuration.networkIPSubnet = sender.text; // TODO: input validation
}

- (IBAction)dhcpStartFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.dhcpStartField, @"Invalid sender");
    self.configuration.networkDHCPStart = sender.text; // TODO: input validation
}

@end
