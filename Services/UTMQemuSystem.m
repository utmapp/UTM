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
#import "UTMLogging.h"
#import "UTMQemuSystem.h"

@interface UTMQemuSystem ()

@property (nonatomic) NSString *architecture;
@property (nonatomic) NSMutableDictionary<NSString *, NSString *> *mutableEnvironment;

@end

@implementation UTMQemuSystem {
    int (*_qemu_init)(int, const char *[], const char *[]);
    void (*_qemu_main_loop)(void);
    void (*_qemu_cleanup)(void);
}

static int startQemu(UTMProcess *process, int argc, const char *argv[], const char *envp[]) {
    UTMQemuSystem *self = (UTMQemuSystem *)process;
    int ret = self->_qemu_init(argc, argv, envp);
    if (ret != 0) {
        return ret;
    }
    self->_qemu_main_loop();
    self->_qemu_cleanup();
    return 0;
}

- (void)setRendererBackend:(UTMQEMURendererBackend)rendererBackend {
    _rendererBackend = rendererBackend;
    switch (rendererBackend) {
        case kQEMURendererBackendDefault:
        case kQEMURendererBackendAngleMetal:
            self.mutableEnvironment[@"ANGLE_DEFAULT_PLATFORM"] = @"metal";
            break;
        case kQEMURendererBackendAngleGL:
        default:
            [self.mutableEnvironment removeObjectForKey:@"ANGLE_DEFAULT_PLATFORM"];
            break;
    }
}

- (void)setVulkanDriver:(UTMQEMUVulkanDriver)vulkanDriver {
    _vulkanDriver = vulkanDriver;
    NSURL *vulkanIcds = [[NSBundle.mainBundle URLForResource:@"vulkan" withExtension:nil] URLByAppendingPathComponent:@"icd.d" isDirectory:YES];
    NSURL *driver;
    switch (vulkanDriver) {
        case kQEMUVulkanDriverDefault:
        case kQEMUVulkanDriverMoltenVK:
            driver = [vulkanIcds URLByAppendingPathComponent:@"MoltenVK_icd.json"];
            break;
        case kQEMUVulkanDriverKosmicKrisp:
            driver = [vulkanIcds URLByAppendingPathComponent:@"kosmickrisp_mesa_icd.json"];
            break;
        case kQEMUVulkanDriverDisabled:
        default:
            driver = nil;
            break;
    }
    if (driver) {
        self.mutableEnvironment[@"VK_DRIVER_FILES"] = driver.path;
        self.resources = [self.resources arrayByAddingObject:driver];
    }
}

- (void)setShmemDirectoryURL:(NSURL *)shmemDirectoryURL {
    _shmemDirectoryURL = shmemDirectoryURL;
    self.mutableEnvironment[@"XDG_RUNTIME_DIR"] = shmemDirectoryURL.path;
}

- (NSPipe *)standardOutput {
    return self.logging.standardOutput;
}

- (void)setStandardOutput:(NSPipe *)standardOutput {
    [self doesNotRecognizeSelector:_cmd];
}

- (NSPipe *)standardError {
    return self.logging.standardError;
}

- (void)setStandardError:(NSPipe *)standardError {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)setLogging:(QEMULogging *)logging {
    _logging = logging;
    [logging writeLine:[NSString stringWithFormat:@"Launching: qemu-system-%@%@\n", self.architecture, self.arguments]];
}

- (void)setHasDebugLog:(BOOL)hasDebugLog {
    _hasDebugLog = hasDebugLog;
    if (hasDebugLog) {
        self.mutableEnvironment[@"G_MESSAGES_DEBUG"] = @"all";
        self.mutableEnvironment[@"VK_LOADER_DEBUG"] = @"all";
        self.mutableEnvironment[@"VIRGL_LOG_LEVEL"] = @"debug";
        self.mutableEnvironment[@"MESA_DEBUG"] = @"1";
        self.mutableEnvironment[@"MVK_CONFIG_LOG_LEVEL"] = @"4";
    } else {
        [self.mutableEnvironment removeObjectForKey:@"G_MESSAGES_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"VK_LOADER_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"VIRGL_LOG_LEVEL"];
        [self.mutableEnvironment removeObjectForKey:@"MESA_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"MVK_CONFIG_LOG_LEVEL"];
    }
}

- (NSDictionary<NSString *,NSString *> *)environment {
    return self.mutableEnvironment;
}

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments architecture:(nonnull NSString *)architecture {
    self = [super initWithArguments:arguments];
    if (self) {
        self.entry = startQemu;
        self.architecture = architecture;
        self.mutableEnvironment = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)didLoadDylib:(void *)handle {
    _qemu_init = dlsym(handle, "qemu_init");
    _qemu_main_loop = dlsym(handle, "qemu_main_loop");
    _qemu_cleanup = dlsym(handle, "qemu_cleanup");
    return (_qemu_init != NULL) && (_qemu_main_loop != NULL) && (_qemu_cleanup != NULL);
}

- (void)startQemuWithCompletion:(nonnull void (^)(NSError * _Nullable))completion {
    dispatch_group_t group = dispatch_group_create();
    for (NSURL *resourceURL in self.resources) {
        NSData *bookmark = self.remoteBookmarks[resourceURL];
        BOOL securityScoped = YES;
        if (!bookmark) {
            bookmark = [resourceURL bookmarkDataWithOptions:0
                             includingResourceValuesForKeys:nil
                                              relativeToURL:nil
                                                      error:nil];
            securityScoped = NO;
        }
        if (bookmark) {
            dispatch_group_enter(group);
            [self accessDataWithBookmark:bookmark securityScoped:securityScoped completion:^(BOOL success, NSData *bookmark, NSString *path) {
                if (!success) {
                    UTMLog(@"Access QEMU bookmark failed for: %@", path);
                }
                dispatch_group_leave(group);
            }];
        }
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    NSString *name = [NSString stringWithFormat:@"qemu-%@-softmmu", self.architecture];
    [self startProcess:name completion:completion];
}

- (void)stopQemu {
    [self stopProcess];
}

/// Called by superclass
- (void)processHasExited:(NSInteger)exitCode message:(nullable NSString *)message {
    [self.launcherDelegate qemuLauncher:self didExitWithExitCode:exitCode message:message];
}

@end
