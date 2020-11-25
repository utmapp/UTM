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
#import <sys/sysctl.h>
#import <TargetConditionals.h>
#import "UTMQemuSystem.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Drives.h"
#import "UTMConfiguration+Miscellaneous.h"
#import "UTMConfiguration+Networking.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMConfiguration+System.h"
#import "UTMConfigurationPortForward.h"
#import "UTMJailbreak.h"
#import "UTMLogging.h"

@interface UTMQemuSystem ()

@property (nonatomic, readonly) NSInteger emulatedCpuCount;

@end

@implementation UTMQemuSystem {
    int (*_qemu_init)(int, const char *[], const char *[]);
    void (*_qemu_main_loop)(void);
    void (*_qemu_cleanup)(void);
}

static void *start_qemu(void *args) {
    UTMQemuSystem *self = (__bridge_transfer UTMQemuSystem *)args;
    NSArray<NSString *> *qemuArgv = self.argv;
    
    NSCAssert(self->_qemu_init != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_main_loop != NULL, @"Started thread with invalid function.");
    NSCAssert(self->_qemu_cleanup != NULL, @"Started thread with invalid function.");
    NSCAssert(qemuArgv, @"Started thread with invalid argv.");
    
    int argc = (int)qemuArgv.count + 1;
    const char *argv[argc];
    argv[0] = "qemu-system";
    for (int i = 0; i < qemuArgv.count; i++) {
        argv[i+1] = [qemuArgv[i] UTF8String];
    }
    const char *envp[] = { NULL };
    self->_qemu_init(argc, argv, envp);
    self->_qemu_main_loop();
    self->_qemu_cleanup();
    self.status = 0;
    dispatch_semaphore_signal(self.done);
    return NULL;
}

static size_t hostCpuCount(void) {
    size_t len;
    unsigned int ncpu = 0;

    len = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
    return ncpu;
}

- (instancetype)initWithConfiguration:(UTMConfiguration *)configuration imgPath:(nonnull NSURL *)imgPath {
    self = [self init];
    if (self) {
        self.configuration = configuration;
        self.imgPath = imgPath;
        self.qmpPort = 4444;
        self.spicePort = 5930;
        self.entry = start_qemu;
    }
    return self;
}

- (NSArray<NSString *> *)argv {
    NSArray<NSString *> *argv = [super argv];
    if (argv.count > 0) {
        return argv;
    } else {
        [self argsRequired];
        if (!self.configuration.ignoreAllConfiguration) {
            [self argsFromConfiguration];
        }
        return [super argv];
    }
}

- (NSInteger)emulatedCpuCount {
    NSInteger userCount = [self.configuration.systemCPUCount integerValue];
    size_t ncpu = hostCpuCount();
    if (userCount > 0 || ncpu == 0) {
        return userCount; // user override
    }
#if defined(__arm__)
    // in ARM we can only emulate other weak architectures
    NSString *arch = self.configuration.systemArchitecture;
    if ([arch isEqualToString:@"alpha"] ||
        [arch isEqualToString:@"arm"] ||
        [arch isEqualToString:@"aarch64"] ||
        [arch isEqualToString:@"avr"] ||
        [arch hasPrefix:@"mips"] ||
        [arch hasPrefix:@"ppc"] ||
        [arch hasPrefix:@"riscv"] ||
        [arch hasPrefix:@"xtensa"]) {
        return ncpu;
    } else {
        return 1;
    }
#elif defined(__i386__)
    // in x86 we can emulate weak on strong
    return ncpu;
#else
    return 1;
#endif
}

- (void)architectureSpecificConfiguration {
    if ([self.configuration.systemArchitecture isEqualToString:@"x86_64"] ||
        [self.configuration.systemArchitecture isEqualToString:@"i386"]) {
        [self pushArgv:@"-vga"];
        [self pushArgv:@"qxl"];
        [self pushArgv:@"-global"];
        [self pushArgv:@"PIIX4_PM.disable_s3=1"]; // applies for pc-i440fx-* types
        [self pushArgv:@"-global"];
        [self pushArgv:@"ICH9-LPC.disable_s3=1"]; // applies for pc-q35-* types
    }
}

