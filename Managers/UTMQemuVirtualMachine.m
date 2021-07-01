//
// Copyright © 2021 osy. All rights reserved.
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

#import <TargetConditionals.h>
#import "UTMVirtualMachine-Private.h"
#import "UTMQemuVirtualMachine.h"
#import "UTMQemuVirtualMachine+Drives.h"
#import "UTMQemuVirtualMachine+SPICE.h"
#import "UTMQemuConfiguration.h"
#import "UTMQemuConfiguration+Constants.h"
#import "UTMQemuConfiguration+Display.h"
#import "UTMQemuConfiguration+Drives.h"
#import "UTMQemuConfiguration+Miscellaneous.h"
#import "UTMViewState.h"
#import "UTMQemuManager.h"
#import "UTMQemuSystem.h"
#import "UTMTerminalIO.h"
#import "UTMSpiceIO.h"
#import "UTMLogging.h"
#import "UTMScreenshot.h"
#import "UTMPortAllocator.h"
#import "qapi-events.h"

const int kQMPMaxConnectionTries = 30; // qemu needs to start spice server first
const int64_t kStopTimeout = (int64_t)30*NSEC_PER_SEC;

extern NSString *const kUTMBundleConfigFilename;
NSString *const kSuspendSnapshotName = @"suspend";


@interface UTMQemuVirtualMachine ()

@property (nonatomic, readonly) UTMQemuManager *qemu;
@property (nonatomic, readwrite, nullable) UTMQemuSystem *system;
@property (nonatomic, readonly, nullable) id<UTMInputOutput> ioService;

@end

@implementation UTMQemuVirtualMachine {
    dispatch_semaphore_t _will_quit_sema;
    dispatch_semaphore_t _qemu_exit_sema;
}

- (UTMQemuConfiguration *)qemuConfig {
    return (UTMQemuConfiguration *)self.config;
}

