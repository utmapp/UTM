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

#import "CSUSBDevice.h"
#import <glib.h>
#import <spice-client.h>

@interface CSUSBDevice ()

@property (nonatomic, readwrite, nonnull) SpiceUsbDevice *device;

@end

@implementation CSUSBDevice

+ (instancetype)usbDeviceWithDevice:(SpiceUsbDevice *)device {
    return [[CSUSBDevice alloc] initWithDevice:device];
}

- (instancetype)initWithDevice:(SpiceUsbDevice *)device {
    if (self = [super init]) {
        self.device = device;
    }
    return self;
}

- (NSString *)description {
    gchar *description = spice_usb_device_get_description(self.device, NULL);
    if (!description) {
        return @"";
    }
    NSString *nsdescription = [NSString stringWithUTF8String:description];
    g_free(description);
    return nsdescription;
}

- (BOOL)isEqualToUSBDevice:(CSUSBDevice *)usbDevice {
    NSString *description = self.description;
    return description.length > 0 && [description isEqualToString:usbDevice.description];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[CSUSBDevice class]]) {
        return NO;
    }
    
    return [self isEqualToUSBDevice:object];
}

- (NSUInteger)hash {
    return self.description.hash;
}

@end