- (void)targetSpecificConfiguration {
    if ([self.configuration.systemTarget hasPrefix:@"virt"]) {
        if (![self useHypervisor] && [self.configuration.systemArchitecture isEqualToString:@"aarch64"]) {
            [self pushArgv:@"-cpu"];
            [self pushArgv:@"cortex-a72"];
        }
        // this is required for virt devices
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtio-gpu-pci"];
    }
}

- (void)argsForDrives {
    for (NSUInteger i = 0; i < self.configuration.countDrives; i++) {
        NSString *path = [self.configuration driveImagePathForIndex:i];
        UTMDiskImageType type = [self.configuration driveImageTypeForIndex:i];
        BOOL hasImage = ![self.configuration driveRemovableForIndex:i] && path;
        NSURL *fullPathURL;
        
        if (hasImage) {
            if ([path characterAtIndex:0] == '/') {
                fullPathURL = [NSURL fileURLWithPath:path isDirectory:NO];
            } else {
                fullPathURL = [[self.imgPath URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory]] URLByAppendingPathComponent:[self.configuration driveImagePathForIndex:i]];
            }
            [self accessDataWithBookmark:[fullPathURL bookmarkDataWithOptions:0
                                               includingResourceValuesForKeys:nil
                                                                relativeToURL:nil
                                                                        error:nil]];
        }
        
        switch (type) {
            case UTMDiskImageTypeDisk:
            case UTMDiskImageTypeCD: {
                NSString *drive;
                [self pushArgv:@"-drive"];
                drive = [NSString stringWithFormat:@"if=%@,media=%@,id=drive%lu", [self.configuration driveInterfaceTypeForIndex:i], type == UTMDiskImageTypeCD ? @"cdrom" : @"disk", i];
                if (hasImage) {
                    drive = [NSString stringWithFormat:@"%@,file=%@", drive, fullPathURL.path];
                }
                [self pushArgv:drive];
                break;
            }
            case UTMDiskImageTypeBIOS: {
                if (hasImage) {
                    [self pushArgv:@"-bios"];
                    [self pushArgv:fullPathURL.path];
                }
                break;
            }
            case UTMDiskImageTypeKernel: {
                if (hasImage) {
                    [self pushArgv:@"-kernel"];
                    [self pushArgv:fullPathURL.path];
                }
                break;
            }
            case UTMDiskImageTypeInitrd: {
                if (hasImage) {
                    [self pushArgv:@"-initrd"];
                    [self pushArgv:fullPathURL.path];
                }
                break;
            }
            case UTMDiskImageTypeDTB: {
                if (hasImage) {
                    [self pushArgv:@"-dtb"];
                    [self pushArgv:fullPathURL.path];
                }
                break;
            }
            default: {
                UTMLog(@"WARNING: unknown image type %lu, ignoring image %@", type, fullPathURL);
                break;
            }
        }
    }
}

- (void)argsForNetwork {
    if (self.configuration.networkEnabled) {
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"%@,netdev=net0", self.configuration.networkCard]];
        [self pushArgv:@"-netdev"];
        NSMutableString *netstr = [NSMutableString stringWithString:@"user,id=net0"];
        if (self.configuration.networkAddress.length > 0) {
            [netstr appendFormat:@",net=%@", self.configuration.networkAddress];
        }
        if (self.configuration.networkHost.length > 0) {
            [netstr appendFormat:@",host=%@", self.configuration.networkHost];
        }
        if (self.configuration.networkAddressIPv6.length > 0) {
            [netstr appendFormat:@",ipv6-net=%@", self.configuration.networkAddressIPv6];
        }
        if (self.configuration.networkHostIPv6.length > 0) {
            [netstr appendFormat:@",ipv6-host=%@", self.configuration.networkHostIPv6];
        }
        if (self.configuration.networkIsolate) {
            [netstr appendString:@"restrict=on"];
        }
        if (self.configuration.networkHost.length > 0) {
            [netstr appendFormat:@",hostname=%@", self.configuration.networkHost];
        }
        if (self.configuration.networkDhcpStart.length > 0) {
            [netstr appendFormat:@",dhcpstart=%@", self.configuration.networkDhcpStart];
        }
        if (self.configuration.networkDnsServer.length > 0) {
            [netstr appendFormat:@",dns=%@", self.configuration.networkDnsServer];
        }
        if (self.configuration.networkDnsServerIPv6.length > 0) {
            [netstr appendFormat:@",ipv6-dns=%@", self.configuration.networkDnsServerIPv6];
        }
        if (self.configuration.networkDnsSearch.length > 0) {
            [netstr appendFormat:@",dnssearch=%@", self.configuration.networkDnsSearch];
        }
        if (self.configuration.networkDhcpDomain.length > 0) {
            [netstr appendFormat:@",domainname=%@", self.configuration.networkDhcpDomain];
        }
        for (NSUInteger i = 0; i < [self.configuration countPortForwards]; i++) {
            UTMConfigurationPortForward *portForward = [self.configuration portForwardForIndex:i];
            [netstr appendFormat:@",hostfwd=%@:%@:%@-%@:%@", portForward.protocol, portForward.hostAddress, portForward.hostPort, portForward.guestAddress, portForward.guestPort];
        }
        [self pushArgv:netstr];
    } else {
        [self pushArgv:@"-nic"];
        [self pushArgv:@"none"];
    }
}

