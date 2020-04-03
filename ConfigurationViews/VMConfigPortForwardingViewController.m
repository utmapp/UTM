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

#import "VMConfigPortForwardingViewController.h"
#import "UTMConfiguration+Networking.h"
#import "UTMConfigurationPortForward.h"

@interface VMConfigPortForwardingViewController ()

@end

@implementation VMConfigPortForwardingViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItems = @[ self.addButtonItem, self.editButtonItem ];
}

- (void)refreshViewFromConfiguration {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section");
    return [self.configuration countPortForwards];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"portForwardCell" forIndexPath:indexPath];
    UTMConfigurationPortForward *portForward = [self.configuration portForwardForIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@:%ld ➡️ %@:%ld", portForward.hostAddress, portForward.hostPort, portForward.guestAddress, portForward.guestPort];
    cell.detailTextLabel.text = portForward.protocol;
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.configuration removePortForwardAtIndex:indexPath.row];
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    UTMConfigurationPortForward *portForward = [self.configuration portForwardForIndex:indexPath.row];
    if (portForward) {
        [self createPortForwardFormTCP:[portForward.protocol isEqualToString:@"tcp"]
                              existing:portForward
                               atIndex:indexPath.row];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Add new port

- (void)createPortForwardFormTCP:(BOOL)tcp {
    [self createPortForwardFormTCP:tcp existing:nil atIndex:0];
}

- (void)createPortForwardFormTCP:(BOOL)tcp existing:(nullable UTMConfigurationPortForward *)existing atIndex:(NSUInteger)index {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:tcp ? NSLocalizedString(@"TCP Forward", @"VMConfigPortForwardingViewController") : NSLocalizedString(@"UDP Forward", @"VMConfigPortForwardingViewController")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Host address (optional)", @"VMConfigPortForwardingViewController");
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = existing.hostAddress;
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Host port (required)", @"VMConfigPortForwardingViewController");
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = existing ? [@(existing.hostPort) stringValue] : @"";
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Guest address (optional)", @"VMConfigPortForwardingViewController");
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = existing.guestAddress;
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Guest port (required)", @"VMConfigPortForwardingViewController");
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = existing ? [@(existing.guestPort) stringValue] : @"";
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"VMConfigPortForwardingViewController")
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Done", @"VMConfigPortForwardingViewController")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        UTMConfigurationPortForward *portForward = [[UTMConfigurationPortForward alloc] init];
        portForward.protocol = tcp ? @"tcp" : @"udp";
        portForward.hostAddress = alertController.textFields[0].text;
        portForward.hostPort = [alertController.textFields[1].text integerValue];
        portForward.guestAddress = alertController.textFields[2].text;
        portForward.guestPort = [alertController.textFields[3].text integerValue];
        //TODO: validate input
        if (existing) {
            [self.configuration updatePortForwardAtIndex:index withValue:portForward];
        } else {
            [self.configuration newPortForward:portForward];
        }
        [self.tableView reloadData];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Event handlers

- (IBAction)addButton:(UIBarButtonItem *)sender {
    UIAlertController *newForward = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"New port forward", @"VMConfigPortForwardingViewController")
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    [newForward addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TCP Forward", @"VMConfigPortForwardingViewController")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self createPortForwardFormTCP:YES];
    }]];
    [newForward addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"UDP Forward", @"VMConfigPortForwardingViewController")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self createPortForwardFormTCP:NO];
    }]];
    [self presentViewController:newForward animated:YES completion:nil];
}

@end
