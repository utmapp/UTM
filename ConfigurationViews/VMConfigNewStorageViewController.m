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

#import "VMConfigDriveDetailViewController.h"

@interface VMConfigDriveDetailViewController ()

@end

@implementation VMConfigDriveDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    UTMNewDrive *driveParams = [self.configuration driveNewParamsAtIndex:self.driveIndex];
    if (driveParams) {
        self.driveImageExisting = YES;
        self.nonexistingPathName.text = driveParams.name;
        self.nonexistingImageSize = driveParams.sizeMB;
        self.nonexistingImageExpandingSwitch.on = driveParams.isQcow2;
    } else {
        self.driveImageExisting = NO;
        self.existingPathLabel.text = [self.configuration driveImagePathForIndex:self.driveIndex];
        self.isCdromSwitch.on = [self.configuration driveIsCdromForIndex:self.driveIndex];
        self.driveInterfaceType = [self.configuration driveInterfaceTypeForIndex:self.driveIndex];
    }
    
}

#pragma mark - Properties

- (void)setDriveLocationPickerActive:(BOOL)driveLocationPickerActive {
    _driveLocationPickerActive = driveLocationPickerActive;
    [self pickerCell:self.driveLocationPickerCell setActive:driveLocationPickerActive];
}

- (void)setDriveImageExisting:(BOOL)driveImageExisting {
    _driveImageExisting = driveImageExisting;
    if (driveImageExisting) {
        [self.configuration prepareNewDriveAtIndex:self.driveIndex];
        [self cells:self.nonexistingImageCells setHidden:YES];
        [self cells:self.existingImageCells setHidden:NO];
        [self reloadDataAnimated:self.doneLoadingConfiguration];
        [self.driveTypeExistingCell setAccessoryType:UITableViewCellAccessoryCheckmark];
        [self.driveTypeNewCell setAccessoryType:UITableViewCellAccessoryNone];
    } else {
        [self.configuration discardNewDriveAtIndex:self.driveIndex];
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

- (NSNumber *)nonexistingImageSize {
    return [NSNumber numberWithLong:[self.nonexistingImageSizeField.text intValue]];
}

- (void)setNonexistingImageSize:(NSNumber *)nonexistingImageSize {
    self.nonexistingImageSizeField.text = [nonexistingImageSize stringValue];
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveLocationCell) {
        self.driveLocationPickerActive = !self.driveLocationPickerActive;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveTypeExistingCell) {
        self.driveImageExisting = YES;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if ([tableView cellForRowAtIndexPath:indexPath] == self.driveTypeNewCell) {
        self.driveImageExisting = NO;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Picker delegate

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    if (pickerView == self.driveLocationPicker) {
        return 1;
    }
    return 0;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (component == 0) {
        if (pickerView == self.driveLocationPicker) {
            return [UTMConfiguration supportedDriveInterfaces].count;
        }
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (component == 0) {
        if (pickerView == self.driveLocationPicker) {
            return [UTMConfiguration supportedDriveInterfaces][row];
        }
    }
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (component == 0) {
        if (pickerView == self.driveLocationPicker) {
            self.driveInterfaceType = [UTMConfiguration supportedDriveInterfaces][row];
        }
    }
}

#pragma mark - Event handlers

- (IBAction)nonexistingImageExpandingSwitchChanged:(UISwitch *)sender {
    [self.configuration driveNewParamsAtIndex:self.driveIndex].isQcow2 = sender.on;
}

- (IBAction)existingImageMakeCopySwitchChanged:(UISwitch *)sender {
    // TODO: implement me
}

- (IBAction)nonexistingPathNameChanged:(UITextField *)sender {
    [self.configuration driveNewParamsAtIndex:self.driveIndex].name = sender.text;
}

- (IBAction)nonexistingImageSizeChanged:(UITextField *)sender {
    [self.configuration driveNewParamsAtIndex:self.driveIndex].sizeMB = self.nonexistingImageSize;
}

- (IBAction)isCdromSwitchChanged:(UISwitch *)sender {
    [self.configuration setDriveIsCdrom:sender.on forIndex:self.driveIndex];
}

@end