- (void)argsForSharing {
    if (self.configuration.shareClipboardEnabled || self.configuration.shareDirectoryEnabled) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtio-serial"];
    }
    
    if (self.configuration.shareClipboardEnabled) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtserialport,chardev=vdagent,name=com.redhat.spice.0"];
        [self pushArgv:@"-chardev"];
        [self pushArgv:@"spicevmc,id=vdagent,debug=0,name=vdagent"];
    }
    
    if (self.configuration.shareDirectoryEnabled) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtserialport,chardev=charchannel1,id=channel1,name=org.spice-space.webdav.0"];
        [self pushArgv:@"-chardev"];
        [self pushArgv:@"spiceport,name=org.spice-space.webdav.0,id=charchannel1"];
    }
}

- (NSString *)tcgAccelProperties {
    NSString *accel = @"tcg";
    
    if (self.configuration.systemForceMulticore) {
        accel = [accel stringByAppendingString:@",thread=multi"];
    }
    if ([self.configuration.systemJitCacheSize integerValue] > 0) {
        accel = [accel stringByAppendingFormat:@",tb-size=%@", [self.configuration.systemJitCacheSize stringValue]];
    }
    
    // use mirror mapping when we don't have JIT entitlements
    if (!jb_has_jit_entitlement()) {
        accel = [accel stringByAppendingString:@",mirror-rwx=on"];
    }
    
    return accel;
}

- (BOOL)useHypervisor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"UseHypervisor"];
}

- (NSString *)machineProperties {
    if (self.configuration.systemMachineProperties.length > 0) {
        return self.configuration.systemMachineProperties; // use specified properties
    }
    // otherwise use default properties for each machine
    if ([self.configuration.systemTarget hasPrefix:@"pc"] || [self.configuration.systemTarget hasPrefix:@"q35"]) {
        return @"vmport=off";
    }
    if ([self.configuration.systemTarget isEqualToString:@"mac99"]) {
        return @"via=pmu";
    }
    return @"";
}

- (void)argsRequired {
    NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:@"qemu" withExtension:nil];
    [self clearArgv];
    [self pushArgv:@"-L"];
    [self accessDataWithBookmark:[resourceURL bookmarkDataWithOptions:0
                                       includingResourceValuesForKeys:nil
                                                        relativeToURL:nil
                                                                error:nil]];
    [self pushArgv:resourceURL.path];
    [self pushArgv:@"-S"]; // startup stopped
    [self pushArgv:@"-qmp"];
    [self pushArgv:[NSString stringWithFormat:@"tcp:localhost:%lu,server,nowait", self.qmpPort]];
    if (self.configuration.displayConsoleOnly) {
        [self pushArgv:@"-nographic"];
        // terminal character device
        NSURL* ioFile = [self.configuration terminalInputOutputURL];
        [self pushArgv: @"-chardev"];
        [self accessDataWithBookmark:[[ioFile URLByDeletingLastPathComponent] bookmarkDataWithOptions:0
                                                                       includingResourceValuesForKeys:nil
                                                                                        relativeToURL:nil
                                                                                                error:nil]];
        [self pushArgv: [NSString stringWithFormat: @"pipe,id=term0,path=%@", ioFile.path]];
        [self pushArgv: @"-serial"];
        [self pushArgv: @"chardev:term0"];
    } else {
        [self pushArgv:@"-spice"];
        [self pushArgv:[NSString stringWithFormat:@"port=%lu,addr=127.0.0.1,disable-ticketing,image-compression=off,playback-compression=off,streaming-video=off", self.spicePort]];
    }
}

