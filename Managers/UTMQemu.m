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

@implementation UTMQemu {
    NSMutableArray<NSString *> *_argv;
}

@synthesize argv = _argv;

- (instancetype)init {
    if (self = [super init]) {
        _argv = [NSMutableArray<NSString *> array];
    }
    return self;
}

- (void)pushArgv:(nullable NSString *)arg {
    NSAssert(arg, @"Cannot push null argument!");
    [_argv addObject:arg];
}

- (void)clearArgv {
    [_argv removeAllObjects];
}

- (void)printArgv {
    NSString *args = @"";
    for (NSString *arg in _argv) {
        if ([arg containsString:@" "]) {
            args = [args stringByAppendingFormat:@" \"%@\"", arg];
        } else {
            args = [args stringByAppendingFormat:@" %@", arg];
        }
    }
    UTMLog(@"Running: %@", args);
}

- (BOOL)didLoadDylib:(void *)handle {
    return YES;
}

- (void)startDylib:(nonnull NSString *)dylib entry:(UTMQemuThreadEntry)entry completion:(void(^)(BOOL,NSString *))completion {
    void *dlctx;
    __block pthread_t qemu_thread;
    __weak typeof(self) wself = self;
    
    self.status = self.fatal = 0;
    self.done = dispatch_semaphore_create(0);
    UTMLog(@"Loading %@", dylib);
    dlctx = dlopen([dylib UTF8String], RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion(NO, err);
        return;
    }
    if (![self didLoadDylib:dlctx]) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion(NO, err);
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
        completion(NO, NSLocalizedString(@"Internal error has occurred.", @"UTMQemu"));
        return;
    }
    [self printArgv];
    pthread_create(&qemu_thread, NULL, entry, (__bridge_retained void *)self);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        if (dispatch_semaphore_wait(self.done, DISPATCH_TIME_FOREVER)) {
            dlclose(dlctx);
            completion(NO, NSLocalizedString(@"Internal error has occurred.", @"UTMQemu"));
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                completion(NO, err);
            } else if (self.fatal || self.status) {
                completion(NO, [NSString stringWithFormat:NSLocalizedString(@"QEMU exited from an error: %@", @"UTMQemu"), [[UTMLogging sharedInstance] lastErrorLine]]);
            } else {
                completion(YES, nil);
            }
        }
    });
}

@end
