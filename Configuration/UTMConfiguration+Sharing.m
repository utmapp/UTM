//
// Copyright © 2020 osy. All rights reserved.
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

#import "UTMConfiguration+Sharing.h"
#import "UTMConfiguration+System.h"
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigSharingKey;

const NSString *const kUTMConfigChipboardSharingKey = @"ClipboardSharing";
const NSString *const kUTMConfigDirectorySharingKey = @"DirectorySharing";
const NSString *const kUTMConfigDirectoryReadOnlyKey = @"DirectoryReadOnly";
const NSString *const kUTMConfigDirectoryNameKey = @"DirectoryName";
const NSString *const kUTMConfigDirectoryBookmarkKey = @"DirectoryBookmark";
const NSString *const kUTMConfigUsb3SupportKey = @"Usb3Support";
const NSString *const kUTMConfigUsbRedirectMaxKey = @"UsbRedirectMax";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Sharing)

#pragma mark - Migration

- (void)migrateSharingConfigurationIfNecessary {
    if (!self.rootDict[kUTMConfigSharingKey][kUTMConfigUsbRedirectMaxKey]) {
        self.usbRedirectionMaximumDevices = @3;
    }
    if (![self.rootDict[kUTMConfigSharingKey] objectForKey:kUTMConfigUsb3SupportKey]) {
        if ([self.systemTarget isEqualToString:@"virt"] || [self.systemTarget hasPrefix:@"virt-"]) {
            self.usb3Support = YES;
        }
    }
}

#pragma mark - Sharing settings

- (BOOL)shareClipboardEnabled {
    return [self.rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] boolValue];
}

- (void)setShareClipboardEnabled:(BOOL)shareClipboardEnabled {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] = @(shareClipboardEnabled);
}

- (BOOL)shareDirectoryEnabled {
    return [self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectorySharingKey] boolValue];
}

- (void)setShareDirectoryEnabled:(BOOL)shareDirectoryEnabled {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectorySharingKey] = @(shareDirectoryEnabled);
}

- (BOOL)shareDirectoryReadOnly {
    return [self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryReadOnlyKey] boolValue];
}

- (void)setShareDirectoryReadOnly:(BOOL)shareDirectoryReadOnly {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryReadOnlyKey] = @(shareDirectoryReadOnly);
}

- (NSString *)shareDirectoryName {
    return self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryNameKey];
}

- (void)setShareDirectoryName:(NSString *)shareDirectoryName {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryNameKey] = shareDirectoryName;
}

- (NSData *)shareDirectoryBookmark {
    return self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryBookmarkKey];
}

- (void)setShareDirectoryBookmark:(NSData *)shareDirectoryBookmark {
    [self propertyWillChange];
    if (!shareDirectoryBookmark) {
        [self.rootDict[kUTMConfigSharingKey] removeObjectForKey:kUTMConfigDirectoryBookmarkKey];
    } else {
        self.rootDict[kUTMConfigSharingKey][kUTMConfigDirectoryBookmarkKey] = shareDirectoryBookmark;
    }
}

- (void)setUsb3Support:(BOOL)usb3Support {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigUsb3SupportKey] = @(usb3Support);
}

- (BOOL)usb3Support {
    return [self.rootDict[kUTMConfigSharingKey][kUTMConfigUsb3SupportKey] boolValue];
}

- (NSNumber *)usbRedirectionMaximumDevices {
    return self.rootDict[kUTMConfigSharingKey][kUTMConfigUsbRedirectMaxKey];
}

- (void)setUsbRedirectionMaximumDevices:(NSNumber *)usbRedirectionMaximumDevices {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSharingKey][kUTMConfigUsbRedirectMaxKey] = usbRedirectionMaximumDevices;
}

@end