- (id)ioDelegate {
    if ([self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        return ((UTMSpiceIO *)self.ioService).delegate;
    } else if ([self.ioService isKindOfClass:[UTMTerminalIO class]]) {
        return ((UTMTerminalIO *)self.ioService).terminal.delegate;
    } else {
        return nil;
    }
}

- (void)setIoDelegate:(id)ioDelegate {
    if ([self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        ((UTMSpiceIO *)self.ioService).delegate = ioDelegate;
    } else if ([self.ioService isKindOfClass:[UTMTerminalIO class]]) {
        ((UTMTerminalIO *)self.ioService).terminal.delegate = ioDelegate;
    } else if (self.state == kVMStarted) {
        NSAssert(0, @"ioService class is invalid: %@", NSStringFromClass([self.ioService class]));
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _will_quit_sema = dispatch_semaphore_create(0);
        _qemu_exit_sema = dispatch_semaphore_create(0);
    }
    return self;
}

#pragma mark - Configuration

- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err {
    NSAssert(self.path != nil, @"Cannot load configuration on an unsaved VM.");
    NSString *name = [UTMVirtualMachine virtualMachineName:self.path];
    NSDictionary *plist = [self loadPlist:[self.path URLByAppendingPathComponent:kUTMBundleConfigFilename] withError:err];
    if (!plist) {
        UTMLog(@"Failed to parse config for %@, error: %@", self.path, err ? *err : nil);
        return NO;
    }
    if (reload) {
        NSAssert(self.qemuConfig != nil, @"Trying to reload when no configuration is loaded.");
        [self.qemuConfig reloadConfigurationWithDictionary:plist name:name path:self.path];
    } else {
        self.config = [[UTMQemuConfiguration alloc] initWithDictionary:plist name:name path:self.path];
    }
    return [super loadConfigurationWithReload:reload error:err];
}

- (BOOL)saveConfigurationWithError:(NSError * _Nullable __autoreleasing *)err {
    NSURL *url = [self packageURLForName:self.config.name];
    if (![self savePlist:[url URLByAppendingPathComponent:kUTMBundleConfigFilename]
                    dict:self.qemuConfig.dictRepresentation
               withError:err]) {
        return NO;
    }
    return [super saveConfigurationWithError:err];
}

- (BOOL)saveIconWithError:(NSError * _Nullable __autoreleasing *)err {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [self packageURLForName:self.qemuConfig.name];
    if (self.qemuConfig.iconCustom && self.qemuConfig.selectedCustomIconPath) {
        NSURL *oldIconPath = [url URLByAppendingPathComponent:self.qemuConfig.icon];
        NSString *newIcon = self.qemuConfig.selectedCustomIconPath.lastPathComponent;
        NSURL *newIconPath = [url URLByAppendingPathComponent:newIcon];
        
        // delete old icon
        if ([fileManager fileExistsAtPath:oldIconPath.path]) {
            [fileManager removeItemAtURL:oldIconPath error:nil]; // ignore error
        }
        // copy new icon
        if (![fileManager copyItemAtURL:self.qemuConfig.selectedCustomIconPath toURL:newIconPath error:err]) {
            return NO;
        }
        // commit icon
        self.qemuConfig.icon = newIcon;
        self.qemuConfig.selectedCustomIconPath = nil;
    }
    return [super saveIconWithError:err];
}

- (BOOL)saveDisksWithError:(NSError * _Nullable __autoreleasing *)err {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [self packageURLForName:self.qemuConfig.name];
    if (!self.qemuConfig.existingPath) {
        NSURL *dstPath = [url URLByAppendingPathComponent:[UTMQemuConfiguration diskImagesDirectory] isDirectory:YES];
        NSURL *tmpPath = [fileManager.temporaryDirectory URLByAppendingPathComponent:[UTMQemuConfiguration diskImagesDirectory] isDirectory:YES];
        
        // create images directory
        if ([fileManager fileExistsAtPath:tmpPath.path]) {
            // delete any orphaned images
            NSArray<NSString *> *orphans = self.qemuConfig.orphanedDrives;
            for (NSInteger i = 0; i < orphans.count; i++) {
                NSURL *orphanPath = [tmpPath URLByAppendingPathComponent:orphans[i]];
                UTMLog(@"Deleting orphaned image '%@'", orphans[i]);
                if (![fileManager removeItemAtURL:orphanPath error:nil]) {
                    UTMLog(@"Ignoring error deleting orphaned image");
                }
            }
            // move remaining drives to VM package
            if (![fileManager moveItemAtURL:tmpPath toURL:dstPath error:err]) {
                return NO;
            }
        } else if (![fileManager fileExistsAtPath:dstPath.path]) {
            if (![fileManager createDirectoryAtURL:dstPath withIntermediateDirectories:NO attributes:nil error:err]) {
                return NO;
            }
        }
    }
    return [super saveDisksWithError:err];
}

#pragma mark - VM actions

- (BOOL)startVM {
    @synchronized (self) {
        if (self.busy || (self.state != kVMStopped && self.state != kVMSuspended)) {
            return NO; // already started
        } else {
            self.busy = YES;
        }
    }
    // start logging
    if (self.qemuConfig.debugLogEnabled) {
        [self.logging logToFile:[self.path URLByAppendingPathComponent:[UTMQemuConfiguration debugLogName]]];
    }
    
    if (!self.system) {
        self.system = [[UTMQemuSystem alloc] initWithConfiguration:self.qemuConfig imgPath:self.path];
        self.system.logging = self.logging;
#if !TARGET_OS_IPHONE
        [self.system setupXpc];
#endif
        self.system.qmpPort = [[UTMPortAllocator sharedInstance] allocatePort];
        self.system.spicePort = [[UTMPortAllocator sharedInstance] allocatePort];
        _qemu = [[UTMQemuManager alloc] initWithPort:self.system.qmpPort];
        _qemu.delegate = self;
    }

    if (!self.system) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting VM.", @"UTMVirtualMachine")];
        self.busy = NO;
        return NO;
    }
    
    if (!_ioService) {
        _ioService = [self inputOutputServiceWithPort:self.system.spicePort];
    }
    
    self.delegate.vmMessage = nil;
    [self changeState:kVMStarting];
    if (self.qemuConfig.debugLogEnabled) {
        [_ioService setDebugMode:YES];
    }
    
    BOOL ioStatus = [_ioService startWithError: nil];
    if (!ioStatus) {
        [self errorTriggered:NSLocalizedString(@"Internal error starting main loop.", @"UTMVirtualMachine")];
        self.busy = NO;
        return NO;
    }
    if (self.viewState.suspended) {
        self.system.snapshot = kSuspendSnapshotName;
    }
    [self.system startWithCompletion:^(BOOL success, NSString *msg){
        if (!success) {
            [self errorTriggered:msg];
        }
        dispatch_semaphore_signal(self->_qemu_exit_sema);
    }];
    [self->_ioService connectWithCompletion:^(BOOL success, NSString * _Nullable msg) {
        if (!success) {
            [self errorTriggered:msg];
        } else {
            [self changeState:kVMStarted];
            [self restoreViewState];
            if (self.viewState.suspended) {
                [self deleteSaveVM];
            }
        }
    }];
    self->_qemu.retries = kQMPMaxConnectionTries;
    [self->_qemu connect];
    self.busy = NO;
    return YES;
}

- (BOOL)quitVMForce:(BOOL)force {
    @synchronized (self) {
        if (!force && (self.busy || self.state != kVMStarted)) {
            return NO; // already stopping
        } else {
            self.busy = YES;
        }
    }
    self.viewState.suspended = NO;
    [self syncViewState];
    if (!force) {
        [self changeState:kVMStopping];
    }
    // save view settings early to win exit race
    [self saveViewState];
    
    _qemu.retries = 0;
    [_qemu vmQuitWithCompletion:nil];
    if (force || dispatch_semaphore_wait(_will_quit_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Stop operation timeout or force quit");
    }
    [_qemu disconnect];
    _qemu.delegate = nil;
    _qemu = nil;
    [_ioService disconnect];
    _ioService = nil;
    
    if (force || dispatch_semaphore_wait(_qemu_exit_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Exit operation timeout or force quit");
    }
    [self.system stopQemu];
    if (self.system.qmpPort) {
        [[UTMPortAllocator sharedInstance] freePort:self.system.qmpPort];
        self.system.qmpPort = 0;
    }
    if (self.system.spicePort) {
        [[UTMPortAllocator sharedInstance] freePort:self.system.spicePort];
        self.system.spicePort = 0;
    }
    self.system = nil;
    [self changeState:kVMStopped];
    // stop logging
    [self.logging endLog];
    self.busy = NO;
    return YES;
}

- (BOOL)resetVM {
    @synchronized (self) {
        if (self.busy || (self.state != kVMStarted && self.state != kVMPaused)) {
            return NO; // already stopping
        } else {
            self.busy = YES;
        }
    }
    [self syncViewState];
    [self changeState:kVMStopping];
    if (self.viewState.suspended) {
        [self deleteSaveVM];
    }
    [self saveViewState];
    __block BOOL success = YES;
    dispatch_semaphore_t reset_sema = dispatch_semaphore_create(0);
    [_qemu vmResetWithCompletion:^(NSError *err) {
        UTMLog(@"reset callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            success = NO;
        }
        dispatch_semaphore_signal(reset_sema);
    }];
    if (dispatch_semaphore_wait(reset_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Reset operation timeout");
        success = NO;
    }
    if (success) {
        [self changeState:kVMStarted];
    } else {
        [self changeState:kVMError];
    }
    self.busy = NO;
    return success;
}

- (BOOL)pauseVM {
    @synchronized (self) {
        if (self.busy || self.state != kVMStarted) {
            return NO; // already stopping
        } else {
            self.busy = YES;
        }
    }
    [self syncViewState];
    [self changeState:kVMPausing];
    [self saveScreenshot];
    __block BOOL success = YES;
    dispatch_semaphore_t suspend_sema = dispatch_semaphore_create(0);
    [_qemu vmStopWithCompletion:^(NSError * err) {
        UTMLog(@"stop callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            success = NO;
        }
        dispatch_semaphore_signal(suspend_sema);
    }];
    if (dispatch_semaphore_wait(suspend_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Stop operation timeout");
        success = NO;
    }
    if (success) {
        [self changeState:kVMPaused];
    } else {
        [self changeState:kVMError];
    }
    self.busy = NO;
    return success;
}

- (BOOL)saveVM {
    @synchronized (self) {
        if (self.busy || (self.state != kVMPaused && self.state != kVMStarted)) {
            return NO;
        } else {
            self.busy = YES;
        }
    }
    UTMVMState state = self.state;
    [self changeState:kVMPausing];
    __block BOOL success = YES;
    dispatch_semaphore_t save_sema = dispatch_semaphore_create(0);
    [_qemu vmSaveWithCompletion:^(NSString *result, NSError *err) {
        UTMLog(@"save callback: %@", result);
        if (err) {
            UTMLog(@"error: %@", err);
            success = NO;
        } else if ([result localizedCaseInsensitiveContainsString:@"Error"]) {
            UTMLog(@"save result: %@", result);
            success = NO; // error message
        }
        dispatch_semaphore_signal(save_sema);
    } snapshotName:kSuspendSnapshotName];
    if (dispatch_semaphore_wait(save_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Save operation timeout");
        success = NO;
    } else if (success) {
        UTMLog(@"Save completed");
        self.viewState.suspended = YES;
        [self saveViewState];
        [self saveScreenshot];
    }
    [self changeState:state];
    self.busy = NO;
    return success;
}

- (BOOL)deleteSaveVM {
    __block BOOL success = YES;
    if (self.qemu) { // if QEMU is running
        dispatch_semaphore_t save_sema = dispatch_semaphore_create(0);
        [_qemu vmDeleteSaveWithCompletion:^(NSString *result, NSError *err) {
            UTMLog(@"delete save callback: %@", result);
            if (err) {
                UTMLog(@"error: %@", err);
                success = NO;
            } else if ([result localizedCaseInsensitiveContainsString:@"Error"]) {
                UTMLog(@"save result: %@", result);
                success = NO; // error message
            }
            dispatch_semaphore_signal(save_sema);
        } snapshotName:kSuspendSnapshotName];
        if (dispatch_semaphore_wait(save_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
            UTMLog(@"Delete save operation timeout");
            success = NO;
        } else {
            UTMLog(@"Delete save completed");
        }
    } // otherwise we mark as deleted
    self.viewState.suspended = NO;
    [self saveViewState];
    return success;
}

- (BOOL)resumeVM {
    @synchronized (self) {
        if (self.busy || self.state != kVMPaused) {
            return NO;
        } else {
            self.busy = YES;
        }
    }
    [self changeState:kVMResuming];
    __block BOOL success = YES;
    dispatch_semaphore_t resume_sema = dispatch_semaphore_create(0);
    [_qemu vmResumeWithCompletion:^(NSError *err) {
        UTMLog(@"resume callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            success = NO;
        }
        dispatch_semaphore_signal(resume_sema);
    }];
    if (dispatch_semaphore_wait(resume_sema, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Resume operation timeout");
        success = NO;
    }
    if (success) {
        [self changeState:kVMStarted];
        [self restoreViewState];
    } else {
        [self changeState:kVMError];
    }
    if (self.viewState.suspended) {
        [self deleteSaveVM];
    }
    self.busy = NO;
    return success;
}

- (UTMDisplayType)supportedDisplayType {
    if ([self.qemuConfig displayConsoleOnly]) {
        return UTMDisplayTypeConsole;
    } else {
        return UTMDisplayTypeFullGraphic;
    }
}

- (id<UTMInputOutput>)inputOutputServiceWithPort:(NSInteger)port {
    if ([self supportedDisplayType] == UTMDisplayTypeConsole) {
        return [[UTMTerminalIO alloc] initWithConfiguration:[self.qemuConfig copy]];
    } else {
        return [[UTMSpiceIO alloc] initWithConfiguration:[self.qemuConfig copy] port:port];
    }
}

#pragma mark - Qemu manager delegate

- (void)qemuHasWakeup:(UTMQemuManager *)manager {
    UTMLog(@"qemuHasWakeup");
}

- (void)qemuHasResumed:(UTMQemuManager *)manager {
    UTMLog(@"qemuHasResumed");
}

- (void)qemuHasStopped:(UTMQemuManager *)manager {
    UTMLog(@"qemuHasStopped");
}

- (void)qemuHasReset:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason {
    UTMLog(@"qemuHasReset, reason = %s", ShutdownCause_str(reason));
}

- (void)qemuHasSuspended:(UTMQemuManager *)manager {
    UTMLog(@"qemuHasSuspended");
}

- (void)qemuWillQuit:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason {
    UTMLog(@"qemuWillQuit, reason = %s", ShutdownCause_str(reason));
    dispatch_semaphore_signal(_will_quit_sema);
    if (!self.busy) {
        [self quitVM];
    }
}

- (void)qemuError:(UTMQemuManager *)manager error:(NSString *)error {
    UTMLog(@"qemuError: %@", error);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self errorTriggered:error];
    });
}

// this is called right before we execute qmp_cont so we can setup additional option
- (void)qemuQmpDidConnect:(UTMQemuManager *)manager {
    UTMLog(@"qemuQmpDidConnect");
    __autoreleasing NSError *err = nil;
    NSString *errMsg = nil;
    if (!self.qemuConfig.displayConsoleOnly) {
        if (![self startSharedDirectoryWithError:&err]) {
            errMsg = [NSString stringWithFormat:NSLocalizedString(@"Error trying to start shared directory: %@", @"UTMVirtualMachine"), err.localizedDescription];
            UTMLog(@"%@", errMsg);
        }
    }
    if (!err && ![self restoreRemovableDrivesFromBookmarksWithError:&err]) {
        errMsg = [NSString stringWithFormat:NSLocalizedString(@"Error trying to restore removable drives: %@", @"UTMVirtualMachine"), err.localizedDescription];
        UTMLog(@"%@", errMsg);
    }
    if (errMsg) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self errorTriggered:errMsg];
        });
    }
}

#pragma mark - View State

- (void)syncViewState {
    [self.ioService syncViewState:self.viewState];
    [super syncViewState];
}

- (void)restoreViewState {
    [self.ioService restoreViewState:self.viewState];
    [super restoreViewState];
}

#pragma mark - Screenshot

- (void)saveScreenshot {
    self.screenshot = [self.ioService screenshot];
    [super saveScreenshot];
}

@end
