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

#import "VMConfigViewController.h"

@interface VMConfigViewController ()

@end

@implementation VMConfigViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.insertTableViewRowAnimation = UITableViewRowAnimationMiddle;
    self.deleteTableViewRowAnimation = UITableViewRowAnimationMiddle;
    self.reloadTableViewRowAnimation = UITableViewRowAnimationMiddle;
    [self refreshViewFromConfiguration];
    self.doneLoadingConfiguration = YES;
}

- (void)refreshViewFromConfiguration {
    NSAssert(self.configuration, @"Configuration is nil!");
}

#pragma mark - Picker helpers

- (void)pickerCell:(nonnull UITableViewCell *)pickerCell setActive:(BOOL)active {
    [self cell:pickerCell setHidden:!active];
    [self reloadDataAnimated:self.doneLoadingConfiguration];
}

#pragma mark - Text field helpers
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)]) {
        id<UTMConfigurationDelegate> dst = (id<UTMConfigurationDelegate>)segue.destinationViewController;
        dst.configuration = self.configuration;
    }
}

#pragma mark - Showing Alerts

- (void)showAlert:(NSString *)msg completion:(nullable void (^)(UIAlertAction *action))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:completion];
    [alert addAction:okay];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end
