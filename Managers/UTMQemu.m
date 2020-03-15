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

#import "UTMQemu.h"
#import "UTMLogging.h"
#import <dlfcn.h>
#import <pthread.h>

const uint64_t kQemuExitErrorStatus = 0xAABBCCDD;

@implementation UTMQemu {
    int (*_main)(int, const char *[]);
    NSMutableArray<NSString *> *_argv;
}

void *start_qemu(void *args) {
    UTMQemu *self = (__bridge_transfer UTMQemu *)args;
    intptr_t status;
    
    NSCAssert(self->_main != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_argv, @"Started thread with invalid argv.");
    
    int argc = (int)self->_argv.count;
    const char *argv[argc];
    for (int i = 0; i < self->_argv.count; i++) {
        argv[i] = [self->_argv[i] UTF8String];
    }
    status = self->_main(argc, argv);
    return (void *)status;
}

- (void)pushArgv:(NSString *)arg {
    if (!_argv) {
        _argv = [NSMutableArray<NSString *> array];
    }
    [_argv addObject:arg];
}

- (void)clearArgv {
    _argv = nil;
}

- (void)printArgv {
    NSString *args = @"";
    for (NSString *arg in _argv) {
        args = [args stringByAppendingFormat:@" %@", arg];
    }
    NSLog(@"Running: %@", args);
}

- (void)startDylib:(nonnull NSString *)dylib main:(nonnull NSString *)main completion:(void(^)(BOOL,NSString *))completion {
    void *dlctx;
    __block pthread_t qemu_thread;
    
    NSLog(@"Loading %@", dylib);
    dlctx = dlopen([dylib UTF8String], RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion(NO, err);
        return;
    }
    _main = dlsym(dlctx, [main UTF8String]);
    if (_main == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion(NO, err);
        return;
    }
    if (atexit_b(^{
        if (pthread_self() == qemu_thread) {
            pthread_exit((void *)kQemuExitErrorStatus);
        }
    }) != 0) {
        completion(NO, NSLocalizedString(@"Internal error has occurred.", @"qemu pthread fail"));
        return;
    }
    [self printArgv];
    pthread_create(&qemu_thread, NULL, &start_qemu, (__bridge_retained void *)self);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        void *status;
        if (pthread_join(qemu_thread, &status)) {
            dlclose(dlctx);
            completion(NO, NSLocalizedString(@"Internal error has occurred.", @"qemu pthread fail"));
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                completion(NO, err);
            } else if (status == (void *)kQemuExitErrorStatus) {
                completion(NO, [NSString stringWithFormat:NSLocalizedString(@"QEMU exited from an error: %@", @"qemu pthread fail"), [[UTMLogging sharedInstance] lastErrorLine]]);
            } else {
                completion(YES, nil);
            }
        }
    });
}

@end
