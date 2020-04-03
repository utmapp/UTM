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

@interface VMConfigDisplayViewController ()

@end

@implementation VMConfigDisplayViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    // FIXME: remove this warning
    [self showUnimplementedAlert];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.consoleOnly = self.configuration.displayConsoleOnly;
    self.maxResolutionPickerActive = NO;
    self.maxResolutionLabel.text = self.maxResolution;
    self.resolutionFixedSwitch.on = self.configuration.displayFixedResolution;
    self.zoomScaleFitSwitch.on = self.configuration.displayZoomScale;
    self.zoomLetterboxSwitch.on = self.configuration.displayZoomLetterBox;
}

#pragma mark - Properties

- (void)setMaxResolutionPickerActive:(BOOL)maxResolutionPickerActive {
    _maxResolutionPickerActive = maxResolutionPickerActive;
    if (maxResolutionPickerActive) {
        NSUInteger index = [[UTMConfiguration supportedResolutions] indexOfObject:self.maxResolution];
        if (index != NSNotFound) {
            [self.maxResolutionPicker selectRow:index inComponent:0 animated:NO];
        }
    }
    [self pickerCell:self.maxResolutionPickerCell setActive:maxResolutionPickerActive];
}

- (void)setConsoleOnly:(BOOL)consoleOnly {
    _consoleOnly = consoleOnly;
    self.configuration.displayConsoleOnly = consoleOnly;
    if (consoleOnly) {
        [self cells:self.displayTypeCells setHidden:YES];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self cells:self.consoleTypeCells setHidden:NO];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self.graphicsTypeFullCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.graphicsTypeConsoleCell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [self cells:self.consoleTypeCells setHidden:YES];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self cells:self.displayTypeCellsWithoutPicker setHidden:NO];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        _maxResolutionPickerActive = NO; // reset picker
        [self.graphicsTypeFullCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.graphicsTypeConsoleCell setAccessoryType:UITableViewCellAccessoryNone];
    }
}

- (void)setMaxResolution:(NSString *)maxResolution {
    NSArray<NSString *> *parts = [maxResolution componentsSeparatedByString:@"x"];
    self.configuration.displayFixedResolutionWidth = @([parts[0] integerValue]);
    self.configuration.displayFixedResolutionHeight = @([parts[1] integerValue]);
}

- (NSString *)maxResolution {
    return [NSString stringWithFormat:@"%@x%@", self.configuration.displayFixedResolutionWidth, self.configuration.displayFixedResolutionHeight];
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.graphicsTypeFullCell) {
        self.consoleOnly = NO;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.graphicsTypeConsoleCell) {
        self.consoleOnly = YES;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.maxResolutionCell) {
        self.maxResolutionPickerActive = !self.maxResolutionPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Picker delegate

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    if (pickerView == self.maxResolutionPicker) {
        return 1;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.maxResolutionPicker) {
        return [UTMConfiguration supportedResolutions].count;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.maxResolutionPicker) {
        return [UTMConfiguration supportedResolutions][row];
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.maxResolutionPicker) {
        self.maxResolutionLabel.text = [UTMConfiguration supportedResolutions][row];
        self.maxResolution = self.maxResolutionLabel.text;
    } else {
        NSAssert(0, @"Invalid picker");
    }
}

#pragma mark - Event handlers

- (IBAction)resolutionFixedSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.resolutionFixedSwitch, @"Invalid sender");
    self.configuration.displayFixedResolution = sender.on;
}

- (IBAction)zoomScaleFitSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.zoomScaleFitSwitch, @"Invalid sender");
    self.configuration.displayZoomScale = sender.on;
}

- (IBAction)zoomLetterboxSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.zoomLetterboxSwitch, @"Invalid sender");
    self.configuration.displayZoomLetterBox = sender.on;
}

@end
