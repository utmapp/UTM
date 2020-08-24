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

#import "VMConfigDrivePickerViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "VMConfigDriveCreateViewController.h"

@interface VMConfigDrivePickerViewController ()

@property (nonatomic, strong) NSMutableArray<NSURL *> *images;

@end

@implementation VMConfigDrivePickerViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshViewFromConfiguration];
    self.navigationItem.rightBarButtonItems = @[ self.addButtonItem, self.editButtonItem ];
}

- (void)viewWillAppear:(BOOL)animated {
    [self refreshList];
    [super viewWillAppear:animated];
}

- (void)refreshViewFromConfiguration {
    if (self.configuration.existingPath) {
        self.imagesPath = [self.configuration.existingPath URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    } else {
        self.imagesPath = [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section.");
    return self.images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"diskImageCell" forIndexPath:indexPath];
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSAssert(cell, @"Invalid cell");
    
    cell.textLabel.text = self.images[indexPath.row].lastPathComponent;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteDiskImage:self.images[indexPath.row] forCell:[tableView cellForRowAtIndexPath:indexPath] success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.images removeObjectAtIndex:indexPath.row];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            });
        }];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return NO;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier:@"editDiskImageSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _selectedName = self.images[indexPath.row].lastPathComponent;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self performSegueWithIdentifier:@"returnToDetailSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
}

#pragma mark - Document picker delegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSAssert(urls.count == 1, @"Invalid number of items picked.");
    NSError *err;
    NSURL *dstUrl = [self.imagesPath URLByAppendingPathComponent:urls[0].lastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.imagesPath.path]) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:self.imagesPath withIntermediateDirectories:NO attributes:nil error:&err]) {
            [self showAlert:err.localizedDescription completion:nil];
        }
    }
    if (!err && ![[NSFileManager defaultManager] moveItemAtURL:urls[0] toURL:dstUrl error:&err]) {
        [self showAlert:err.localizedDescription completion:nil];
    } else {
        [self refreshList];
    }
    
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"newDiskImageSegue"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDriveCreateViewController class]], @"Invalid segue destination");
        VMConfigDriveCreateViewController *view = (VMConfigDriveCreateViewController *)segue.destinationViewController;
        view.configuration = self.configuration;
        view.imagesPath = self.imagesPath;
    } else if ([segue.identifier isEqualToString:@"editDiskImageSegue"]) {
        NSIndexPath *idxPath = [self.tableView indexPathForCell:sender];
        NSAssert(idxPath, @"No index path for this segue");
        NSAssert(idxPath.section == 0, @"Bad index path section");
        NSAssert(idxPath.row < self.images.count, @"Index row exceeds number of images.");
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDriveCreateViewController class]], @"Invalid segue destination");
        VMConfigDriveCreateViewController *view = (VMConfigDriveCreateViewController *)segue.destinationViewController;
        view.configuration = self.configuration;
        view.imagesPath = self.imagesPath;
        view.existingPath = self.images[idxPath.row];
    }
}

#pragma mark - Operations

- (void)showAlert:(NSString *)msg completion:(nullable void (^)(UIAlertAction *action))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:completion];
    [alert addAction:okay];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)refreshList {
    NSArray<NSURL *> *images = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.imagesPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    if (images) {
        self.images = [NSMutableArray<NSURL *> arrayWithArray:images];
    }
    [self.tableView reloadData];
}

- (void)deleteDiskImage:(NSURL *)path forCell:(nullable UITableViewCell *)cell success:(nullable void (^)(void))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"Are you sure you want to permanently delete this disk image?", @"VMConfigDrivePickerViewController") preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *delete = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", @"Delete button") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        NSError *err;
        [[NSFileManager defaultManager] removeItemAtURL:path error:&err];
        if (err) {
            [self showAlert:err.localizedDescription completion:nil];
        } else {
            completion();
        }
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button") style:UIAlertActionStyleCancel handler:nil];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;
    [alert addAction:delete];
    [alert addAction:cancel];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Event handlers

- (IBAction)addButton:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"Would you like to import an existing disk image or create a new one?", @"VMConfigDrivePickerViewController") preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *import = [UIAlertAction actionWithTitle:NSLocalizedString(@"Import", @"Import button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
        picker.delegate = self;
        picker.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:picker animated:YES completion:nil];
    }];
    UIAlertAction *create = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create", @"Create button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [self performSegueWithIdentifier:@"newDiskImageSegue" sender:action];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button") style:UIAlertActionStyleCancel handler:nil];
    alert.popoverPresentationController.barButtonItem = sender;
    [alert addAction:import];
    [alert addAction:create];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
