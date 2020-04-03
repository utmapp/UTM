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

#import "VMConfigSoundViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"

@interface VMConfigSoundViewController ()

@end

@implementation VMConfigSoundViewController

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.soundEnabled = self.configuration.soundEnabled;
    self.soundEnabledSwitch.on = self.soundEnabled;
    self.soundHardwareLabel.text = self.configuration.soundCard;
    self.soundHardwarePickerActive = NO;
}

#pragma mark - Properties

- (void)setSoundEnabled:(BOOL)soundEnabled {
    _soundEnabled = soundEnabled;
    self.configuration.soundEnabled = soundEnabled;
    if (!soundEnabled && self.soundHardwarePickerActive) {
        self.soundHardwarePickerActive = NO;
    }
    [self pickerCell:self.soundHardwareCell setActive:soundEnabled];
}

- (void)setSoundHardwarePickerActive:(BOOL)soundHardwarePickerActive {
    _soundHardwarePickerActive = soundHardwarePickerActive;
    if (soundHardwarePickerActive) {
        NSUInteger index = [[UTMConfiguration supportedSoundCardDevices] indexOfObject:self.configuration.soundCard];
        if (index != NSNotFound) {
            [self.soundCardPickerView selectRow:index inComponent:0 animated:NO];
        }
    }
    [self pickerCell:self.soundCardPickerViewTableViewCell setActive:soundHardwarePickerActive];
}

#pragma mark - View delegates

- (void)pickerCell:(nonnull UITableViewCell *)pickerCell setActive:(BOOL)active {
    [self cell:pickerCell setHidden:!active];
    [self reloadDataAnimated:self.doneLoadingConfiguration];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.soundHardwareCell) {
        self.soundHardwarePickerActive = !self.soundHardwarePickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    NSAssert(pickerView == self.soundCardPickerView, @"Invalid picker");
    return 1;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert(pickerView == self.soundCardPickerView, @"Invalid picker");
    return [UTMConfiguration supportedSoundCardDevices].count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert(pickerView == self.soundCardPickerView, @"Invalid picker");
    return [UTMConfiguration supportedSoundCardDevicesPretty][row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert(pickerView == self.soundCardPickerView, @"Invalid picker");
    self.configuration.soundCard = [UTMConfiguration supportedSoundCardDevices][row];
    self.soundHardwareLabel.text = self.configuration.soundCard;
}

#pragma mark - Event handlers

- (IBAction)soundEnabledSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.soundEnabledSwitch, @"Invalid sender");
    self.soundEnabled = sender.on;
}

@end
