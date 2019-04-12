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

#import "VMConfigCreateViewController.h"

@interface VMConfigCreateViewController ()

@end

@implementation VMConfigCreateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.advancedConfiguration = NO;
    self.nameField.text = self.configuration.name;
}

#pragma mark - Event handlers

- (IBAction)cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(id)sender {
}

- (IBAction)nameFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.nameField, @"Invalid sender");
    // TODO: validate input
    self.configuration.name = sender.text;
}

@end
