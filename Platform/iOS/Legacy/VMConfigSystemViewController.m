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

#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import "UIViewController+Extensions.h"
#import "VMConfigSystemViewController.h"
#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+System.h"
#import "UTMLogging.h"
#import "VMConfigPickerView.h"
#import "VMConfigTextField.h"
#import "VMConfigTogglePickerCell.h"

const NSUInteger kMBinBytes = 1024 * 1024;
const NSUInteger kMinCodeGenBufferSizeMB = 1;
const NSUInteger kMaxCodeGenBufferSizeMB = 2048;
const NSUInteger kBaseUsageBytes = 128 * kMBinBytes;
const float kMemoryAlertThreshold = 0.5;
const float kMemoryWarningThreshold = 0.8;

@interface VMConfigSystemViewController ()

@end

@implementation VMConfigSystemViewController {
    NSUInteger _totalRam;
    NSUInteger _estimatedRam;
    NSUInteger _cpuCores;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateHostInfo];
    [self updateEstimatedRam];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.configuration.systemJitCacheSize.integerValue == 0) {
        self.jitCacheSizeField.text = @"";
    }
}

#pragma mark - Properties

@synthesize totalRam = _totalRam;
@synthesize estimatedRam = _estimatedRam;

#pragma mark - Picker delegate

- (void)pickerCell:(VMConfigTogglePickerCell *)cell showPicker:(BOOL)visible animated:(BOOL)animated {
    if (visible && cell.picker == self.targetPicker) {
        NSUInteger index = [[UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture] indexOfObject:cell.detailTextLabel.text];
        if (index != NSNotFound) {
            [cell.picker selectRow:index inComponent:0 animated:NO];
        }
    }
    [super pickerCell:cell showPicker:visible animated:animated];
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.targetPicker) {
        return [UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture].count;
    } else {
        return [super pickerView:pickerView numberOfRowsInComponent:component];
    }
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.targetPicker) {
        return [UTMConfiguration supportedTargetsForArchitecturePretty:self.configuration.systemArchitecture][row];
    } else {
        return [super pickerView:pickerView titleForRow:row forComponent:component];
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.architecturePicker) {
        NSString *prev = self.configuration.systemArchitecture;
        [super pickerView:pickerView didSelectRow:row inComponent:component];
        // refresh system picker with default target
        if (![prev isEqualToString:self.configuration.systemArchitecture]) {
            NSInteger index = [UTMConfiguration defaultTargetIndexForArchitecture:self.configuration.systemArchitecture];
            [self.targetPicker reloadAllComponents];
            [self.targetPicker selectRow:index inComponent:0 animated:YES];
            [self pickerView:self.targetPicker didSelectRow:index inComponent:0];
        }
    } else if (pickerView == self.targetPicker) {
        NSAssert([pickerView isKindOfClass:[VMConfigPickerView class]], @"Invalid picker");
        VMConfigPickerView *vmPicker = (VMConfigPickerView *)pickerView;
        NSString *selected = [UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture][row];
        [self.configuration setValue:selected forKey:vmPicker.selectedOptionCell.configurationPath];
        vmPicker.selectedOptionCell.detailTextLabel.text = selected;
    } else {
        [super pickerView:pickerView didSelectRow:row inComponent:component];
    }
}

#pragma mark - Validate input

- (void)verifyRam {
    if (self.estimatedRam > kMemoryWarningThreshold * self.totalRam) {
        [self showAlert:NSLocalizedString(@"Warning: iOS will kill apps that use more than 80% of the device's total memory.", @"VMConfigSystemViewController") actions:nil completion:nil];
    } else if (self.estimatedRam > kMemoryAlertThreshold * self.totalRam) {
        [self showAlert:NSLocalizedString(@"The total memory usage is close to your device's limit. iOS will kill the VM if it consumes too much memory.", @"VMConfigSystemViewController") actions:nil completion:nil];
    }
}

