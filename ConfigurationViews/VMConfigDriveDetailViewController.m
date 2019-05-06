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

#import "VMConfigDriveDetailViewController.h"
#import "UTMConfiguration.h"
#import "VMConfigDrivePickerViewController.h"

@interface VMConfigDriveDetailViewController ()

@end

@implementation VMConfigDriveDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshViewFromConfiguration];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.driveLocationPickerActive = NO;
    if (self.valid) {
        self.existingPathLabel.text = [self.configuration driveImagePathForIndex:self.driveIndex];
        self.isCdromSwitch.on = [self.configuration driveIsCdromForIndex:self.driveIndex];
        self.driveInterfaceType = [self.configuration driveInterfaceTypeForIndex:self.driveIndex];
    } else {
        self.driveInterfaceType = [UTMConfiguration defaultDriveInterface];
    }
}

#pragma mark - Properties

- (void)setDriveLocationPickerActive:(BOOL)driveLocationPickerActive {
    _driveLocationPickerActive = driveLocationPickerActive;
    [self pickerCell:self.driveLocationPickerCell setActive:driveLocationPickerActive];
}

- (void)setDriveInterfaceType:(NSString *)driveInterfaceType {
    _driveInterfaceType = driveInterfaceType;
    if (self.valid) {
        [self.configuration setDriveInterfaceType:driveInterfaceType forIndex:self.driveIndex];
    }
    self.driveLocationLabel.text = driveInterfaceType;
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveLocationCell) {
        self.driveLocationPickerActive = !self.driveLocationPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Picker delegate

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    if (pickerView == self.driveLocationPicker) {
        return 1;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.driveLocationPicker) {
        return [UTMConfiguration supportedDriveInterfaces].count;
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.driveLocationPicker) {
        return [UTMConfiguration supportedDriveInterfaces][row];
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.driveLocationPicker) {
        self.driveInterfaceType = [UTMConfiguration supportedDriveInterfaces][row];
    } else {
        NSAssert(0, @"Invalid picker");
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"selectDiskSegue"]) {
        NSAssert([segue.destinationViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid segue destination");
        id<UTMConfigurationDelegate> controller = (id<UTMConfigurationDelegate>)segue.destinationViewController;
        controller.configuration = self.configuration;
    }
}

- (IBAction)unwindToDriveDetailFromDrivePicker:(UIStoryboardSegue*)sender {
    NSAssert([sender.sourceViewController isKindOfClass:[VMConfigDrivePickerViewController class]], @"Invalid segue destination");
    VMConfigDrivePickerViewController *source = (VMConfigDrivePickerViewController *)sender.sourceViewController;
    if (!self.valid) {
        self.valid = YES;
        self.driveIndex = [self.configuration newDrive:source.selectedName interface:self.driveInterfaceType isCdrom:self.isCdromSwitch.on];
    } else {
        [self.configuration setImagePath:source.selectedName forIndex:self.driveIndex];
    }
}

#pragma mark - Event handlers

- (IBAction)isCdromSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.isCdromSwitch, @"Invalid sender");
    if (self.valid) {
        [self.configuration setDriveIsCdrom:sender.on forIndex:self.driveIndex];
    }
}

@end
