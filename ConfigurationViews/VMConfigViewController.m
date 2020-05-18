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

#import "VMConfigViewController.h"
#import "VMConfigControl.h"
#import "VMConfigPickerView.h"
#import "VMConfigStepper.h"
#import "VMConfigSwitch.h"
#import "VMConfigTextField.h"
#import "VMConfigTogglePickerCell.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "UTMLogging.h"

void *kVMConfigViewControllerContext = &kVMConfigViewControllerContext;

@interface VMConfigViewController ()

@end

@implementation VMConfigViewController

@synthesize configuration;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.insertTableViewRowAnimation = UITableViewRowAnimationMiddle;
    self.deleteTableViewRowAnimation = UITableViewRowAnimationMiddle;
    self.reloadTableViewRowAnimation = UITableViewRowAnimationMiddle;
}

#pragma mark - Text field helpers
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)]) {
        id<UTMConfigurationDelegate> dst = (id<UTMConfigurationDelegate>)segue.destinationViewController;
        dst.configuration = self.configuration;
    }
}

#pragma mark - Configuration observers

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    for (id<VMConfigControl> control in self.configControls) {
        NSAssert([control conformsToProtocol:@protocol(VMConfigControl)], @"Invalid configControls");
        NSAssert(control.configurationPath, @"nil configurationPath for %@", control);
        [self.configuration addObserver:self
                             forKeyPath:control.configurationPath
                                options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial
                                context:kVMConfigViewControllerContext];
    }
    // hide pickers
    for (VMConfigTogglePickerCell *cell in self.configPickerToggles) {
        [self pickerCell:cell showPicker:NO animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    for (id<VMConfigControl> control in self.configControls) {
        NSAssert([control conformsToProtocol:@protocol(VMConfigControl)], @"Invalid configControls");
        NSAssert(control.configurationPath, @"nil configurationPath for %@", control);
        [self.configuration removeObserver:self
                                forKeyPath:control.configurationPath
                                   context:kVMConfigViewControllerContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == kVMConfigViewControllerContext) {
        for (id<VMConfigControl> control in self.configControls) {
            if ([control.configurationPath isEqualToString:keyPath]) {
                id value = change[NSKeyValueChangeNewKey];
                if (value != change[NSKeyValueChangeOldKey]) {
                    UTMLog(@"seen configuration change %@ = %@", keyPath, value);
                    [control valueChanged:value];
                }
            }
        }
    }
}

#pragma mark - Picker view

- (void)pickerCell:(VMConfigTogglePickerCell *)cell showPicker:(BOOL)visible animated:(BOOL)animated {
    if (visible) {
        NSUInteger index = [[UTMConfiguration supportedOptions:cell.picker.supportedOptionsPath pretty:NO] indexOfObject:cell.detailTextLabel.text];
        if (index != NSNotFound) {
            [cell.picker selectRow:index inComponent:0 animated:NO];
        }
    }
    [self cells:cell.toggleVisibleCells setHidden:!visible];
    [self reloadDataAnimated:animated];
    cell.cellsVisible = visible;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[VMConfigTogglePickerCell class]]) {
        VMConfigTogglePickerCell *vmCell = (VMConfigTogglePickerCell *)cell;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self pickerCell:vmCell showPicker:!vmCell.cellsVisible animated:YES];
    }
}

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    NSAssert([pickerView isKindOfClass:[VMConfigPickerView class]], @"Invalid picker");
    return 1;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert([pickerView isKindOfClass:[VMConfigPickerView class]], @"Invalid picker");
    VMConfigPickerView *vmPicker = (VMConfigPickerView *)pickerView;
    return [UTMConfiguration supportedOptions:vmPicker.supportedOptionsPath pretty:NO].count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert([pickerView isKindOfClass:[VMConfigPickerView class]], @"Invalid picker");
    VMConfigPickerView *vmPicker = (VMConfigPickerView *)pickerView;
    return [UTMConfiguration supportedOptions:vmPicker.supportedOptionsPath pretty:YES][row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    NSAssert([pickerView isKindOfClass:[VMConfigPickerView class]], @"Invalid picker");
    VMConfigPickerView *vmPicker = (VMConfigPickerView *)pickerView;
    NSString *selected = [UTMConfiguration supportedOptions:vmPicker.supportedOptionsPath pretty:NO][row];
    [self.configuration setValue:selected forKey:vmPicker.selectedOptionCell.configurationPath];
    vmPicker.selectedOptionCell.detailTextLabel.text = selected;
}

- (void)hidePickersAnimated:(BOOL)animated {
    for (VMConfigTogglePickerCell *cell in self.configPickerToggles) {
        [self pickerCell:cell showPicker:NO animated:animated];
    }
}

#pragma mark - Event handler for controls

- (IBAction)configTextEditChanged:(VMConfigTextField *)sender {
}

- (IBAction)configTextFieldEditEnd:(VMConfigTextField *)sender {
    // validate input in super-class
    UTMLog(@"config edited for text %@", sender.configurationPath);
    if (sender.isNumber) {
        [self.configuration setValue:@([sender.text integerValue]) forKey:sender.configurationPath];
    } else {
        [self.configuration setValue:sender.text forKey:sender.configurationPath];
    }
}

- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender {
    UTMLog(@"config changed for switch %@", sender.configurationPath);
    [self.configuration setValue:@(sender.on) forKey:sender.configurationPath];
}

- (IBAction)configStepperChanged:(VMConfigStepper *)sender {
    UTMLog(@"config changed for stepper %@", sender.configurationPath);
    [self.configuration setValue:@(sender.value) forKey:sender.configurationPath];
}

@end
