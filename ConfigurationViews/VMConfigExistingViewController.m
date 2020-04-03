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
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"

@interface VMConfigExistingViewController ()

@end

@implementation VMConfigExistingViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.nameReadOnly) {
        self.nameField.enabled = NO;
    }
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.nameField.text = self.configuration.name;
    self.debugLogSwitch.on = self.configuration.debugLogEnabled;
    self.saveButton.enabled = self.configuration.name && ![self.configuration.name isEqualToString:@""];
}

- (void)setNameReadOnly:(BOOL)nameReadOnly {
    self.nameField.enabled = !nameReadOnly;
    _nameReadOnly = nameReadOnly;
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Cell Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.exportLogCell) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self exportLog];
    }
}

- (void)exportLog {
    NSURL *path;
    if (self.configuration.existingPath) {
        path = [self.configuration.existingPath URLByAppendingPathComponent:[UTMConfiguration debugLogName]];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path.path]) {
        [self showAlert:NSLocalizedString(@"No debug log found!", @"VMConfigExistingViewController") completion:nil];
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
            [self showAlert:err.localizedDescription completion:nil];
        }
    }
}

#pragma mark - Event handlers

- (IBAction)screenTapped:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.view endEditing:YES];
    }
}

- (IBAction)nameFieldChanged:(UITextField *)sender {
    NSAssert(sender == self.nameField, @"Invalid sender");
    // TODO: input validation
    configuration.name = sender.text;
    self.saveButton.enabled = ![sender.text isEqualToString:@""];
}

- (IBAction)cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)debugLogSwitchChanged:(UISwitch *)sender {
    self.configuration.debugLogEnabled = sender.on;
}

@end
