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
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "VMConfigDrivePickerViewController.h"
#import "VMConfigPickerView.h"
#import "VMConfigTogglePickerCell.h"

@interface VMConfigDriveDetailViewController ()

@end

@implementation VMConfigDriveDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.valid) {
        self.existingPathLabel.text = [self.configuration driveImagePathForIndex:self.driveIndex];
        self.imageType = [self.configuration driveImageTypeForIndex:self.driveIndex];
        self.driveInterfaceType = [self.configuration driveInterfaceTypeForIndex:self.driveIndex];
    } else {
        self.imageType = UTMDiskImageTypeDisk;
        self.driveInterfaceType = [UTMConfiguration defaultDriveInterface];
    }
    if (self.imageType == UTMDiskImageTypeDisk || self.imageType == UTMDiskImageTypeCD) {
        [self showDriveTypeOptions:YES animated:NO];
    } else {
        [self showDriveTypeOptions:NO animated:NO];
    }
    [self hidePickersAnimated:NO];
}

- (void)showDriveTypeOptions:(BOOL)visible animated:(BOOL)animated {
    if (!visible) {
        [self pickerCell:self.driveLocationPickerCell showPicker:NO animated:YES];
    }
    [self cells:self.driveTypeCells setHidden:!visible];
    [self reloadDataAnimated:YES];
}

#pragma mark - Properties

- (void)setImageType:(UTMDiskImageType)imageType {
    NSAssert(imageType < UTMDiskImageTypeMax, @"Invalid image type %lu", imageType);
    _imageType = imageType;
    if (self.valid) {
        [self.configuration setDriveImageType:imageType forIndex:self.driveIndex];
    }
    self.imageTypePickerCell.detailTextLabel.text = [UTMConfiguration supportedImageTypes][imageType];
}

- (void)setDriveInterfaceType:(NSString *)driveInterfaceType {
    _driveInterfaceType = driveInterfaceType;
    if (self.valid) {
        [self.configuration setDriveInterfaceType:driveInterfaceType forIndex:self.driveIndex];
    }
    self.driveLocationPickerCell.detailTextLabel.text = driveInterfaceType.length > 0 ? driveInterfaceType : @" ";
}

#pragma mark - Picker delegate

- (void)imageTypeChanged {
    if (self.imageType == UTMDiskImageTypeDisk || self.imageType == UTMDiskImageTypeCD) {
        if (self.driveInterfaceType.length == 0) {
            self.driveInterfaceType = [UTMConfiguration defaultDriveInterface];
        }
        [self showDriveTypeOptions:YES animated:NO];
    } else {
        self.driveInterfaceType = @"";
        [self showDriveTypeOptions:NO animated:NO];
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.driveLocationPickerCell.picker) {
        self.driveInterfaceType = [UTMConfiguration supportedDriveInterfaces][row];
    } else if (pickerView == self.imageTypePickerCell.picker) {
        self.imageType = row;
        [self imageTypeChanged];
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
        self.driveIndex = [self.configuration newDrive:source.selectedName type:self.imageType interface:self.driveInterfaceType];
    } else {
        [self.configuration setImagePath:source.selectedName forIndex:self.driveIndex];
    }
}

@end
