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

#import "VMConfigExistingViewController.h"
#import "UIViewController+Extensions.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "VMConfigTextField.h"

@interface VMConfigExistingViewController ()

@property (nonatomic, weak, readonly) NSString *version;

@end

@implementation VMConfigExistingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.nameReadOnly) {
        self.nameField.enabled = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.saveButton.enabled = self.configuration.name.length > 0;
    self.versionCell.detailTextLabel.text = self.version;
}

- (void)setNameReadOnly:(BOOL)nameReadOnly {
    self.nameField.enabled = !nameReadOnly;
    _nameReadOnly = nameReadOnly;
}

#pragma mark - Properties

- (NSString *)version {
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    return [infoDict objectForKey:@"CFBundleShortVersionString"];
}

#pragma mark - Cell Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.exportLogCell) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self exportLog];
    } else {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (void)exportLog {
    NSURL *path;
    if (self.configuration.existingPath) {
        path = [self.configuration.existingPath URLByAppendingPathComponent:[UTMConfiguration debugLogName]];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path.path]) {
        [self showAlert:NSLocalizedString(@"No debug log found!", @"VMConfigExistingViewController") actions:nil completion:nil];
    } else {
        NSError *err;
        NSURL *temp = [NSURL fileURLWithPathComponents:@[NSTemporaryDirectory(), [UTMConfiguration debugLogName]]];
        [[NSFileManager defaultManager] removeItemAtURL:temp error:nil];
        if ([[NSFileManager defaultManager] copyItemAtURL:path toURL:temp error:&err]) {
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[temp] applicationActivities:nil];
            activityViewController.popoverPresentationController.sourceView = self.exportLogCell;
            activityViewController.popoverPresentationController.sourceRect = self.exportLogCell.bounds;
            [self presentViewController:activityViewController animated:YES completion:nil];
        } else {
            [self showAlert:err.localizedDescription actions:nil completion:nil];
        }
    }
}

#pragma mark - Event handlers

- (IBAction)configTextEditChanged:(VMConfigTextField *)sender {
    [super configTextEditChanged:sender];
    if (sender == self.nameField) {
        // TODO: input validation
        self.saveButton.enabled = sender.text.length > 0;
        self.configuration.name = sender.text;
    }
}

- (IBAction)cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
