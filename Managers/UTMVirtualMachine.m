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

#import "UTMVirtualMachine.h"
#import "UTMConfiguration.h"
#import "UTMViewState.h"
#import "UTMQemuImg.h"
#import "UTMQemuManager.h"
#import "UTMQemuSystem.h"
#import "UTMLogging.h"
#import "CocoaSpice.h"

const int kMaxConnectionTries = 10; // qemu needs to start spice server first
const int64_t kStopTimeout = (int64_t)30*1000000000;

NSString *const kUTMErrorDomain = @"com.osy86.utm";
NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";
NSString *const kUTMBundleViewFilename = @"view.plist";

@interface UTMVirtualMachine ()

@property (nonatomic) UTMViewState *viewState;
@property (nonatomic, weak) UTMLogging *logging;

- (NSURL *)packageURLForName:(NSString *)name;

@end

@implementation UTMVirtualMachine {
    UTMQemuSystem *_qemu_system;
    CSConnection *_spice_connection;
    CSMain *_spice;
    dispatch_semaphore_t _will_quit_sema;
    dispatch_semaphore_t _qemu_exit_sema;
    BOOL _is_busy;
}

@synthesize busy = _is_busy;

- (void)setDelegate:(id<UTMVirtualMachineDelegate>)delegate {
    _delegate = delegate;
    _delegate.vmDisplay = self.primaryDisplay;
    _delegate.vmInput = self.primaryInput;
    _delegate.vmConfiguration = self.configuration;
    [self restoreViewState];
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
        _will_quit_sema = dispatch_semaphore_create(0);
        _qemu_exit_sema = dispatch_semaphore_create(0);
        self.logging = [UTMLogging sharedInstance];
    }
    return self;
}

- (id)initWithURL:(NSURL *)url {
    self = [self init];
    if (self) {
        self.parentPath = url.URLByDeletingLastPathComponent;
        NSString *name = [UTMVirtualMachine virtualMachineName:url];
        NSMutableDictionary *plist = [self loadPlist:[url URLByAppendingPathComponent:kUTMBundleConfigFilename] withError:nil];
        if (!plist) {
            self = nil;
            return self;
        }
        _configuration = [[UTMConfiguration alloc] initWithDictionary:plist name:name path:url];
        [self loadViewState:url];
    }
    return self;
}

- (id)initDefaults:(NSString *)name withDestinationURL:(NSURL *)dstUrl {
    self = [self init];
    if (self) {
        self.parentPath = dstUrl;
        _configuration = [[UTMConfiguration alloc] initDefaults:name];
        self.viewState = [[UTMViewState alloc] initDefaults];
    }
    return self;
}

- (void)changeState:(UTMVMState)state {
    @synchronized (self) {
        _state = state;
        [self.delegate virtualMachine:self transitionToState:state];
    }
}

