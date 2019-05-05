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

#import "UTMVirtualMachine.h"
#import "UTMConfiguration.h"
#import "UTMQemuImg.h"
#import "UTMQemuManager.h"
#import "UTMQemuSystem.h"
#import "CocoaSpice.h"

const int kMaxConnectionTries = 10; // qemu needs to start spice server first
const int64_t kStopTimeout = (int64_t)30*1000000000;

NSString *const kUTMErrorDomain = @"com.halts.utm";
NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";

@interface UTMVirtualMachine ()

- (NSURL *)packageURLForName:(NSString *)name;

@end

@implementation UTMVirtualMachine {
    UTMQemuSystem *_qemu_system;
    CSConnection *_spice_connection;
    CSMain *_spice;
    dispatch_semaphore_t _stop_request_sema;
    BOOL _is_stopping;
}

- (void)setDelegate:(id<UTMVirtualMachineDelegate>)delegate {
    _delegate = delegate;
    _delegate.vmRendering = self.primaryRendering;
}

+ (BOOL)URLisVirtualMachine:(NSURL *)url {
    return [url.pathExtension isEqualToString:kUTMBundleExtension];
}

+ (NSString *)virtualMachineName:(NSURL *)url {
    return [[[NSFileManager defaultManager] displayNameAtPath:url.path] stringByDeletingPathExtension];
}

