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
#import "UTMConfiguration+Defaults.h"
#import "UTMConfiguration+System.h"
#import "VMConfigDrivePickerViewController.h"
#import "VMConfigPickerView.h"
#import "VMConfigTogglePickerCell.h"
#import "UIViewController+Extensions.h"

@interface VMConfigDriveDetailViewController ()

@property (nonatomic, assign) BOOL edited;

@end

@implementation VMConfigDriveDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.edited) {
        return;
    }
    if (self.existing) {
        self.imageName = [self.configuration driveImagePathForIndex:self.driveIndex];
        self.imageType = [self.configuration driveImageTypeForIndex:self.driveIndex];
        self.driveInterfaceType = [self.configuration driveInterfaceTypeForIndex:self.driveIndex];
        self.removable = [self.configuration driveRemovableForIndex:self.driveIndex];
        [self showImagePathCell:!self.removable animated:NO];
    } else {
        self.imageType = UTMDiskImageTypeDisk;
        self.driveInterfaceType = [UTMConfiguration defaultDriveInterfaceForTarget:self.configuration.systemTarget type:UTMDiskImageTypeDisk];
    }
    if (self.imageType == UTMDiskImageTypeDisk || self.imageType == UTMDiskImageTypeCD) {
        [self showDriveTypeOptions:YES animated:NO];
    } else {
        [self showDriveTypeOptions:NO animated:NO];
    }
    [self hidePickersAnimated:NO];
    self.edited = YES;
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
    if (self.existing) {
        [self.configuration setDriveImageType:imageType forIndex:self.driveIndex];
    }
    self.imageTypePickerCell.detailTextLabel.text = [UTMConfiguration supportedImageTypes][imageType];
}

- (void)setDriveInterfaceType:(NSString *)driveInterfaceType {
    _driveInterfaceType = driveInterfaceType;
    if (self.existing) {
        [self.configuration setDriveInterfaceType:driveInterfaceType forIndex:self.driveIndex];
    }
    self.driveLocationPickerCell.detailTextLabel.text = driveInterfaceType.length > 0 ? driveInterfaceType : @" ";
}

- (void)setRemovable:(BOOL)removable {
    _removable = removable;
    if (self.removableToggle.on != removable) {
        self.removableToggle.on = removable;
    }
}

- (void)setImageName:(NSString *)imageName {
    _imageName = imageName;
    self.existingPathLabel.text = imageName;
}

#pragma mark - Picker delegate

- (void)imageTypeChanged {
    if (self.imageType == UTMDiskImageTypeDisk || self.imageType == UTMDiskImageTypeCD) {
        if (self.driveInterfaceType.length == 0) {
            self.driveInterfaceType = [UTMConfiguration defaultDriveInterfaceForTarget:self.configuration.systemTarget type:self.imageType];
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
    self.imageName = source.selectedName;
}

#pragma mark - Actions

- (void)showImagePathCell:(BOOL)visible animated:(BOOL)animated {
    [self cell:self.existingPathCell setHidden:!visible];
    [self reloadDataAnimated:animated];
}

- (IBAction)removableToggleChanged:(UISwitch *)sender {
    self.removable = sender.on;
    [self showImagePathCell:!self.removable animated:YES];
}

- (IBAction)saveButtonPressed:(UIBarButtonItem *)sender {
    if (!self.removable && self.imageName.length == 0) {
        [self showAlert:NSLocalizedString(@"You must select a disk image.", @"VMConfigDriveDetailsViewController") actions:nil completion:nil];
        return;
    }
    if (!self.existing) {
        NSString *name = [NSUUID UUID].UUIDString;
        self.existing = YES;
        if (self.removable) {
            self.driveIndex = [self.configuration newRemovableDrive:name type:self.imageType interface:self.driveInterfaceType];
        } else {
            self.driveIndex = [self.configuration newDrive:name path:self.imageName type:self.imageType interface:self.driveInterfaceType];
        }
    } else {
        [self.configuration setDriveRemovable:self.removable forIndex:self.driveIndex];
        if (!self.removable) {
            [self.configuration setImagePath:self.imageName forIndex:self.driveIndex];
        }
        [self.configuration setDriveInterfaceType:self.driveInterfaceType forIndex:self.driveIndex];
        [self.configuration setDriveImageType:self.imageType forIndex:self.driveIndex];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
