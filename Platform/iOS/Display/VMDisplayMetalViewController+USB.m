//
// Copyright © 2021 osy. All rights reserved.
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

#import "VMDisplayMetalViewController+USB.h"
#import "CSUSBDevice.h"
#import "UIViewController+Extensions.h"
#import "UTMLogging.h"
#import "UTM-Swift.h"

@interface VMDisplayViewController ()

@property (nonatomic, readonly) BOOL isNoUsbPrompt;

@end

@implementation VMDisplayMetalViewController (USB)

- (BOOL)isNoUsbPrompt {
    return [self boolForSetting:@"NoUsbPrompt"];
}

- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceError:(NSString *)error forDevice:(CSUSBDevice *)device {
    UTMLog(@"USB device (%@) error: %@", device, error);
    [self showAlert:error actions:nil completion:nil];
}

- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceAttached:(CSUSBDevice *)device {
    UTMLog(@"USB device attached: %@", device);
    typeof(self) _self = self;
    NSString *prompt = NSLocalizedString(@"Would you like to connect '%@' to this virtual machine?", @"VMDisplayMetalWindowController");
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", @"VMDisplayMetalWindowController") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.usbDevicesViewController addDevice:device onCompletion:^(BOOL success, NSString * _Nullable message) {
            if (message) {
                [_self showAlert:message actions:nil completion:nil];
            }
        }];
    }];
    UIAlertAction *donotshow = [UIAlertAction actionWithTitle:NSLocalizedString(@"Do Not Show Again", @"VMDisplayMetalWindowController") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NoUsbPrompt"];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"VMDisplayMetalWindowController") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:[NSString stringWithFormat:prompt, device.name ? device.name : device.description] actions:@[confirm, donotshow, cancel] completion:nil];
}

- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceRemoved:(CSUSBDevice *)device {
    UTMLog(@"USB device removed: %@", device);
    [self.usbDevicesViewController removeDevice:device];
}

@end
