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
#import "UTMLegacyQemuConfiguration.h"
#import "UTMLegacyQemuConfiguration+Constants.h"
#import "UTMLegacyQemuConfiguration+Display.h"
#import "UTMLegacyQemuConfiguration+Drives.h"
#import "UTMLegacyQemuConfiguration+Miscellaneous.h"
#import "UTMLegacyQemuConfiguration+Networking.h"
#import "UTMLegacyQemuConfiguration+Sharing.h"
#import "UTMLegacyQemuConfiguration+System.h"
#import "UTMLegacyQemuConfigurationPortForward.h"
#import "UTMJailbreak.h"
#import "UTMLogging.h"

typedef struct {
    NSInteger cpus;
    NSInteger threads;
} CPUCount;

extern NSString *const kUTMErrorDomain;

@interface UTMQemuSystem ()

@property (nonatomic, readonly) NSURL *resourceURL;
@property (nonatomic, readonly) CPUCount emulatedCpuCount;
@property (nonatomic, readonly) BOOL hasCustomBios;
@property (nonatomic, readonly) BOOL usbSupported;
@property (nonatomic, readonly) NSURL *efiVariablesURL;
@property (nonatomic, readonly) BOOL isGLOn;
@property (nonatomic, readonly) BOOL isSparc;

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

static size_t sysctl_read(const char *name) {
    size_t len;
    unsigned int ncpu = 0;

    len = sizeof(ncpu);
    sysctlbyname(name, &ncpu, &len, NULL, 0);
    return ncpu;
}

- (instancetype)initWithConfiguration:(UTMLegacyQemuConfiguration *)configuration imgPath:(nonnull NSURL *)imgPath {
    self = [self init];
    if (self) {
        self.configuration = configuration;
        self.imgPath = imgPath;
        self.entry = start_qemu;
    }
    return self;
}

- (NSArray<NSString *> *)argv {
    NSArray<NSString *> *argv = [super argv];
    if (argv.count == 0) {
        // HACK: when called from QEMU settings page
        [self updateArgvWithUserOptions:NO];
    }
    return [super argv];
}

- (NSURL *)resourceURL {
    return [[NSBundle mainBundle] URLForResource:@"qemu" withExtension:nil];
}

- (CPUCount)emulatedCpuCount {
    static const __unused CPUCount singleCpu = {
        .cpus = 1,
        .threads = 1,
    };
    CPUCount hostCount = {
        .cpus = sysctl_read("hw.physicalcpu"),
        .threads = sysctl_read("hw.logicalcpu"),
    };
    NSInteger userCpus = [self.configuration.systemCPUCount integerValue];
    if (userCpus > 0 || hostCount.cpus == 0) {
        CPUCount userCount = {
            .cpus = userCpus,
            .threads = userCpus,
        };
        return userCount; // user override
    }
    NSString *arch = self.configuration.systemArchitecture;
    // SPARC5 defaults to single CPU
    if ([arch hasPrefix:@"sparc"]) {
        return singleCpu;
    }
#if defined(__aarch64__)
    CPUCount hostPcoreCount = {
        .cpus = sysctl_read("hw.perflevel0.physicalcpu"),
        .threads = sysctl_read("hw.perflevel0.logicalcpu"),
    };
    // in ARM we can only emulate other weak architectures
    if ([arch isEqualToString:@"alpha"] ||
        [arch isEqualToString:@"arm"] ||
        [arch isEqualToString:@"aarch64"] ||
        [arch isEqualToString:@"avr"] ||
        [arch hasPrefix:@"mips"] ||
        [arch hasPrefix:@"ppc"] ||
        [arch hasPrefix:@"riscv"] ||
        [arch hasPrefix:@"xtensa"]) {
        if (self.useOnlyPcores && hostPcoreCount.cpus > 0) {
            return hostPcoreCount;
        } else {
            return hostCount;
        }
    } else {
        return singleCpu;
    }
#elif defined(__x86_64__)
    // in x86 we can emulate weak on strong
    return hostCount;
#else
    return singleCpu;
#endif
}

