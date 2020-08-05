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

#import "UTMQemuSystem.h"
#import "UTMLogging.h"
#import <dlfcn.h>

@implementation UTMQemuSystem {
    int (*_qemu_init)(int, const char *[], const char *[]);
    void (*_qemu_main_loop)(void);
    void (*_qemu_cleanup)(void);
}

static void *start_qemu(void *args) {
    UTMQemuSystem *self = (__bridge_transfer UTMQemuSystem *)args;
    __weak NSArray<NSString *> *qemuArgv = self.argv;
    
    NSCAssert(self->_qemu_init != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_main_loop != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_cleanup != NULL, @"Started thread with invalid function.");
    NSCAssert(qemuArgv, @"Started thread with invalid argv.");
    
    int argc = (int)qemuArgv.count;
    const char *argv[argc];
    for (int i = 0; i < qemuArgv.count; i++) {
        argv[i] = [qemuArgv[i] UTF8String];
    }
    const char *envp[] = { NULL };
    self->_qemu_init(argc, argv, envp);
    self->_qemu_main_loop();
    self->_qemu_cleanup();
    self.status = 0;
    dispatch_semaphore_signal(self.done);
    return NULL;
}

- (instancetype)initWithArgv:(NSArray<NSString *> *)argv {
    if (self = [super initWithArgv:argv]) {
        self.entry = start_qemu;
        self.type = QEMUHelperTypeSystem;
    }
    return self;
}

- (BOOL)didLoadDylib:(void *)handle {
    _qemu_init = dlsym(handle, "qemu_init");
    _qemu_main_loop = dlsym(handle, "qemu_main_loop");
    _qemu_cleanup = dlsym(handle, "qemu_cleanup");
    return (_qemu_init != NULL) && (_qemu_main_loop != NULL) && (_qemu_cleanup != NULL);
}

@end
