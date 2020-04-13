//
// Copyright © 2020 osy. All rights reserved.
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

#import "VMConfigDirectoryPickerViewController.h"
#import "UIViewController+Extensions.h"
#import "UTMVirtualMachine.h"

@interface VMConfigDirectoryPickerViewController ()

@property (nonatomic, readonly) NSURL *documentsPath;
@property (nonatomic) NSMutableArray<NSURL *> *items;
@property (nonatomic, nullable) UITableViewCell *selectedCell;

@end

@implementation VMConfigDirectoryPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshList];
    self.navigationItem.rightBarButtonItems = @[ self.addButtonItem, self.editButtonItem ];
}

- (void)tableView:(UITableView *)tableView selectCell:(UITableViewCell *)selectedCell {
    if (self.selectedCell) {
        self.selectedCell.accessoryType = UITableViewCellAccessoryNone;
    }
    selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
    self.selectedCell = selectedCell;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section");
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"directoryItemCell" forIndexPath:indexPath];
    
    cell.textLabel.text = self.items[indexPath.row].lastPathComponent;
    if ([self.selectedDirectory isEqual:self.items[indexPath.row]]) {
        [self tableView:tableView selectCell:cell];
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
        NSURL *url = self.items[indexPath.row];
        [self deleteDirectory:url success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (url == self.selectedDirectory) {
                    self.selectedDirectory = nil;
                    self.selectedCell = nil;
                }
                [self.items removeObjectAtIndex:indexPath.row];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            });
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self tableView:tableView selectCell:cell];
    self.selectedDirectory = self.items[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self performSegueWithIdentifier:@"returnToShareSegue" sender:self];
}

#pragma mark - Directory listing

- (NSURL *)documentsPath {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)refreshList {
    NSArray<NSURL *> *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.documentsPath
                                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                error:nil];
    self.items = [[dirs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary<NSString *,id> * _Nullable bindings) {
        NSNumber *isDir;
        [object getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
        return [isDir boolValue] && ![UTMVirtualMachine URLisVirtualMachine:object];
    }]] mutableCopy];
    [self.tableView reloadData];
}

- (void)createDirectory {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Create Directory", @"VMConfigDirectoryPickerViewController")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Directory Name", @"VMConfigDirectoryPickerViewController");
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"VMConfigDirectoryPickerViewController")
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Done", @"VMConfigDirectoryPickerViewController")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSError *err;
        NSURL *url = [self.documentsPath URLByAppendingPathComponent:alertController.textFields[0].text];
        [[NSFileManager defaultManager] createDirectoryAtURL:url
                                 withIntermediateDirectories:NO
                                                  attributes:nil
                                                       error:&err];
        if (err) {
            [self showAlert:err.localizedDescription actions:nil completion:nil];
        }
        [self refreshList];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)deleteDirectory:(NSURL *)url success:(nullable void (^)(void))completion {
    UIAlertAction *delete = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", @"VMConfigDirectoryPickerViewController")
                                                     style:UIAlertActionStyleDestructive
                                                   handler:^(UIAlertAction * _Nonnull action) {
        NSError *err = nil;
        [[NSFileManager defaultManager] removeItemAtURL:url error:&err];
        if (err) {
            [self showAlert:err.localizedDescription actions:nil completion:nil];
        } else {
            completion();
        }
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"VMConfigDirectoryPickerViewController")
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to delete this directory? All files and subdirectories WILL be deleted.", @"VMConfigDirectoryPickerViewController")
            actions:@[cancel, delete]
         completion:nil];
}

#pragma mark - Event handlers

- (void)addButton:(UIBarButtonItem *)sender {
    [self createDirectory];
}

@end
