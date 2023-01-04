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

#import <dlfcn.h>
#import "UTMQemuSystem.h"

@interface UTMQemuSystem ()

@property (nonatomic) NSString *architecture;

@end

@implementation UTMQemuSystem {
    int (*_qemu_init)(int, const char *[], const char *[]);
    void (*_qemu_main_loop)(void);
    void (*_qemu_cleanup)(void);
}

static void *start_qemu(void *args) {
    UTMQemuSystem *self = (__bridge_transfer UTMQemuSystem *)args;
    NSArray<NSString *> *qemuArgv = self.argv;
    NSMutableArray<NSString *> *environment = [NSMutableArray arrayWithCapacity:self.environment.count];
    
    NSCAssert(self->_qemu_init != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_main_loop != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_cleanup != NULL, @"Started thread with invalid function.");
    NSCAssert(qemuArgv, @"Started thread with invalid argv.");
    
    /* set up environment variables */
    [self.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *combined = [NSString stringWithFormat:@"%@=%@", key, value];
        [environment addObject:combined];
        setenv(key.UTF8String, value.UTF8String, 1);
    }];
    NSUInteger envc = environment.count;
    const char *envp[envc + 1];
    for (NSUInteger i = 0; i < envc; i++) {
        envp[i] = environment[i].UTF8String;
    }
    envp[envc] = NULL;
    setenv("TMPDIR", NSFileManager.defaultManager.temporaryDirectory.path.UTF8String, 1);
    
    int argc = (int)qemuArgv.count + 1;
    const char *argv[argc];
    argv[0] = "qemu-system";
    for (int i = 0; i < qemuArgv.count; i++) {
        argv[i+1] = [qemuArgv[i] UTF8String];
    }
    self->_qemu_init(argc, argv, envp);
    self->_qemu_main_loop();
    self->_qemu_cleanup();
    self.status = 0;
    dispatch_semaphore_signal(self.done);
    return NULL;
}

- (void)setRendererBackend:(UTMQEMURendererBackend)rendererBackend {
    _rendererBackend = rendererBackend;
    switch (rendererBackend) {
        case kQEMURendererBackendAngleMetal:
            self.environment = @{@"ANGLE_DEFAULT_PLATFORM": @"metal"};
            break;
        case kQEMURendererBackendDefault:
        case kQEMURendererBackendAngleGL:
        default:
            break;
    }
}

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments architecture:(nonnull NSString *)architecture {
    self = [super initWithArguments:arguments];
    if (self) {
        self.entry = start_qemu;
        self.architecture = architecture;
    }
    return self;
}

- (BOOL)didLoadDylib:(void *)handle {
    _qemu_init = dlsym(handle, "qemu_init");
    _qemu_main_loop = dlsym(handle, "qemu_main_loop");
    _qemu_cleanup = dlsym(handle, "qemu_cleanup");
    return (_qemu_init != NULL) && (_qemu_main_loop != NULL) && (_qemu_cleanup != NULL);
}

- (void)startWithCompletion:(void (^)(BOOL, NSString * _Nonnull))completion {
    for (NSURL *resourceURL in self.resources) {
        NSData *bookmark = [resourceURL bookmarkDataWithOptions:0
                                 includingResourceValuesForKeys:nil
                                                  relativeToURL:nil
                                                          error:nil];
        if (bookmark) {
            [self accessDataWithBookmark:bookmark];
        }
    }
    NSString *name = [NSString stringWithFormat:@"qemu-%@-softmmu", self.architecture];
    [self startQemu:name completion:completion];
}

@end
