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

#import "VMConfigSystemArgumentsViewController.h"
#import "VMConfigDriveDetailViewController.h"
#import "UTMConfiguration+System.h"

@interface VMConfigSystemArgumentsViewController ()

@end

@implementation VMConfigSystemArgumentsViewController

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
    NSInteger count = self.configuration.countArguments;
    
    // Insert an empty argument if there are no existing arguments.
    if (count == 0) {
        [self.configuration newArgument:@""];
        return count + 1;
    }
    
    return count;
}

- (VMConfigSystemArgumentsTextCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    VMConfigSystemArgumentsTextCell *cell = [tableView dequeueReusableCellWithIdentifier:@"argumentCell" forIndexPath:indexPath];
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSAssert(cell, @"Invalid cell");
    
    NSInteger row = indexPath.row;
    cell.argTextItem.tag = row;
    cell.argTextItem.text = [self.configuration argumentForIndex:row];
    cell.configuration = configuration;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // If there's only one argument, add a new item at 1 before deleting the first so we're never at 0 rows.
        if ([self.configuration countArguments] == 1) {
            [self.configuration updateArgumentAtIndex:0 withValue:@""];
        } else {
            // Delete the row and coorresponding argument.
            [self.configuration removeArgumentAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        [tableView reloadData];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    NSAssert(fromIndexPath.section == 0, @"Invalid section");
    NSAssert(toIndexPath.section == 0, @"Invalid section");
    [self.configuration moveArgumentIndex:fromIndexPath.row to:toIndexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    return YES;
}

- (IBAction)addButton:(id *)sender {
    // Insert a new empty argument.
    [self.configuration newArgument:@""];
    [self.tableView reloadData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // done button was pressed - dismiss keyboard
    [textField resignFirstResponder];
    return YES;
}

@end

#pragma mark - Text input from cell

@interface VMConfigSystemArgumentsTextCell()

@end

@implementation VMConfigSystemArgumentsTextCell
@synthesize configuration;

- (void)refreshViewFromConfiguration {
    // The table would update before we could do anything.
    return;
}

- (IBAction)editingDidEnd:(UITextField *)sender {
    [self.configuration updateArgumentAtIndex:sender.tag withValue:sender.text];
    [self.argTextItem endEditing:true];
}


- (IBAction)valueWasChanged:(UITextField *)sender {
    [self.argTextItem endEditing:true];
}

- (IBAction)touchWasCancelled:(UITextField *)sender {
    [self.argTextItem endEditing:true];
}

@end
