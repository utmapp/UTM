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
#import "VMConfigSystemViewController.h"
#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+System.h"

const NSUInteger kMBinBytes = 1024 * 1024;
const NSUInteger kMinCodeGenBufferSizeMB = 1;
const NSUInteger kMaxCodeGenBufferSizeMB = 2048;
const NSUInteger kBaseUsageBytes = 128 * kMBinBytes;
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

- (void)refreshViewFromConfiguration {
    [super refreshViewFromConfiguration];
    self.architecturePickerActive = NO;
    self.bootPickerActive = NO;
    self.systemPickerActive = NO;
    self.architectureLabel.text = self.configuration.systemArchitecture;
    self.bootLabel.text = self.configuration.systemBootDevice;
    self.systemLabel.text = self.configuration.systemTarget;
    self.memorySize = self.configuration.systemMemory;
    self.cpuCount = self.configuration.systemCPUCount;
    self.jitCacheSize = self.configuration.systemJitCacheSize;
    self.forceMulticoreSwitch.on = self.configuration.systemForceMulticore;
}

#pragma mark - Properties

@synthesize totalRam = _totalRam;
@synthesize estimatedRam = _estimatedRam;

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
        NSUInteger index = [[UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture] indexOfObject:self.systemLabel.text];
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
    return @([self.memorySizeField.text integerValue]);
}

- (void)setJitCacheSize:(NSNumber *)jitCacheSize {
    self.jitCacheSizeField.text = [jitCacheSize integerValue] > 0 ? [jitCacheSize stringValue] : @"";
}

- (NSNumber *)jitCacheSize {
    return @([self.jitCacheSizeField.text integerValue]);
}

- (void)setCpuCount:(NSNumber *)cpuCount {
    self.cpuCountField.text = [cpuCount stringValue];
}

- (NSNumber *)cpuCount {
    return @([self.cpuCountField.text integerValue]);
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
        return [UTMConfiguration supportedBootDevicesPretty].count;
    } else if (pickerView == self.systemPicker) {
        return [UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture].count;
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
        return [UTMConfiguration supportedBootDevicesPretty][row];
    } else if (pickerView == self.systemPicker) {
        return [UTMConfiguration supportedTargetsForArchitecturePretty:self.configuration.systemArchitecture][row];
    } else {
        NSAssert(0, @"Invalid picker");
    }
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSAssert(component == 0, @"Invalid component");
    if (pickerView == self.architecturePicker) {
        NSString *prev = self.configuration.systemArchitecture;
        self.architectureLabel.text = [UTMConfiguration supportedArchitectures][row];
        self.configuration.systemArchitecture = [UTMConfiguration supportedArchitectures][row];
        // refresh system picker with default target
        if (![prev isEqualToString:self.configuration.systemArchitecture]) {
            NSInteger index = [UTMConfiguration defaultTargetIndexForArchitecture:self.configuration.systemArchitecture];
            [self.systemPicker reloadAllComponents];
            [self.systemPicker selectRow:index inComponent:0 animated:YES];
            [self pickerView:self.systemPicker didSelectRow:index inComponent:0];
        }
    } else if (pickerView == self.bootPicker) {
        self.bootLabel.text = [UTMConfiguration supportedBootDevices][row];
        self.configuration.systemBootDevice = self.bootLabel.text;
    } else if (pickerView == self.systemPicker) {
        self.systemLabel.text = [UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture][row];
        self.configuration.systemTarget = [UTMConfiguration supportedTargetsForArchitecture:self.configuration.systemArchitecture][row];
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
        [self showAlert:NSLocalizedString(@"Invalid memory size.", @"VMConfigSystemViewController") completion:nil];
    }
    [self updateEstimatedRam];
    if (self.estimatedRam > kMemoryWarningThreshold * self.totalRam) {
        [self showAlert:NSLocalizedString(@"The total memory usage is close to your device's limit. iOS will kill the VM if it consumes too much memory.", @"VMConfigSystemViewController") completion:nil];
    }
}

- (void)cpuCountFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.cpuCountField, @"Invalid sender");
    NSNumber *num = self.cpuCount;
    if (num.intValue > 0) {
        self.configuration.systemCPUCount = num;
    } else {
        [self showAlert:NSLocalizedString(@"Invalid core count.", @"VMConfigSystemViewController") completion:nil];
    }
}

- (IBAction)jitCacheSizeFieldEdited:(UITextField *)sender {
    NSAssert(sender == self.jitCacheSizeField, @"Invalid sender");
    NSInteger jit = [self.jitCacheSize integerValue];
    if (jit == 0) { // default value
        self.configuration.systemJitCacheSize = self.jitCacheSize;
    } else if (jit < kMinCodeGenBufferSizeMB) {
        [self showAlert:NSLocalizedString(@"JIT cache size too small.", @"VMConfigSystemViewController") completion:nil];
    } else if (jit > kMaxCodeGenBufferSizeMB) {
        [self showAlert:NSLocalizedString(@"JIT cache size cannot be larger than 2GB.", @"VMConfigSystemViewController") completion:nil];
    } else {
        self.configuration.systemJitCacheSize = self.jitCacheSize;
    }
    [self updateEstimatedRam];
    if (self.estimatedRam > kMemoryWarningThreshold * self.totalRam) {
        [self showAlert:NSLocalizedString(@"The total memory usage is close to your device's limit. iOS will kill the VM if it consumes too much memory.", @"VMConfigSystemViewController") completion:nil];
    }
}

- (IBAction)forceMulticoreSwitchChanged:(UISwitch *)sender {
    NSAssert(sender == self.forceMulticoreSwitch, @"Invalid sender");
    self.configuration.systemForceMulticore = sender.on;
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
        NSLog(@"Failed to fetch vm statistics");
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
    NSUInteger guestRam = [self.memorySize unsignedIntegerValue] * kMBinBytes;
    NSUInteger jitSize = [self.jitCacheSize unsignedIntegerValue] * kMBinBytes;
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