- (void)architectureSpecificConfiguration {
    NSString *arch = self.configuration.systemArchitecture;
    if ([arch isEqualToString:@"x86_64"] || [arch isEqualToString:@"i386"]) {
        [self pushArgv:@"-global"];
        [self pushArgv:@"PIIX4_PM.disable_s3=1"]; // applies for pc-i440fx-* types
        [self pushArgv:@"-global"];
        [self pushArgv:@"ICH9-LPC.disable_s3=1"]; // applies for pc-q35-* types
    }
    if (self.configuration.systemBootUefi) {
        NSString *name = [NSString stringWithFormat:@"edk2-%@-code.fd", arch];
        NSURL *path = [self.resourceURL URLByAppendingPathComponent:name];
        if (!self.hasCustomBios && [[NSFileManager defaultManager] fileExistsAtPath:path.path]) {
            [self pushArgv:@"-drive"];
            [self pushArgv:[NSString stringWithFormat:@"if=pflash,format=raw,unit=0,file=%@,readonly=on", path.path]]; // accessDataWithBookmark called already
            [self pushArgv:@"-drive"];
            [self pushArgv:[NSString stringWithFormat:@"if=pflash,unit=1,file=%@", self.efiVariablesURL.path]];
            [self accessDataWithBookmark:[self.efiVariablesURL bookmarkDataWithOptions:0
                                                        includingResourceValuesForKeys:nil
                                                                         relativeToURL:nil
                                                                                 error:nil]];
        }
    }
}

- (NSString *)expandDriveInterface:(NSString *)interface identifier:(NSString *)identifier removable:(BOOL)removable busInterfaceMap:(NSMutableDictionary<NSString *, NSNumber *> *)busInterfaceMap {
    NSInteger bootindex = [busInterfaceMap[@"boot"] integerValue];
    NSInteger busindex = [busInterfaceMap[interface] integerValue];
    if ([interface isEqualToString:@"ide"]) {
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"%@,bus=ide.%lu,drive=%@,bootindex=%lu", removable ? @"ide-cd" : @"ide-hd", busindex++, identifier, bootindex++]];
    } else if ([interface isEqualToString:@"scsi"]) {
        NSString *bus;
        if (self.isSparc) {
            bus = @"scsi";
        } else {
            bus = @"scsi0";
            if (busindex == 0) {
                [self pushArgv:@"-device"];
                [self pushArgv:@"lsi53c895a,id=scsi0"];
            }
        }
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"%@,bus=%@.0,channel=0,scsi-id=%lu,drive=%@,bootindex=%lu", removable ? @"scsi-cd" : @"scsi-hd", bus, busindex++, identifier, bootindex++]];
    } else if ([interface isEqualToString:@"virtio"]) {
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"%@,drive=%@,bootindex=%lu", [self.configuration.systemArchitecture isEqualToString:@"s390x"] ? @"virtio-blk-ccw" : @"virtio-blk-pci", identifier, bootindex++]];
    } else if ([interface isEqualToString:@"nvme"]) {
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"nvme,drive=%@,serial=%@,bootindex=%lu", identifier, identifier, bootindex++]];
    } else if ([interface isEqualToString:@"usb"]) {
        [self pushArgv:@"-device"];
        /// use usb 3 bus for virt system, unless using legacy input setting (this mirrors the code in argsForUsb)
        bool useUSB3 = !self.configuration.inputLegacy && [self.configuration.systemTarget hasPrefix:@"virt"];
        NSString *bus = useUSB3 ? @",bus=usb-bus.0" : @"";
        [self pushArgv:[NSString stringWithFormat:@"usb-storage,drive=%@,removable=%@,bootindex=%lu%@", identifier, removable ? @"true" : @"false", bootindex++, bus]];
    } else if ([interface isEqualToString:@"floppy"] && [self.configuration.systemTarget hasPrefix:@"q35"]) {
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"isa-fdc,id=fdc%lu,bootindexA=%lu", busindex, bootindex++]];
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"floppy,unit=0,bus=fdc%lu.0,drive=%@", busindex++, identifier]];
    } else {
        return interface; // no expand needed
    }
    busInterfaceMap[@"boot"] = @(bootindex);
    busInterfaceMap[interface] = @(busindex);
    return @"none";
}

