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

#import "VMConfigDrivesViewController.h"
#import "VMConfigDriveDetailViewController.h"
#import "UTMConfiguration.h"

@interface VMConfigDrivesViewController ()

@end

@implementation VMConfigDrivesViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItems = @[ self.addButtonItem, self.editButtonItem ];
}

- (void)viewDidAppear:(BOOL)animated {
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
    cell.detailTextLabel.text = [self.configuration driveInterfaceTypeForIndex:indexPath.row];
    if ([self.configuration driveIsCdromForIndex:indexPath.row]) {
        cell.imageView.image = [UIImage imageNamed:@"Media Icon"];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"HDD Icon"];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.configuration removeDriveAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
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
    } else if ([segue.identifier isEqualToString:@"newDrive"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDriveDetailViewController class]], @"Invalid segue destination");
        VMConfigDriveDetailViewController *view = (VMConfigDriveDetailViewController *)segue.destinationViewController;
        view.configuration = self.configuration;
        view.driveIndex = [self.configuration newDefaultDrive];
    }
}

@end