- (BOOL)memorySizeFieldValid:(UITextField *)sender {
    BOOL valid = NO;
    NSAssert(sender == self.memorySizeField, @"Invalid sender");
    self.memorySize = sender.text.integerValue;
    if (self.memorySize > 0) {
        valid = YES;
    } else {
        [self showAlert:NSLocalizedString(@"Invalid memory size.", @"VMConfigSystemViewController") actions:nil completion:nil];
    }
    [self updateEstimatedRam];
    [self verifyRam];
    return valid;
}

- (BOOL)cpuCountFieldValid:(UITextField *)sender {
    BOOL valid = NO;
    NSAssert(sender == self.cpuCountField, @"Invalid sender");
    self.cpuCount = sender.text.integerValue;
    if (self.cpuCount >= 0) {
        valid = YES;
    } else {
        [self showAlert:NSLocalizedString(@"Invalid core count.", @"VMConfigSystemViewController") actions:nil completion:nil];
    }
    return valid;
}

- (BOOL)jitCacheSizeFieldValid:(UITextField *)sender {
    BOOL valid = NO;
    NSAssert(sender == self.jitCacheSizeField, @"Invalid sender");
    self.jitCacheSize = sender.text.integerValue;
    if (self.jitCacheSize == 0) { // default value
        valid = YES;
    } else if (self.jitCacheSize < kMinCodeGenBufferSizeMB) {
        [self showAlert:NSLocalizedString(@"JIT cache size too small.", @"VMConfigSystemViewController") actions:nil completion:nil];
    } else if (self.jitCacheSize > kMaxCodeGenBufferSizeMB) {
        [self showAlert:NSLocalizedString(@"JIT cache size cannot be larger than 2GB.", @"VMConfigSystemViewController") actions:nil completion:nil];
    } else {
        valid = YES;
    }
    [self updateEstimatedRam];
    [self verifyRam];
    return valid;
}

- (IBAction)configTextFieldEditEnd:(VMConfigTextField *)sender {
    if (sender == self.memorySizeField) {
        if ([self memorySizeFieldValid:sender]) {
            [super configTextFieldEditEnd:sender];
        }
    } else if (sender == self.cpuCountField) {
        if ([self cpuCountFieldValid:sender]) {
            [super configTextFieldEditEnd:sender];
        }
    } else if (sender == self.jitCacheSizeField) {
        if ([self jitCacheSizeFieldValid:sender]) {
            [super configTextFieldEditEnd:sender];
        }
    } else {
        [super configTextFieldEditEnd:sender];
    }
}

#pragma mark - Update host information

- (void)updateHostInfo {
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;

    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);

    vm_statistics_data_t vm_stat;

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        UTMLog(@"Failed to fetch vm statistics");
    }

    /* Stats in bytes */
    natural_t mem_used = (vm_stat.free_count +
                          vm_stat.active_count +
                          vm_stat.inactive_count +
                          vm_stat.wire_count) * (natural_t)pagesize;
    _totalRam = mem_used;
    
    /* Get core count */
    size_t len;
    unsigned int ncpu;

    len = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
    _cpuCores = ncpu;
    
    // update labels
    self.totalRamLabel.text = [NSString stringWithFormat:@"%lu MB", _totalRam / kMBinBytes];
    self.cpuCoresLabel.text = [NSString stringWithFormat:@"%lu", _cpuCores];
}

- (void)updateEstimatedRam {
    NSUInteger guestRam = self.memorySize * kMBinBytes;
    NSUInteger jitSize = self.jitCacheSize * kMBinBytes;
    if (jitSize == 0) { // default size
        jitSize = guestRam / 4;
    }
    // we need to double observed JIT size due to iOS restrictions
    // FIXME: remove this doubling when JIT is fixed
    jitSize *= 2;
    _estimatedRam = kBaseUsageBytes + guestRam + jitSize;
    self.estimatedRamLabel.text = [NSString stringWithFormat:@"%lu MB", _estimatedRam / kMBinBytes];
}

@end