- (void)argsForCpu {
    NSString *cpu = self.configuration.systemCPU;
    if ([cpu isEqualToString:@"default"]) {
        // if default and not hypervisor, we don't pass any -cpu argument for x86 and use host for ARM
        if (self.configuration.useHypervisor) {
#if !defined(__x86_64__)
            [self pushArgv:@"-cpu"];
            [self pushArgv:@"host"];
#endif
        } else if ([self.configuration.systemArchitecture isEqualToString:@"aarch64"]) {
            // ARM64 QEMU does not support "-cpu default" so we hard code a sensible default
            cpu = @"cortex-a72";
        } else if ([self.configuration.systemArchitecture isEqualToString:@"arm"]) {
            // ARM64 QEMU does not support "-cpu default" so we hard code a sensible default
            cpu = @"cortex-a15";
        }
    }
    if (cpu.length > 0 && ![cpu isEqualToString:@"default"]) {
        for (NSString *flag in self.configuration.systemCPUFlags) {
            unichar prefix = [flag characterAtIndex:0];
            if (prefix != '-' && prefix != '+') {
                cpu = [cpu stringByAppendingFormat:@",+%@", flag];
            } else {
                cpu = [cpu stringByAppendingFormat:@",%@", flag];
            }
        }
        [self pushArgv:@"-cpu"];
        [self pushArgv:cpu];
    }
    [self pushArgv:@"-smp"];
    [self pushArgv:[NSString stringWithFormat:@"cpus=%lu,sockets=1,cores=%lu,threads=%lu", self.emulatedCpuCount.threads, self.emulatedCpuCount.cpus, self.emulatedCpuCount.threads / self.emulatedCpuCount.cpus]];
}

- (void)argsForSound {
    if (self.configuration.soundEnabled) {
        if ([self.configuration.soundCard isEqualToString:@"screamer"]) {
#if !TARGET_OS_IPHONE
            // force CoreAudio backend for mac99 which only supports 44100 Hz
            [self pushArgv:@"-audiodev"];
            [self pushArgv:@"coreaudio,id=audio0"];
            // no device setting for screamer
#endif
        } else {
            [self pushArgv:@"-device"];
            [self pushArgv:self.configuration.soundCard];
            if ([self.configuration.soundCard containsString:@"hda"]) {
                [self pushArgv:@"-device"];
                [self pushArgv:@"hda-duplex"];
            }
        }
    }
}

