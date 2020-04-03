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

#import "VMConfigDrivesViewController.h"
#import "VMConfigDriveDetailViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"

@interface VMConfigDrivesViewController ()

@end

@implementation VMConfigDrivesViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItems = @[ self.addButtonItem, self.editButtonItem ];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshViewFromConfiguration];
}

- (void)refreshViewFromConfiguration {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section.");
    return self.configuration.countDrives;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"existingDrive" forIndexPath:indexPath];
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSAssert(cell, @"Invalid cell");
    
    cell.textLabel.text = [self.configuration driveImagePathForIndex:indexPath.row];
    UTMDiskImageType type = [self.configuration driveImageTypeForIndex:indexPath.row];
    NSString *typeStr = [UTMConfiguration supportedImageTypesPretty][type];
    NSString *interface = [self.configuration driveInterfaceTypeForIndex:indexPath.row];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", typeStr, interface];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *name = [self.configuration driveImagePathForIndex:indexPath.row];
        [self.configuration removeDriveAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self promptDelete:name];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    NSAssert(fromIndexPath.section == 0, @"Invalid section");
    NSAssert(toIndexPath.section == 0, @"Invalid section");
    [self.configuration moveDriveIndex:fromIndexPath.row to:toIndexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"existingDrive"]) {
        NSIndexPath *idxPath = [self.tableView indexPathForCell:sender];
        NSAssert(idxPath, @"No index path for this segue");
        NSAssert(idxPath.section == 0, @"Bad index path section");
        NSAssert(idxPath.row < configuration.countDrives, @"Index row exceeds number of drives.");
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDriveDetailViewController class]], @"Invalid segue destination");
        VMConfigDriveDetailViewController *view = (VMConfigDriveDetailViewController *)segue.destinationViewController;
        view.configuration = self.configuration;
        view.driveIndex = idxPath.row;
        view.valid = YES;
    } else if ([segue.identifier isEqualToString:@"newDrive"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDriveDetailViewController class]], @"Invalid segue destination");
        VMConfigDriveDetailViewController *view = (VMConfigDriveDetailViewController *)segue.destinationViewController;
        view.configuration = self.configuration;
        view.valid = NO;
    }
}

#pragma mark - Delete Disk

- (void)showAlert:(NSString *)msg completion:(nullable void (^)(UIAlertAction *action))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:completion];
    [alert addAction:okay];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)promptDelete:(NSString *)name {
    NSURL *path;
    if (self.configuration.existingPath) {
        path = [self.configuration.existingPath URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    } else {
        path = [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete Data", @"VMConfigDrivesViewController") message:NSLocalizedString(@"Do you want to also delete the disk image data? If yes, the data will be lost. Otherwise, you can create a new drive with the existing data.", @"VMConfigDrivesViewController") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *delete = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes button") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        NSError *err;
        [[NSFileManager defaultManager] removeItemAtURL:[path URLByAppendingPathComponent:name] error:&err];
        if (err) {
            [self showAlert:err.localizedDescription completion:nil];
        }
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No button") style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:delete];
    [alert addAction:cancel];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end
