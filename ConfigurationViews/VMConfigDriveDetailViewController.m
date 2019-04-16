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

@interface VMConfigDriveDetailViewController ()

@end

@implementation VMConfigDriveDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.driveLocationPickerActive = NO;
    UTMNewDrive *driveParams = [self.configuration driveNewParamsAtIndex:self.driveIndex];
    self.driveImageExisting = !driveParams.valid;
    self.nonexistingImageSize = driveParams.sizeMB;
    self.nonexistingImageExpandingSwitch.on = driveParams.isQcow2;
    self.nonexistingPathName.text = [self.configuration driveImagePathForIndex:self.driveIndex];
    self.existingPathLabel.text = [self.configuration driveImagePathForIndex:self.driveIndex];
    self.isCdromSwitch.on = [self.configuration driveIsCdromForIndex:self.driveIndex];
    self.driveInterfaceType = [self.configuration driveInterfaceTypeForIndex:self.driveIndex];
}

#pragma mark - Properties

- (void)setDriveLocationPickerActive:(BOOL)driveLocationPickerActive {
    _driveLocationPickerActive = driveLocationPickerActive;
    [self pickerCell:self.driveLocationPickerCell setActive:driveLocationPickerActive];
}

- (void)setDriveImageExisting:(BOOL)driveImageExisting {
    _driveImageExisting = driveImageExisting;
    if (driveImageExisting) {
        [self cells:self.nonexistingImageCells setHidden:YES];
        [self cells:self.existingImageCells setHidden:NO];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self.driveTypeExistingCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.driveTypeNewCell setAccessoryType:UITableViewCellAccessoryNone];
    } else {
        [self cells:self.existingImageCells setHidden:YES];
        [self cells:self.nonexistingImageCells setHidden:NO];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self.driveTypeExistingCell setAccessoryType:UITableViewCellAccessoryNone];
        [self.driveTypeNewCell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
}

- (void)setDriveInterfaceType:(NSString *)driveInterfaceType {
    _driveInterfaceType = driveInterfaceType;
    [self.configuration setDriveInterfaceType:driveInterfaceType forIndex:self.driveIndex];
    self.driveLocationLabel.text = driveInterfaceType;
}

- (NSUInteger)nonexistingImageSize {
    return [self.nonexistingImageSizeField.text intValue];
}

- (void)setNonexistingImageSize:(NSUInteger)nonexistingImageSize {
    self.nonexistingImageSizeField.text = [NSString stringWithFormat:@"%lu", nonexistingImageSize];
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveLocationCell) {
        self.driveLocationPickerActive = !self.driveLocationPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveTypeExistingCell) {
        UTMNewDrive *driveParams = [self.configuration driveNewParamsAtIndex:self.driveIndex];
        self.driveImageExisting = YES;
        driveParams.valid = NO;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveTypeNewCell) {
        UTMNewDrive *driveParams = [self.configuration driveNewParamsAtIndex:self.driveIndex];
        self.driveImageExisting = NO;
        driveParams.valid = YES;
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

#pragma mark - Event handlers

- (IBAction)nonexistingImageExpandingSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.nonexistingImageExpandingSwitch, @"Invalid sender");
    [self.configuration driveNewParamsAtIndex:self.driveIndex].isQcow2 = sender.on;
}

- (IBAction)existingImageMakeCopySwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.existingImageMakeCopySwitch, @"Invalid sender");
    // TODO: implement me
}

- (IBAction)nonexistingPathNameChanged:(UITextField *)sender {
    NSAssert(sender == self.nonexistingPathName, @"Invalid sender");
    [self.configuration setImagePath:sender.text forIndex:self.driveIndex];
}

- (IBAction)nonexistingImageSizeChanged:(UITextField *)sender {
    NSAssert(sender == self.nonexistingImageSizeField, @"Invalid sender");
    [self.configuration driveNewParamsAtIndex:self.driveIndex].sizeMB = self.nonexistingImageSize;
}

- (IBAction)isCdromSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.isCdromSwitch, @"Invalid sender");
    [self.configuration setDriveIsCdrom:sender.on forIndex:self.driveIndex];
}

@end