- (void)argsForDrives {
    NSMutableDictionary<NSString *, NSNumber *> *busInterfaceMap = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < self.configuration.countDrives; i++) {
        NSString *path = [self.configuration driveImagePathForIndex:i];
        UTMDiskImageType type = [self.configuration driveImageTypeForIndex:i];
        BOOL hasImage = ![self.configuration driveRemovableForIndex:i] && path;
        NSURL *fullPathURL;
        
        if (hasImage) {
            if ([path characterAtIndex:0] == '/') {
                fullPathURL = [NSURL fileURLWithPath:path isDirectory:NO];
            } else {
                fullPathURL = [[self.imgPath URLByAppendingPathComponent:[UTMLegacyQemuConfiguration diskImagesDirectory]] URLByAppendingPathComponent:[self.configuration driveImagePathForIndex:i]];
            }
            [self accessDataWithBookmark:[fullPathURL bookmarkDataWithOptions:0
                                               includingResourceValuesForKeys:nil
                                                                relativeToURL:nil
                                                                        error:nil]];
        }
        
        switch (type) {
            case UTMDiskImageTypeDisk:
            case UTMDiskImageTypeCD: {
                NSString *interface = [self.configuration driveInterfaceTypeForIndex:i];
                BOOL removable = (type == UTMDiskImageTypeCD) || [self.configuration driveRemovableForIndex:i];
                NSString *identifier = [self.configuration driveNameForIndex:i];
                NSString *realInterface = [self expandDriveInterface:interface identifier:identifier removable:removable busInterfaceMap:busInterfaceMap];
                BOOL floppy = [realInterface containsString:@"floppy"];
                NSString *drive;
                [self pushArgv:@"-drive"];
                drive = [NSString stringWithFormat:@"if=%@,media=%@,id=%@", realInterface, (removable && !floppy) ? @"cdrom" : @"disk", identifier];
                if (hasImage) {
                    drive = [NSString stringWithFormat:@"%@,file=%@,discard=unmap,detect-zeroes=unmap", drive, fullPathURL.path];
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
            case UTMDiskImageTypeNone: {
                break; // ignore this image
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
        if (self.isSparc) {
            [self pushArgv:@"-net"];
            [self pushArgv:[NSString stringWithFormat:@"nic,model=lance,macaddr=%@,netdev=net0", self.configuration.networkCardMac]];
        } else {
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"%@,mac=%@,netdev=net0", self.configuration.networkCard, self.configuration.networkCardMac]];
        }
        [self pushArgv:@"-netdev"];
        NSMutableString *netstr;
        BOOL useVMnet = NO;
        if ([self.configuration.networkMode isEqualToString:@"shared"]) {
            useVMnet = YES;
            netstr = [NSMutableString stringWithString:@"vmnet-shared,id=net0"];
        } else if ([self.configuration.networkMode isEqualToString:@"bridged"]) {
            useVMnet = YES;
            netstr = [NSMutableString stringWithString:@"vmnet-bridged,id=net0"];
            NSString *interface = self.configuration.networkBridgeInterface;
            if (!interface) {
                interface = @"en0";
            }
            [netstr appendFormat:@",ifname=%@", interface];
        } else if ([self.configuration.networkMode isEqualToString:@"host"]) {
            useVMnet = YES;
            netstr = [NSMutableString stringWithString:@"vmnet-host,id=net0"];
        } else {
            netstr = [NSMutableString stringWithString:@"user,id=net0"];
        }
        if (self.configuration.networkIsolate) {
            if (useVMnet) {
                [netstr appendString:@",isolated=on"];
            } else {
                [netstr appendString:@",restrict=on"];
            }
        }
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
        if (!useVMnet) {
            for (NSUInteger i = 0; i < [self.configuration countPortForwards]; i++) {
                UTMLegacyQemuConfigurationPortForward *portForward = [self.configuration portForwardForIndex:i];
                [netstr appendFormat:@",hostfwd=%@:%@:%@-%@:%@", portForward.protocol, portForward.hostAddress, portForward.hostPort, portForward.guestAddress, portForward.guestPort];
            }
        }
        [self pushArgv:netstr];
    } else {
        [self pushArgv:@"-nic"];
        [self pushArgv:@"none"];
    }
}

- (void)argsForUsb {
    // set up USB input devices unless user requested legacy (QEMU default PS/2 input)
    if (self.configuration.inputLegacy) {
        return; // no USB in legacy input mode
    }
    if ([self.configuration.systemTarget hasPrefix:@"virt"]) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"nec-usb-xhci,id=usb-bus"];
    } else {
        [self pushArgv:@"-usb"];
    }
    [self pushArgv:@"-device"];
    [self pushArgv:@"usb-tablet,bus=usb-bus.0"];
    [self pushArgv:@"-device"];
    [self pushArgv:@"usb-mouse,bus=usb-bus.0"];
    [self pushArgv:@"-device"];
    [self pushArgv:@"usb-kbd,bus=usb-bus.0"];
#if !defined(WITH_QEMU_TCI)
    NSInteger maxDevices = [self.configuration.usbRedirectionMaximumDevices integerValue];
    if (self.configuration.usb3Support) {
        NSString *controller = @"qemu-xhci";
        if ([self.configuration.systemTarget hasPrefix:@"pc"] || [self.configuration.systemTarget hasPrefix:@"q35"]) {
            controller = @"nec-usb-xhci"; // Windows 7 doesn't like qemu-xchi
        }
        for (int j = 0; j < ((maxDevices + 2) / 3); j++) {
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"%@,id=usb-controller-%d", controller, j]];
        }
    } else {
        for (int j = 0; j < ((maxDevices + 2) / 3); j++) {
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"ich9-usb-ehci1,id=usb-controller-%d", j]];
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"ich9-usb-uhci1,masterbus=usb-controller-%d.0,firstport=0,multifunction=on", j]];
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"ich9-usb-uhci2,masterbus=usb-controller-%d.0,firstport=2,multifunction=on", j]];
            [self pushArgv:@"-device"];
            [self pushArgv:[NSString stringWithFormat:@"ich9-usb-uhci3,masterbus=usb-controller-%d.0,firstport=4,multifunction=on", j]];
        }
    }
    // set up usb forwarding
    for (int i = 0; i < maxDevices; i++) {
        [self pushArgv:@"-chardev"];
        [self pushArgv:[NSString stringWithFormat:@"spicevmc,name=usbredir,id=usbredirchardev%d", i]];
        [self pushArgv:@"-device"];
        [self pushArgv:[NSString stringWithFormat:@"usb-redir,chardev=usbredirchardev%d,id=usbredirdev%d,bus=usb-controller-%d.0", i, i, i / 3]];
    }
