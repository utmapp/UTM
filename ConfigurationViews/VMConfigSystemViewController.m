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

#import "VMConfigSystemViewController.h"
#import "UTMConfiguration.h"

@interface VMConfigSystemViewController ()

@end

@implementation VMConfigSystemViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.architecturePickerActive = NO;
    self.bootPickerActive = NO;
    self.systemPickerActive = NO;
    self.architectureLabel.text = self.configuration.systemArchitecture;
    self.bootLabel.text = self.configuration.systemBootDevice;
    self.systemLabel.text = self.configuration.systemTarget;
    self.additionalArgsField.text = self.configuration.systemAddArgs;
    self.memorySize = self.configuration.systemMemory;
    self.cpuCount = self.configuration.systemCPUCount;
}

#pragma mark - Properties

- (void)setArchitecturePickerActive:(BOOL)architecturePickerActive {
    _architecturePickerActive = architecturePickerActive;
    if (architecturePickerActive) {
        NSUInteger index = [[UTMConfiguration supportedArchitectures] indexOfObject:self.architectureLabel.text];
        if (index != NSNotFound) {
            [self.architecturePicker selectRow:index inComponent:0 animated:NO];
        }
    }
    [self pickerCell:self.architecturePickerCell setActive:architecturePickerActive];
}

- (void)setBootPickerActive:(BOOL)bootPickerActive {
    _bootPickerActive = bootPickerActive;
    if (bootPickerActive) {
        NSUInteger index = [[UTMConfiguration supportedBootDevices] indexOfObject:self.bootLabel.text];
        if (index != NSNotFound) {
            [self.bootPicker selectRow:index inComponent:0 animated:NO];
        }
    }
    [self pickerCell:self.bootPickerCell setActive:bootPickerActive];
}

- (void)setSystemPickerActive:(BOOL)systemPickerActive {
    _systemPickerActive = systemPickerActive;
    if (systemPickerActive) {
        NSUInteger index = [[UTMConfiguration supportedTargetsForArchitecture:@"FIXME: arch here"] indexOfObject:self.systemLabel.text];
        if (index != NSNotFound) {
            [self.systemPicker selectRow:index inComponent:0 animated:NO];
        }
    }
    [self pickerCell:self.systemPickerCell setActive:systemPickerActive];
}

- (void)setMemorySize:(NSNumber *)memorySize {
    self.memorySizeField.text = [memorySize stringValue];
}

- (NSNumber *)memorySize {
    return [NSNumber numberWithLong:[self.memorySizeField.text integerValue]];
}

- (void)setCpuCount:(NSNumber *)cpuCount {
    self.cpuCountField.text = [cpuCount stringValue];
}

- (NSNumber *)cpuCount {
    return [NSNumber numberWithLong:[self.cpuCountField.text integerValue]];
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.architectureCell) {
        self.architecturePickerActive = !self.architecturePickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.bootCell) {
        self.bootPickerActive = !self.bootPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.systemCell) {
        self.systemPickerActive = !self.systemPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    if (pickerView == self.architecturePicker) {
        return 1;
    } else if (pickerView == self.bootPicker) {
        return 1;
    } else if (pickerView == self.systemPicker) {
        return 1;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

#pragma mark - Picker delegate

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.architecturePicker) {
        return [UTMConfiguration supportedArchitecturesPretty].count;
    } else if (pickerView == self.bootPicker) {
        return [UTMConfiguration supportedBootDevices].count;
    } else if (pickerView == self.systemPicker) {
        return [UTMConfiguration supportedTargetsForArchitecture:@"FIXME: arch here"].count;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.architecturePicker) {
        return [UTMConfiguration supportedArchitecturesPretty][row];
    } else if (pickerView == self.bootPicker) {
        return [UTMConfiguration supportedBootDevices][row];
    } else if (pickerView == self.systemPicker) {
        return [UTMConfiguration supportedTargetsForArchitecture:@"FIXME: arch here"][row];
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.architecturePicker) {
        self.architectureLabel.text = [UTMConfiguration supportedArchitecturesPretty][row];
        self.configuration.systemArchitecture = self.architectureLabel.text;
    } else if (pickerView == self.bootPicker) {
        self.bootLabel.text = [UTMConfiguration supportedBootDevices][row];
        self.configuration.systemBootDevice = self.bootLabel.text;
    } else if (pickerView == self.systemPicker) {
        self.systemLabel.text = [UTMConfiguration supportedTargetsForArchitecture:@"FIXME: arch here"][row];
        self.configuration.systemTarget = self.systemLabel.text;
    } else {
        NSAssert(0, @"Invalid picker");
    }
}

#pragma mark - Event handlers

- (void)memorySizeFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.memorySizeField, @"Invalid sender");
    NSNumber *memorySize = self.memorySize;
    if (memorySize.intValue > 0) {
        self.configuration.systemMemory = memorySize;
    } else {
        // TODO: error handler
    }
}

- (void)cpuCountFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.cpuCountField, @"Invalid sender");
    NSNumber *num = self.cpuCount;
    if (num.intValue > 0) {
        self.configuration.systemCPUCount = num;
    } else {
        // TODO: error handler
    }
}

- (IBAction)additionalArgsFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.additionalArgsField, @"Invalid sender");
    self.configuration.systemAddArgs = sender.text;
}

@end
