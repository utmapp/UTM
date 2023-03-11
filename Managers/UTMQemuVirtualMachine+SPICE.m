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

#import "UTMQemuVirtualMachine+SPICE.h"
#import "UTMLogging.h"
#import "UTMQemuMonitor.h"
#import "UTMSpiceIO.h"
#import "UTMJailbreak.h"
#import "UTM-Swift.h"
#if defined(WITH_QEMU_TCI)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

@interface UTMQemuVirtualMachine ()

@property (nonatomic, readonly, nullable) UTMQemuMonitor *qemu;
@property (nonatomic, readonly, nullable) UTMSpiceIO *ioService;
@property (nonatomic) BOOL changeCursorRequestInProgress;

@end

@implementation UTMQemuVirtualMachine (SPICE)

#pragma mark - Input device switching

- (void)requestInputTablet:(BOOL)tablet {
    UTMQemuMonitor *qemu;
    @synchronized (self) {
        qemu = self.qemu;
        if (self.changeCursorRequestInProgress || !qemu) {
            return;
        }
        self.changeCursorRequestInProgress = YES;
    }
    [qemu mouseIndexForAbsolute:tablet withCompletion:^(int64_t index, NSError *err) {
        if (err) {
            UTMLog(@"error finding index: %@", err);
            self.changeCursorRequestInProgress = NO;
        } else {
            UTMLog(@"found index:%lld absolute:%d", index, tablet);
            [self.qemu mouseSelect:index withCompletion:^(NSString *res, NSError *err) {
                if (err) {
                    UTMLog(@"input select returned error: %@", err);
                } else {
                    UTMSpiceIO *spiceIO = self.ioService;
                    if (spiceIO) {
                        [spiceIO.primaryInput requestMouseMode:!tablet];
                    } else {
                        UTMLog(@"failed to get SPICE manager: %@", err);
                    }
                }
                self.changeCursorRequestInProgress = NO;
            }];
        }
    }];
}

#pragma mark - USB redirection

- (BOOL)hasUsbRedirection {
    return jb_has_usb_entitlement();
}

@end