#endif
}

- (void)argsForSharing {
    if (self.configuration.shareClipboardEnabled || self.configuration.shareDirectoryEnabled || self.configuration.displayFitScreen) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtio-serial"];
    }
    
    if (self.configuration.shareClipboardEnabled || self.configuration.displayFitScreen) {
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
    NSInteger tb_size = self.configuration.systemMemory.integerValue / 4;
    if (self.configuration.systemJitCacheSize.integerValue > 0) {
        tb_size = self.configuration.systemJitCacheSize.integerValue;
    }
    accel = [accel stringByAppendingFormat:@",tb-size=%ld", tb_size];
    
#if !defined(WITH_QEMU_TCI)
    // use mirror mapping when we don't have JIT entitlements
    if (!jb_has_jit_entitlement()) {
        accel = [accel stringByAppendingString:@",split-wx=on"];
    }
#endif
    
    return accel;
}

- (BOOL)useOnlyPcores {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isUnset = ![defaults objectForKey:@"UseOnlyPcores"];
    return isUnset || [defaults boolForKey:@"UseOnlyPcores"];
}

- (BOOL)hasCustomBios {
    for (NSUInteger i = 0; i < self.configuration.countDrives; i++) {
        UTMDiskImageType type = [self.configuration driveImageTypeForIndex:i];
        NSString *interface = [self.configuration driveInterfaceTypeForIndex:i];
        switch (type) {
            case UTMDiskImageTypeDisk:
            case UTMDiskImageTypeCD: {
                if ([interface isEqualToString:@"pflash"]) {
                    return YES;
                }
                break;
            }
            case UTMDiskImageTypeBIOS:
            case UTMDiskImageTypeKernel: {
                return YES;
                break;
            }
            default: {
                continue;
            }
        }
    }
    return NO;
}

- (BOOL)usbSupported {
    NSString *arch = self.configuration.systemArchitecture;
    NSString *target = self.configuration.systemTarget;
    if ([target isEqualToString:@"isapc"]) {
        return NO;
    }
    if ([arch isEqualToString:@"s390x"]) {
        return NO;
    }
    if ([arch hasPrefix:@"sparc"]) {
        return NO;
    }
    return YES;
}

- (NSURL *)efiVariablesURL {
    return [[self.imgPath URLByAppendingPathComponent:[UTMLegacyQemuConfiguration diskImagesDirectory]] URLByAppendingPathComponent:UTMLegacyQemuConfiguration.efiVariablesFileName];
}

/// Set either name=value or does nothing if name= is already in `properties`
/// @param name Name of property to set
/// @param value Default value
/// @param properties Current properties
/// @returns `properties` unmodified if name is already set, otherwise name=value will be appended
- (NSString *)appendDefaultPropertyName:(NSString *)name value:(NSString *)value toProperties:(NSString *)properties {
    if (![properties containsString:[name stringByAppendingString:@"="]]) {
        properties = [NSString stringWithFormat:@"%@%@%@=%@", properties, properties.length > 0 ? @"," : @"", name, value];
    }
    return properties;
}

