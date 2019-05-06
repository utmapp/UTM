//
// Copyright © 2019 Halts. All rights reserved.
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
#import "UTMConfiguration.h"

@implementation UTMQemuSystem

- (id)initWithConfiguration:(UTMConfiguration *)configuration imgPath:(nonnull NSURL *)imgPath {
    self = [self init];
    if (self) {
        self.configuration = configuration;
        self.imgPath = imgPath;
    }
    return self;
}

- (void)argsFromConfiguration {
    [self clearArgv];
    [self pushArgv:@"qemu"];
    [self pushArgv:@"-L"];
    [self pushArgv:[[NSBundle mainBundle] URLForResource:@"qemu" withExtension:nil].path];
    [self pushArgv:@"-qmp"];
    [self pushArgv:@"tcp:localhost:4444,server,nowait"];
    [self pushArgv:@"-smp"];
    [self pushArgv:[NSString stringWithFormat:@"cpus=%@", self.configuration.systemCPUCount]];
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
        [self pushArgv:@"hda"];
    }
    [self pushArgv:@"-name"];
    [self pushArgv:self.configuration.name];
    for (NSUInteger i = 0; i < self.configuration.countDrives; i++) {
        NSString *path = [self.configuration driveImagePathForIndex:i];
        NSURL *fullPathURL;
        
        if ([path characterAtIndex:0] == '/') {
            fullPathURL = [NSURL fileURLWithPath:path isDirectory:NO];
        } else {
            fullPathURL = [[self.imgPath URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory]] URLByAppendingPathComponent:[self.configuration driveImagePathForIndex:i]];
        }
        [self pushArgv:@"-drive"];
        [self pushArgv:[NSString stringWithFormat:@"file=%@,if=%@,media=%@", fullPathURL.path, [self.configuration driveInterfaceTypeForIndex:i], [self.configuration driveIsCdromForIndex:i] ? @"cdrom" : @"disk"]];
    }
    if (self.configuration.displayConsoleOnly) {
        [self pushArgv:@"-display"];
        [self pushArgv:@"curses"];
    } else {
        [self pushArgv:@"-spice"];
        [self pushArgv:@"port=5930,addr=127.0.0.1,disable-ticketing,image-compression=off,playback-compression=off,streaming-video=filter"];
        [self pushArgv:@"-vga"];
        [self pushArgv:@"qxl"];
    }
    if (self.configuration.networkEnabled) {
        [self pushArgv:@"-netdev"];
        NSMutableString *netstr = [NSMutableString stringWithString:@"user,id=net0"];
        if (self.configuration.networkIPSubnet) {
            [netstr appendFormat:@",net=%@", self.configuration.networkIPSubnet];
        }
        if (self.configuration.networkDHCPStart) {
            [netstr appendFormat:@",dhcpstart=%@", self.configuration.networkDHCPStart];
        }
        if (self.configuration.networkLocalhostOnly) {
            [netstr appendString:@"restrict=on"];
        }
        [self pushArgv:netstr];
    }
}

- (void)startWithCompletion:(void (^)(BOOL, NSString * _Nonnull))completion {
    NSString *dylib = [NSString stringWithFormat:@"libqemu-system-%@.dylib", self.configuration.systemArchitecture];
    [self argsFromConfiguration];
    [self startDylib:dylib main:@"qemu_main" completion:completion];
}

@end
