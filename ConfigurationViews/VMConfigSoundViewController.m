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

@interface VMConfigSoundViewController ()

@end

@implementation VMConfigSoundViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.soundCardPickerView.delegate = self;
    self.soundCardPickerView.dataSource = self;
}


- (void)viewWillAppear:(BOOL)animated {
    NSUInteger row = [[UTMConfiguration supportedSoundCardDevices] indexOfObject:self.configuration.soundCard];
    [self.soundCardPickerView selectRow: row inComponent:0 animated:NO];
    [self.soundCardPickerView reloadComponent:0];
}

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.soundEnabledSwitch.on = self.configuration.soundEnabled;
    [self pickerCell:self.soundCardPickerViewTableViewCell setActive:self.configuration.soundEnabled];
     
    
}

#pragma mark - Picker helpers

- (void)pickerCell:(nonnull UITableViewCell *)pickerCell setActive:(BOOL)active {
    [self cell:pickerCell setHidden:!active];
    [self reloadDataAnimated:self.doneLoadingConfiguration];
}

#pragma mark - Event handlers

- (IBAction)soundEnabledSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.soundEnabledSwitch, @"Invalid sender");
    self.configuration.soundEnabled = sender.on;
    [self pickerCell:self.soundCardPickerViewTableViewCell setActive:sender.on];
    
}


- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [UTMConfiguration supportedSoundCardDevices].count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [UTMConfiguration supportedSoundCardDevices][row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.configuration.soundCard = [UTMConfiguration supportedSoundCardDevices][row];
}

@end