- (NSString *)machineProperties {
    NSString *target = self.configuration.systemTarget;
    NSString *architecture = self.configuration.systemArchitecture;
    NSString *properties = @"";
    if (self.configuration.systemMachineProperties.length > 0) {
        properties = self.configuration.systemMachineProperties; // use specified properties
    }
    if (([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"])) {
        properties = [self appendDefaultPropertyName:@"vmport" value:@"off" toProperties:properties];
        // disable PS/2 emulation if we are not legacy input and it's not explicitly enabled
        if (!self.configuration.inputLegacy && !self.configuration.forcePs2Controller) {
            properties = [self appendDefaultPropertyName:@"i8042" value:@"off" toProperties:properties];
        }
    }
    if (([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) && ![architecture hasPrefix:@"riscv"]) {
        if (@available(macOS 12.4, iOS 15.5, *)) {
            // default highmem value is fine here
        } else {
            // a kernel panic is triggered on M1 Max if highmem=on and running < macOS 12.4
            properties = [self appendDefaultPropertyName:@"highmem" value:@"off" toProperties:properties];
        }
        // required to boot Windows ARM on TCG
        if ([architecture isEqualToString:@"aarch64"] && !self.configuration.useHypervisor) {
            properties = [self appendDefaultPropertyName:@"virtualization" value:@"on" toProperties:properties];
        }
    }
    if ([target isEqualToString:@"mac99"]) {
        properties = [self appendDefaultPropertyName:@"via" value:@"pmu" toProperties:properties];
    }
    return properties;
}

- (BOOL)isGLOn {
    // GL supported devices have contains GL moniker
    return [self.configuration.displayCard containsString:@"-gl-"] ||
           [self.configuration.displayCard hasSuffix:@"-gl"];
}

- (BOOL)isSparc {
    return [self.configuration.systemArchitecture isEqualToString:@"sparc"];
}

- (void)argsRequired {
    [self clearArgv];
    [self pushArgv:@"-L"];
    [self accessDataWithBookmark:[self.resourceURL bookmarkDataWithOptions:0
                                            includingResourceValuesForKeys:nil
                                                             relativeToURL:nil
                                                                     error:nil]];
    [self pushArgv:self.resourceURL.path];
    [self pushArgv:@"-S"]; // startup stopped
    NSURL *spiceSocketURL = self.configuration.spiceSocketURL;
    [self pushArgv:@"-spice"];
    [self pushArgv:[NSString stringWithFormat:@"unix=on,addr=%@,disable-ticketing=on,image-compression=off,playback-compression=off,streaming-video=off,gl=%@", spiceSocketURL.path, self.isGLOn ? @"on" : @"off"]];
    [self pushArgv:@"-chardev"];
    [self pushArgv:@"spiceport,id=org.qemu.monitor.qmp,name=org.qemu.monitor.qmp.0"];
    [self pushArgv:@"-mon"];
    [self pushArgv:@"chardev=org.qemu.monitor.qmp,mode=control"];
    if (self.isSparc) { // SPARC uses -vga
        if (!self.configuration.displayConsoleOnly) {
            [self pushArgv:@"-vga"];
            [self pushArgv:self.configuration.displayCard];
        }
    } else { // disable -vga and other default devices
        // prevent QEMU default devices, which leads to duplicate CD drive (fix #2538)
        // see https://github.com/qemu/qemu/blob/6005ee07c380cbde44292f5f6c96e7daa70f4f7d/docs/qdev-device-use.txt#L382
        [self pushArgv:@"-nodefaults"];
        [self pushArgv:@"-vga"];
        [self pushArgv:@"none"];// -vga none, avoid adding duplicate graphics cards
    }
    if (self.configuration.displayConsoleOnly) {
        [self pushArgv:@"-nographic"];
        // terminal character device
        [self pushArgv: @"-chardev"];
        [self pushArgv: @"spiceport,id=term0,name=com.utmapp.terminal.0"];
        [self pushArgv: @"-serial"];
        [self pushArgv: @"chardev:term0"];
    } else {
        if (!self.isSparc) { // SPARC uses -vga (above)
            [self pushArgv:@"-device"];
            [self pushArgv:self.configuration.displayCard];
        }
    }
}

- (void)argsFromConfiguration {
    [self argsForCpu];
    [self pushArgv:@"-machine"];
    [self pushArgv:[NSString stringWithFormat:@"%@,%@", self.configuration.systemTarget, [self machineProperties]]];
    if (self.configuration.useHypervisor) {
        [self pushArgv:@"-accel"];
        [self pushArgv:@"hvf"];
    }
    [self pushArgv:@"-accel"];
    [self pushArgv:[self tcgAccelProperties]];
    [self architectureSpecificConfiguration];
    // legacy boot order; new bootindex uses drive ordering
    [self pushArgv:@"-boot"];
    if (self.configuration.systemBootDevice.length > 0 && ![self.configuration.systemBootDevice isEqualToString:@"hdd"]) {
        if ([self.configuration.systemBootDevice isEqualToString:@"floppy"]) {
            [self pushArgv:@"order=ab"];
        } else {
            [self pushArgv:@"order=d"];
        }
    } else {
        [self pushArgv:@"menu=on"];
    }
    [self pushArgv:@"-m"];
    [self pushArgv:[self.configuration.systemMemory stringValue]];
    [self argsForSound];
    [self pushArgv:@"-name"];
    [self pushArgv:self.configuration.name];
    if (self.usbSupported) {
        [self argsForUsb];
    }
    [self argsForDrives];
    [self argsForNetwork];
    if (self.snapshot) {
        [self pushArgv:@"-loadvm"];
        [self pushArgv:self.snapshot];
    }
    
    [self argsForSharing];
    
    if (self.configuration.systemUUID.length > 0) {
        [self pushArgv:@"-uuid"];
        [self pushArgv:self.configuration.systemUUID];
    }
    
    if (self.configuration.rtcUseLocalTime) {
        // fix windows time issues
        [self pushArgv:@"-rtc"];
        [self pushArgv:@"base=localtime"];
    }
    
    if (self.configuration.systemRngEnabled) {
        [self pushArgv:@"-device"];
        [self pushArgv:@"virtio-rng-pci"];
    }
    
    if (self.runAsSnapshot) {
        [self pushArgv:@"-snapshot"];
    }
}
    
- (void)argsFromUser {
    if (self.configuration.systemArguments.count != 0) {
        NSArray *addArgs = self.configuration.systemArguments;
        // Splits all spaces into their own, except when between quotes.
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"((?:[^\"\\s]*\"[^\"]*\"[^\"\\s]*)+|[^\"\\s]+)" options:0 error:nil];
        
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
                argFragment = [argFragment stringByReplacingOccurrencesOfString:@"\"" withString:@""];
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

- (void)updateArgvWithUserOptions:(BOOL)userOptions {
    [self argsRequired];
    if (!self.configuration.ignoreAllConfiguration) {
        [self argsFromConfiguration];
    }
    if (userOptions) {
        [self argsFromUser];
    }
}

- (BOOL)createEfiVariablesIfNeededWithError:(NSError **)error {
    NSString *arch = self.configuration.systemArchitecture;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *srcUrl = nil;
    if (![fileManager fileExistsAtPath:self.efiVariablesURL.path]) {
        if ([arch isEqualToString:@"arm"] || [arch isEqualToString:@"aarch64"]) {
            srcUrl = [self.resourceURL URLByAppendingPathComponent:@"edk2-arm-vars.fd"];
        } else if ([arch isEqualToString:@"i386"] || [arch isEqualToString:@"x86_64"]) {
            srcUrl = [self.resourceURL URLByAppendingPathComponent:@"edk2-i386-vars.fd"];
        } else {
            if (error) {
                *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"UEFI is not supported with this architecture.", "UTMQemuSystem")}];
            }
            return NO;
        }
        return [fileManager copyItemAtURL:srcUrl toURL:self.efiVariablesURL error:error];
    }
    return YES;
}

- (void)startWithCompletion:(void (^)(BOOL, NSString * _Nonnull))completion {
    NSError *err;
    if (self.configuration.systemBootUefi) {
        if (![self createEfiVariablesIfNeededWithError:&err]) {
            completion(NO, err.localizedDescription);
            return;
        }
    }
    [self updateArgvWithUserOptions:YES];
    NSString *name = [NSString stringWithFormat:@"qemu-%@-softmmu", self.configuration.systemArchitecture];
    [self startQemu:name completion:completion];
}

@end
