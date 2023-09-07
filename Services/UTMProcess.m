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

#import "UTMProcess.h"
#import "UTMLogging.h"
#import "QEMUHelperDelegate.h"
#import "QEMUHelperProtocol.h"
#import <dlfcn.h>
#import <pthread.h>
#import <TargetConditionals.h>

extern NSString *const kUTMErrorDomain;

#pragma mark - Methods

- (void)startDylibThread:(nonnull NSString *)dylib completion:(nonnull void (^)(NSError * _Nullable))completion {
    void *dlctx;
    __block pthread_t qemu_thread;
    pthread_attr_t qosAttribute;
    __weak typeof(self) wself = self;
    
    NSAssert(self.entry != NULL, @"entry is NULL!");
    self.status = self.fatal = 0;
    UTMLog(@"Loading %@", dylib);
    dlctx = dlopen([dylib UTF8String], RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion([self errorWithMessage:err]);
        return;
    }
    if (![self didLoadDylib:dlctx]) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion([self errorWithMessage:err]);
        return;
    }
    if (atexit_b(^{
        if (pthread_self() == qemu_thread) {
            __strong typeof(self) sself = wself;
            if (sself) {
                sself->_fatal = 1;
                dispatch_semaphore_signal(sself->_done);
            }
            pthread_exit(NULL);
        }
    }) != 0) {
        completion([self errorWithMessage:NSLocalizedString(@"Internal error has occurred.", @"UTMProcess")]);
        return;
    }
    pthread_attr_init(&qosAttribute);
    pthread_attr_set_qos_class_np(&qosAttribute, QOS_CLASS_USER_INTERACTIVE, 0);
    pthread_create(&qemu_thread, &qosAttribute, startProcess, (__bridge_retained void *)self);
    dispatch_async(self.completionQueue, ^{
        if (dispatch_semaphore_wait(self.done, DISPATCH_TIME_FOREVER)) {
            dlclose(dlctx);
            [self processHasExited:-1 message:NSLocalizedString(@"Internal error has occurred.", @"UTMProcess")];
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                [self processHasExited:-1 message:err];
            } else if (self.fatal || self.status) {
                [self processHasExited:-1 message:nil];
            } else {
                [self processHasExited:0 message:nil];
            }
        }
    });
    completion(nil);
}

@end