- (void)argsFromConfiguration {
    [self pushArgv:@"-smp"];
    [self pushArgv:[NSString stringWithFormat:@"cpus=%lu,sockets=1", self.emulatedCpuCount]];
    [self pushArgv:@"-machine"];
    [self pushArgv:[NSString stringWithFormat:@"%@,%@", self.configuration.systemTarget, [self machineProperties]]];
    if ([self useHypervisor]) {
        [self pushArgv:@"-accel"];
        [self pushArgv:@"hvf"];
        [self pushArgv:@"-cpu"];
        [self pushArgv:@"host"];
    }
    [self pushArgv:@"-accel"];
    [self pushArgv:[self tcgAccelProperties]];
    [self architectureSpecificConfiguration];
    [self targetSpecificConfiguration];
    if (![self.configuration.systemBootDevice isEqualToString:@"hdd"]) {
        [self pushArgv:@"-boot"];
        if ([self.configuration.systemBootDevice isEqualToString:@"floppy"]) {
            [self pushArgv:@"order=ab"];
        } else {
            [self pushArgv:@"order=d"];
        }
    }
    [self pushArgv:@"-m"];
    [self pushArgv:[self.configuration.systemMemory stringValue]];
    if (self.configuration.soundEnabled) {
        [self pushArgv:@"-soundhw"];
        [self pushArgv:self.configuration.soundCard];
    }
    [self pushArgv:@"-name"];
    [self pushArgv:self.configuration.name];
    [self argsForDrives];
    [self argsForNetwork];
    // usb input if not legacy
    if (!self.configuration.inputLegacy) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"usb-ehci"];
        [self pushArgv:@"-device"];
        [self pushArgv:@"usb-tablet"];
        [self pushArgv:@"-device"];
        [self pushArgv:@"usb-mouse"];
        [self pushArgv:@"-device"];
        [self pushArgv:@"usb-kbd"];
    }
    if (self.snapshot) {
        [self pushArgv:@"-loadvm"];
        [self pushArgv:self.snapshot];
    }
    
    [self argsForSharing];
    
    if (self.configuration.systemUUID.length > 0) {
        [self pushArgv:@"-uuid"];
        [self pushArgv:self.configuration.systemUUID];
    }
    
    // fix windows time issues
    [self pushArgv:@"-rtc"];
    [self pushArgv:@"base=localtime"];
}
    
- (void)argsFromUser {
    if (self.configuration.systemArguments.count != 0) {
        NSArray *addArgs = self.configuration.systemArguments;
        // Splits all spaces into their own, except when between quotes.
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\"[^\"]+\"|\\+|\\S+)" options:0 error:nil];
        
        for (NSString *arg in addArgs) {
            // No need to operate on empty arguments.
            if (arg.length == 0) {
                continue;
            }
            
            NSArray *splitArgsArray = [regex matchesInString:arg
                                              options:0
                                                range:NSMakeRange(0, [arg length])];
            
            
            for (NSTextCheckingResult *match in splitArgsArray) {
                NSRange matchRange = [match rangeAtIndex:1];
                NSString *argFragment = [arg substringWithRange:matchRange];
                if ([argFragment hasPrefix:@"\""] && [argFragment hasSuffix:@"\""]) {
                    argFragment = [argFragment substringWithRange:NSMakeRange(1, argFragment.length-2)];
                }
                [self pushArgv:argFragment];
            }
        }
    }
}

- (BOOL)didLoadDylib:(void *)handle {
    _qemu_init = dlsym(handle, "qemu_init");
    _qemu_main_loop = dlsym(handle, "qemu_main_loop");
    _qemu_cleanup = dlsym(handle, "qemu_cleanup");
    return (_qemu_init != NULL) && (_qemu_main_loop != NULL) && (_qemu_cleanup != NULL);
}

- (void)startWithCompletion:(void (^)(BOOL, NSString * _Nonnull))completion {
    NSString *name = [NSString stringWithFormat:@"qemu-system-%@", self.configuration.systemArchitecture];
    [self argsRequired];
    if (!self.configuration.ignoreAllConfiguration) {
        [self argsFromConfiguration];
    }
    [self argsFromUser];
    [self start:name completion:completion];
}

@end