+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent {
    return [[parent URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (id)init {
    self = [super init];
    if (self) {
        _stop_request_sema = dispatch_semaphore_create(0);
    }
    return self;
}

- (id)initWithURL:(NSURL *)url {
    self = [self init];
    if (self) {
        self.parentPath = url.URLByDeletingLastPathComponent;
        NSString *name = [UTMVirtualMachine virtualMachineName:url];
        NSError *err;
        NSData *data = [NSData dataWithContentsOfURL:[url URLByAppendingPathComponent:kUTMBundleConfigFilename]];
        id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:&err];
        if (err) {
            NSLog(@"Error reading %@: %@\n", url, err.localizedDescription);
            self = nil;
            return self;
        }
        if (![plist isKindOfClass:[NSMutableDictionary class]]) {
            NSLog(@"Wrong data format %@!\n", url);
            self = nil;
            return self;
        }
        _configuration = [[UTMConfiguration alloc] initWithDictionary:plist name:name];
    }
    return self;
}

- (id)initDefaults:(NSString *)name withDestinationURL:(NSURL *)dstUrl {
    self = [self init];
    if (self) {
        self.parentPath = dstUrl;
        _configuration = [[UTMConfiguration alloc] initDefaults:name];
    }
    return self;
}

- (void)changeState:(UTMVMState)state {
    _state = state;
    [self.delegate virtualMachine:self transitionToState:state];
}

- (NSURL *)packageURLForName:(NSString *)name {
    return [[self.parentPath URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (BOOL)saveUTMWithError:(NSError * _Nullable *)err {
    NSURL *url = [self packageURLForName:self.configuration.changeName];
    __block NSError *_err;
    if (!self.configuration.name) { // new package
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&_err];
        if (_err && err) {
            *err = _err;
            return NO;
        }
        self.configuration.name = self.configuration.changeName;
    } else if (![self.configuration.name isEqualToString:self.configuration.changeName]) { // rename if needed
        [[NSFileManager defaultManager] moveItemAtURL:[self packageURLForName:self.configuration.name] toURL:url error:&_err];
        if (_err && err) {
            *err = _err;
            return NO;
        }
        self.configuration.name = self.configuration.changeName;
    }
    // serialize config.plist
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self.configuration.dictRepresentation format:NSPropertyListXMLFormat_v1_0 options:0 error:&_err];
    if (_err && err) {
        *err = _err;
        return NO;
    }
    // write config.plist
    [data writeToURL:[url URLByAppendingPathComponent:kUTMBundleConfigFilename] options:NSDataWritingAtomic error:&_err];
    if (_err && err) {
        *err = _err;
        return NO;
    }
    // create disk images
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    for (NSUInteger i = 0; i < self.configuration.countDrives; i++) {
        UTMNewDrive *newDrive = [self.configuration driveNewParamsAtIndex:i];
        if (newDrive.valid) {
            UTMQemuImg *imgCreate = [[UTMQemuImg alloc] init];
            imgCreate.op = kUTMQemuImgCreate;
            imgCreate.outputPath = [url URLByAppendingPathComponent:[self.configuration driveImagePathForIndex:i]];
            imgCreate.sizeMiB = newDrive.sizeMB;
            imgCreate.compressed = newDrive.isQcow2;
            [imgCreate startWithCompletion:^(BOOL success, NSString *msg){
                if (!success) {
                    if (!msg) {
                        msg = NSLocalizedString(@"Disk creation failed.", "Alert message");
                    }
                    _err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: msg}];
                }
                dispatch_semaphore_signal(sema);
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
    }
    if (_err && err) {
        *err = _err;
        return NO;
    }
    return YES;
}

- (void)errorTriggered:(nullable NSString *)msg {
    [self quitVM];
    self.delegate.vmMessage = msg;
    [self changeState:kVMError];
}

- (void)startVM {
    if (self.state != kVMStopped) {
        return; // already started
    }
    if (!_qemu_system) {
        _qemu_system = [[UTMQemuSystem alloc] initWithConfiguration:self.configuration imgPath:[self packageURLForName:self.configuration.name]];
        _qemu = [[UTMQemuManager alloc] init];
        _qemu.delegate = self;
    }
    if (!_spice) {
        _spice = [[CSMain alloc] init];
    }
    if (!_spice_connection) {
        _spice_connection = [[CSConnection alloc] initWithHost:@"127.0.0.1" port:@"5930"];
        _spice_connection.delegate = self;
    }
    if (!_qemu_system || !_spice || !_spice_connection) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting VM.", @"UTMVirtualMachine")];
        return;
    }
    _spice_connection.glibMainContext = _spice.glibMainContext;
    self.delegate.vmMessage = nil;
    self.delegate.vmScreenshot = nil;
    self.delegate.vmRendering = nil;
    _primaryRendering = nil;
    
    [self changeState:kVMStarting];
    [_spice spiceSetDebug:YES];
    if (![_spice spiceStart]) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting main loop.", @"UTMVirtualMachine")];
        return;
    }
    [_qemu_system startWithCompletion:^(BOOL success, NSString *msg){
        if (!success) {
            [self errorTriggered:msg];
        } else {
        }
    }];
    int tries = kMaxConnectionTries;
    do {
        [NSThread sleepForTimeInterval:0.1f];
        if ([_spice_connection connect]) {
            break;
        }
    } while (tries-- > 0);
    if (tries == 0) {
        [self errorTriggered:NSLocalizedString(@"Failed to connect to display server.", @"UTMVirtualMachine")];
    }
    [self->_qemu connect];
}

- (void)quitVM {
    if (_is_stopping || self.state != kVMStarted) {
        return; // already stopping
    } else {
        _is_stopping = YES;
    }
    [self changeState:kVMStopping];
    
    [_qemu vmStopWithCompletion:nil];
    if (!dispatch_semaphore_wait(_stop_request_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout))) {
        // force shutdown
        [_qemu vmQuitWithCompletion:nil];
    }
    [_qemu disconnect];
    _qemu.delegate = nil;
    _qemu = nil;
    
    [_spice_connection disconnect];
    _spice_connection.delegate = nil;
    _spice_connection = nil;
    [_spice spiceStop];
    _spice = nil;
    
    _qemu_system = nil; // should be stopped by vmQuit
    _is_stopping = NO;
    [self changeState:kVMStopped];
}

#pragma mark - Spice connection delegate

- (void)spiceConnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceDisconnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceError:(CSConnection *)connection err:(NSString *)msg {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    [self errorTriggered:msg];
}

- (void)spiceDisplayCreated:(CSConnection *)connection display:(CSDisplayMetal *)display input:(CSInput *)input {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    if (display.channelID == 0 && display.monitorID == 0) {
        self.delegate.vmRendering = display;
        _primaryRendering = display;
        _primaryInput = input;
        [self changeState:kVMStarted];
    }
}

#pragma mark - Qemu manager delegate

- (void)qemuHasWakeup:(UTMQemuManager *)manager {
    
}

- (void)qemuHasResumed:(UTMQemuManager *)manager {
    
}

- (void)qemuHasStopped:(UTMQemuManager *)manager {
    dispatch_semaphore_signal(_stop_request_sema);
    if (!_is_stopping) {
        [self quitVM];
    }
}

- (void)qemuHasReset:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason {
    
}

- (void)qemuHasSuspended:(UTMQemuManager *)manager {
    
}

@end