- (NSURL *)packageURLForName:(NSString *)name {
    return [[self.parentPath URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (BOOL)saveUTMWithError:(NSError * _Nullable *)err {
    NSURL *url = [self packageURLForName:self.configuration.name];
    __block NSError *_err;
    if (!self.configuration.existingPath) { // new package
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&_err];
        if (_err && err) {
            *err = _err;
            return NO;
        }
    } else if (![self.configuration.existingPath.URLByStandardizingPath isEqual:url.URLByStandardizingPath]) { // rename if needed
        [[NSFileManager defaultManager] moveItemAtURL:self.configuration.existingPath toURL:url error:&_err];
        if (_err && err) {
            *err = _err;
            return NO;
        }
        self.configuration.existingPath = url;
    }
    if (![self savePlist:[url URLByAppendingPathComponent:kUTMBundleConfigFilename]
                    dict:self.configuration.dictRepresentation
               withError:err]) {
        return NO;
    }
    // create disk images directory
    if (!self.configuration.existingPath) {
        NSURL *dstPath = [url URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
        NSURL *tmpPath = [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
        
        // create images directory
        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath.path]) {
            [[NSFileManager defaultManager] moveItemAtURL:tmpPath toURL:dstPath error:&_err];
        } else {
            [[NSFileManager defaultManager] createDirectoryAtURL:dstPath withIntermediateDirectories:NO attributes:nil error:&_err];
        }
        if (_err && err) {
            *err = _err;
            return NO;
        }
    }
    return YES;
}

- (void)errorTriggered:(nullable NSString *)msg {
    [self quitVM];
    self.delegate.vmMessage = msg;
    [self changeState:kVMError];
}

- (void)startVM {
    @synchronized (self) {
        if (self.busy || self.state != kVMStopped) {
            return; // already started
        } else {
            _is_busy = YES;
        }
    }
    // start logging
    if (self.configuration.debugLogEnabled) {
        NSURL *url = [self packageURLForName:self.configuration.name];
        [self.logging logToFile:[url URLByAppendingPathComponent:[UTMConfiguration debugLogName]]];
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
        _spice_connection.audioEnabled = _configuration.soundEnabled;
    }
    if (!_qemu_system || !_spice || !_spice_connection) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting VM.", @"UTMVirtualMachine")];
        _is_busy = NO;
        return;
    }
    _spice_connection.glibMainContext = _spice.glibMainContext;
    self.delegate.vmMessage = nil;
    self.delegate.vmScreenshot = nil;
    self.delegate.vmDisplay = nil;
    self.delegate.vmInput = nil;
    _primaryDisplay = nil;
    
    [self changeState:kVMStarting];
    if (self.configuration.debugLogEnabled) {
        [_spice spiceSetDebug:YES]; // only if debug logging
    }
    if (![_spice spiceStart]) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting main loop.", @"UTMVirtualMachine")];
        _is_busy = NO;
        return;
    }
    [_qemu_system startWithCompletion:^(BOOL success, NSString *msg){
        if (!success) {
            [self errorTriggered:msg];
        }
        dispatch_semaphore_signal(self->_qemu_exit_sema);
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
    _is_busy = NO;
}

- (void)quitVM {
    @synchronized (self) {
        if (self.busy || self.state != kVMStarted) {
            return; // already stopping
        } else {
            _is_busy = YES;
        }
    }
    [self syncViewState];
    [self changeState:kVMStopping];
    
    [_qemu vmQuitWithCompletion:nil];
    if (dispatch_semaphore_wait(_will_quit_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        // TODO: force shutdown
        NSLog(@"Stop operation timeout");
    }
    [_qemu disconnect];
    _qemu.delegate = nil;
    _qemu = nil;
    
    [_spice_connection disconnect];
    _spice_connection.delegate = nil;
    _spice_connection = nil;
    [_spice spiceStop];
    _spice = nil;
    
    if (dispatch_semaphore_wait(_qemu_exit_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        // TODO: force shutdown
        NSLog(@"Exit operation timeout");
    }
    _qemu_system = nil;
    [self changeState:kVMStopped];
    // save view settings
    [self saveViewState];
    // stop logging
    [self.logging endLog];
    _is_busy = NO;
}

#pragma mark - Spice connection delegate

- (void)spiceConnected:(CSConnection *)connection {
    NSLog(@"spiceConnected");
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceDisconnected:(CSConnection *)connection {
    NSLog(@"spiceDisconnected");
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceError:(CSConnection *)connection err:(NSString *)msg {
    NSLog(@"spiceError");
    NSAssert(connection == _spice_connection, @"Unknown connection");
    [self errorTriggered:msg];
}

- (void)spiceDisplayCreated:(CSConnection *)connection display:(CSDisplayMetal *)display input:(CSInput *)input {
    NSLog(@"spiceDisplayCreated");
    NSAssert(connection == _spice_connection, @"Unknown connection");
    if (display.channelID == 0 && display.monitorID == 0) {
        self.delegate.vmDisplay = display;
        self.delegate.vmInput = input;
        _primaryDisplay = display;
        _primaryInput = input;
        [self changeState:kVMStarted];
        [self restoreViewState];
    }
}

#pragma mark - Qemu manager delegate

- (void)qemuHasWakeup:(UTMQemuManager *)manager {
    NSLog(@"qemuHasWakeup");
}

- (void)qemuHasResumed:(UTMQemuManager *)manager {
    NSLog(@"qemuHasResumed");
}

- (void)qemuHasStopped:(UTMQemuManager *)manager {
    NSLog(@"qemuHasStopped");
}

- (void)qemuHasReset:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason {
    NSLog(@"qemuHasReset, reason = %s", ShutdownCause_str(reason));
}

- (void)qemuHasSuspended:(UTMQemuManager *)manager {
    NSLog(@"qemuHasSuspended");
}

- (void)qemuWillQuit:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason {
    NSLog(@"qemuWillQuit, reason = %s", ShutdownCause_str(reason));
    dispatch_semaphore_signal(_will_quit_sema);
    if (!_is_busy) {
        [self quitVM];
    }
}

#pragma mark - Plist Handling

- (NSMutableDictionary *)loadPlist:(NSURL *)path withError:(NSError **)err {
    NSData *data = [NSData dataWithContentsOfURL:path];
    if (!data) {
        if (err) {
            *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to load plist", @"UTMVirtualMachine")}];
        }
        return nil;
    }
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:err];
    if (err) {
        return nil;
    }
    if (![plist isKindOfClass:[NSMutableDictionary class]]) {
        return nil;
    }
    return plist;
}

- (BOOL)savePlist:(NSURL *)path dict:(NSDictionary *)dict withError:(NSError **)err {
    NSError *_err;
    // serialize plist
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&_err];
    if (_err && err) {
        *err = _err;
        return NO;
    }
    // write plist
    [data writeToURL:path options:NSDataWritingAtomic error:&_err];
    if (_err && err) {
        *err = _err;
        return NO;
    }
    return YES;
}

#pragma mark - View State

- (void)syncViewState {
    self.viewState.displayOriginX = self.primaryDisplay.viewportOrigin.x;
    self.viewState.displayOriginY = self.primaryDisplay.viewportOrigin.y;
    self.viewState.displayScale = self.primaryDisplay.viewportScale;
    self.viewState.showToolbar = self.delegate.toolbarVisible;
    self.viewState.showKeyboard = self.delegate.keyboardVisible;
}

- (void)restoreViewState {
    self.primaryDisplay.viewportOrigin = CGPointMake(self.viewState.displayOriginX, self.viewState.displayOriginY);
    self.primaryDisplay.viewportScale = self.viewState.displayScale;
    self.delegate.toolbarVisible = self.viewState.showToolbar;
    self.delegate.keyboardVisible = self.viewState.showKeyboard;
}

- (void)loadViewState:(NSURL *)url {
    NSMutableDictionary *plist = [self loadPlist:[url URLByAppendingPathComponent:kUTMBundleViewFilename] withError:nil];
    if (plist) {
        self.viewState = [[UTMViewState alloc] initWithDictionary:plist];
    } else {
        self.viewState = [[UTMViewState alloc] initDefaults];
    }
}

- (void)saveViewState {
    NSURL *url = [self packageURLForName:self.configuration.name];
    [self savePlist:[url URLByAppendingPathComponent:kUTMBundleViewFilename]
               dict:self.viewState.dictRepresentation
          withError:nil];
}

@end
