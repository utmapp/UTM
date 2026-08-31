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
#import <TargetConditionals.h>
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
        _vulkanDriver = vulkanDriver;
    } else {
        [self.mutableEnvironment removeObjectForKey:@"VK_DRIVER_FILES"];
        _vulkanDriver = kQEMUVulkanDriverDisabled;
    }
}

- (void)setDirectXDriver:(UTMQEMUDirectXDriver)directXDriver {
    NSString *backend;
    NSString *frameworkName;
    NSURL *library;
    if (@available(macOS 13, iOS 16, *)) {
    } else {
        return;
    }
    NSURL *bundleURL = NSBundle.mainBundle.bundleURL;
#if TARGET_OS_OSX
    NSURL *contentsURL = [bundleURL URLByAppendingPathComponent:@"Contents" isDirectory:YES];
    NSString *versionPath = @"Versions/A/";
#else
    NSURL *contentsURL = bundleURL;
    NSString *versionPath = @"";
#endif
    NSURL *frameworksURL = [contentsURL URLByAppendingPathComponent:@"Frameworks" isDirectory:YES];
    NSString *d3dMetal = @"D3DMetal";
    NSURL *d3dMetalURL = [frameworksURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@%@", d3dMetal, versionPath, d3dMetal] isDirectory:NO];
    if (directXDriver == kQEMUDirectXDriverDefault) {
        if (@available(macOS 14, *)) {
            if ([NSFileManager.defaultManager fileExistsAtPath:d3dMetalURL.path]) {
                directXDriver = kQEMUDirectXDriverD3DMetal;
            }
        }
    }
    switch (directXDriver) {
        case kQEMUDirectXDriverDefault:
        case kQEMUDirectXDriverDXMT:
            backend = @"dxmt";
            frameworkName = @"dxmt-native";
            break;
        case kQEMUDirectXDriverD3DMetal:
            backend = @"d3dmetal";
            frameworkName = @"d3dmetal-native";
            break;
        case kQEMUDirectXDriverDisabled:
        default:
            break;
    }
    if (frameworkName) {
        library = [frameworksURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@%@", frameworkName, versionPath, frameworkName] isDirectory:NO];
        if (![NSFileManager.defaultManager fileExistsAtPath:library.path]) {
            UTMLog(@"DirectX driver '%@' is not available in this build", backend);
            backend = nil;
            library = nil;
        } else if (directXDriver == kQEMUDirectXDriverD3DMetal) {
            self.mutableEnvironment[@"D3DMETAL_FRAMEWORK_PATH"] = d3dMetalURL.path;
            self.resources = [self.resources arrayByAddingObject:d3dMetalURL];
        }
    }
    if (backend && library) {
        self.mutableEnvironment[@"NPT_D3D11_LIBRARY_PATH"] = library.path;
        self.mutableEnvironment[@"NPT_D3D12_LIBRARY_PATH"] = library.path;
        self.mutableEnvironment[@"NPT_DXGI_LIBRARY_PATH"] = library.path;
        self.mutableEnvironment[@"NPT_BACKEND"] = backend;
        if (directXDriver == kQEMUDirectXDriverD3DMetal) {
            self.mutableEnvironment[@"NPT_CAPSET_D3D12"] = @"1";
        }
        self.resources = [self.resources arrayByAddingObject:library];
        _directXDriver = directXDriver;
    } else {
        [self.mutableEnvironment removeObjectForKey:@"NPT_D3D11_LIBRARY_PATH"];
        [self.mutableEnvironment removeObjectForKey:@"NPT_D3D12_LIBRARY_PATH"];
        [self.mutableEnvironment removeObjectForKey:@"NPT_DXGI_LIBRARY_PATH"];
        [self.mutableEnvironment removeObjectForKey:@"NPT_BACKEND"];
        [self.mutableEnvironment removeObjectForKey:@"NPT_CAPSET_D3D12"];
        [self.mutableEnvironment removeObjectForKey:@"D3DMETAL_FRAMEWORK_PATH"];
        _directXDriver = kQEMUDirectXDriverDisabled;
    }
}

- (void)setShmemDirectoryURL:(NSURL *)shmemDirectoryURL {
    _shmemDirectoryURL = shmemDirectoryURL;
    if (shmemDirectoryURL) {
        self.mutableEnvironment[@"XDG_RUNTIME_DIR"] = shmemDirectoryURL.path;
    } else {
        [self.mutableEnvironment removeObjectForKey:@"XDG_RUNTIME_DIR"];
    }
}

- (void)setAppSandboxGroupId:(NSString *)appSandboxGroupId {
    _appSandboxGroupId = appSandboxGroupId;
    if (appSandboxGroupId) {
        self.mutableEnvironment[@"APP_SANDBOX_GROUP_ID"] = appSandboxGroupId;
    } else {
        [self.mutableEnvironment removeObjectForKey:@"APP_SANDBOX_GROUP_ID"];
    }
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
    [logging writeLine:@"Environment variables:\n"];
    [self.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [logging writeLine:[NSString stringWithFormat:@"    %@=%@\n", key, value]];
    }];
}

- (void)setHasDebugLog:(BOOL)hasDebugLog {
    _hasDebugLog = hasDebugLog;
    if (hasDebugLog) {
#if TARGET_OS_OSX // FIXME: verbose logging is broken on iOS
        self.mutableEnvironment[@"G_MESSAGES_DEBUG"] = @"all";
#endif
        self.mutableEnvironment[@"VK_LOADER_DEBUG"] = @"all";
        self.mutableEnvironment[@"VIRGL_LOG_LEVEL"] = @"debug";
        self.mutableEnvironment[@"MESA_DEBUG"] = @"1";
        self.mutableEnvironment[@"MVK_CONFIG_LOG_LEVEL"] = @"4";
        self.mutableEnvironment[@"MVK_DEBUG"] = @"1";
        self.mutableEnvironment[@"MTL_DEBUG_LAYER"] = @"1";
        self.mutableEnvironment[@"MTL_DEBUG_LAYER_ERROR_MODE"] = @"nslog";
        self.mutableEnvironment[@"ANGLE_ENABLE_DEBUG_TRACE"] = @"1";
        self.mutableEnvironment[@"ANGLE_METAL_DEBUG_BINDINGS"] = @"1";
    } else {
        [self.mutableEnvironment removeObjectForKey:@"G_MESSAGES_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"VK_LOADER_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"VIRGL_LOG_LEVEL"];
        [self.mutableEnvironment removeObjectForKey:@"MESA_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"MVK_CONFIG_LOG_LEVEL"];
        [self.mutableEnvironment removeObjectForKey:@"MVK_DEBUG"];
        [self.mutableEnvironment removeObjectForKey:@"MTL_DEBUG_LAYER"];
        [self.mutableEnvironment removeObjectForKey:@"MTL_DEBUG_LAYER_ERROR_MODE"];
        [self.mutableEnvironment removeObjectForKey:@"ANGLE_ENABLE_DEBUG_TRACE"];
        [self.mutableEnvironment removeObjectForKey:@"ANGLE_METAL_DEBUG_BINDINGS"];
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
