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

#import "VMConfigDisplayViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+Display.h"

@interface VMConfigDisplayViewController ()

@end

@implementation VMConfigDisplayViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _consoleOnly = self.configuration.displayConsoleOnly;
    [self showConsoleOptions:_consoleOnly animated:NO];
    NSInteger fontSize = self.configuration.consoleFontSize.integerValue;
    self.fontSizeLabel.text = [NSString stringWithFormat:@"%ld", fontSize];
    [self refreshFontLabel];
}

- (void)showConsoleOptions:(BOOL)consoleOnly animated:(BOOL)animated {
    if (consoleOnly) {
        [self cells:self.fullDisplayCells setHidden:YES];
        [self cells:self.consoleDisplayCells setHidden:NO];
        [self.graphicsTypeFullCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.graphicsTypeConsoleCell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [self cells:self.consoleDisplayCells setHidden:YES];
        [self cells:self.fullDisplayCells setHidden:NO];
        [self.graphicsTypeFullCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.graphicsTypeConsoleCell setAccessoryType:UITableViewCellAccessoryNone];
    }
    [self hidePickersAnimated:animated];
}

- (void)refreshFontLabel {
    CGFloat size = self.fontPickerToggleCell.detailTextLabel.font.pointSize;
    self.fontPickerToggleCell.detailTextLabel.font = [UIFont fontWithName:self.configuration.consoleFont size:size];
}

#pragma mark - Properties

- (void)setConsoleOnly:(BOOL)consoleOnly {
    if (_consoleOnly == consoleOnly) {
        return;
    }
    _consoleOnly = consoleOnly;
    self.configuration.displayConsoleOnly = consoleOnly;
    [self showConsoleOptions:consoleOnly animated:YES];
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.graphicsTypeFullCell) {
        self.consoleOnly = NO;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else if ([tableView cellForRowAtIndexPath:indexPath] == self.graphicsTypeConsoleCell) {
        self.consoleOnly = YES;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

#pragma mark - Picker delegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [super pickerView:pickerView didSelectRow:row inComponent:component];
    if (pickerView == self.fontPicker) {
        [self refreshFontLabel];
    }
}

#pragma mark - Event handlers

- (IBAction)fontSizeStepperChanged:(UIStepper *)sender {
    NSAssert(sender == self.fontSizeStepper, @"Invalid sender");
    self.fontSizeLabel.text = [NSString stringWithFormat:@"%d", (int)sender.value];
}

@end
