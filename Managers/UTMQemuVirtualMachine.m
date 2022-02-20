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
#import "UTMVirtualMachine-Protected.h"
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
@property (nonatomic) dispatch_queue_t vmOperations;
@property (nonatomic, nullable) dispatch_semaphore_t qemuWillQuitEvent;
@property (nonatomic, nullable) dispatch_semaphore_t qemuDidExitEvent;
@property (nonatomic, nullable) dispatch_semaphore_t qemuDidConnectEvent;

@end

@implementation UTMQemuVirtualMachine

- (UTMQemuConfiguration *)qemuConfig {
    return (UTMQemuConfiguration *)self.config;
}

- (void)setDelegate:(id<UTMVirtualMachineDelegate>)delegate {
    [super setDelegate:delegate];
    [self.ioService restoreViewState:self.viewState];
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
        self.qemuWillQuitEvent = dispatch_semaphore_create(0);
        self.qemuDidExitEvent = dispatch_semaphore_create(0);
        self.qemuDidConnectEvent = dispatch_semaphore_create(0);
        self.vmOperations = dispatch_queue_create("com.utmapp.UTM.VMOperations", DISPATCH_QUEUE_SERIAL);
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
        return [self.qemuConfig reloadConfigurationWithDictionary:plist name:name path:self.path];
    } else {
        self.config = [[UTMQemuConfiguration alloc] initWithDictionary:plist name:name path:self.path];
        return self.config != nil;
    }
}

- (BOOL)saveConfigurationWithError:(NSError * _Nullable __autoreleasing *)err {
    NSURL *url = [self packageURLForName:self.qemuConfig.name];
    if (![self savePlist:[url URLByAppendingPathComponent:kUTMBundleConfigFilename]
                    dict:self.qemuConfig.dictRepresentation
               withError:err]) {
        return NO;
    }
    return YES;
}

- (BOOL)saveIconWithError:(NSError * _Nullable __autoreleasing *)err {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [self packageURLForName:self.qemuConfig.name];
    if (self.qemuConfig.iconCustom && self.qemuConfig.selectedCustomIconPath) {
        if (self.qemuConfig.icon != nil) {
            NSURL *oldIconPath = [url URLByAppendingPathComponent:self.qemuConfig.icon];
            // delete old icon
            if ([fileManager fileExistsAtPath:oldIconPath.path]) {
                [fileManager removeItemAtURL:oldIconPath error:nil]; // Ignore error
            }
        }
        NSString *newIcon = self.qemuConfig.selectedCustomIconPath.lastPathComponent;
        NSURL *newIconPath = [url URLByAppendingPathComponent:newIcon];
        
        // copy new icon
        if (![fileManager copyItemAtURL:self.qemuConfig.selectedCustomIconPath toURL:newIconPath error:err]) {
            return NO;
        }
        // commit icon
        self.qemuConfig.icon = newIcon;
        self.qemuConfig.selectedCustomIconPath = nil;
    }
    return YES;
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
    return YES;
}

- (void)saveUTMWithCompletion:(void (^)(NSError * _Nullable))completion {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [self packageURLForName:self.qemuConfig.name];
    NSError *err;
    if (!self.qemuConfig.existingPath) { // new package
        if (![fileManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&err]) {
            completion(err);
            return;
        }
    } else if (![self.qemuConfig.existingPath.URLByStandardizingPath isEqual:url.URLByStandardizingPath]) { // rename if needed
        if (![fileManager moveItemAtURL:self.qemuConfig.existingPath toURL:url error:&err]) {
            completion(err);
            return;
        }
    } else {
        url = self.qemuConfig.existingPath;
    }
    // save icon
    if (![self saveIconWithError:&err]) {
        completion(err);
        return;
    }
    // save config
    if (![self saveConfigurationWithError:&err]) {
        completion(err);
        return;
    }
    // create disk images directory
    if (![self saveDisksWithError:&err]) {
        completion(err);
        return;
    }
    self.qemuConfig.existingPath = url;
    self.path = url;
    completion(nil);
}

#pragma mark - Shortcut access

- (void)accessShortcutWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    NSAssert(self.path != nil, @"VM must be existing in the filesystem!");
    if (!completion) {
        // default handler
        completion = ^(NSError *error){};
    }
    if (!self.isShortcut) {
        completion(nil); // not needed
        return;
    }
    UTMQemu *service = self.system;
    if (!service) {
        service = [UTMQemu new]; // VM has not started yet, we create a temporary process
    }
    NSData *bookmark = self.viewState.shortcutBookmark;
    NSString *bookmarkPath = self.viewState.shortcutBookmarkPath;
    BOOL existing = bookmark != nil;
    if (!existing) {
        // create temporary bookmark
        NSError *err;
        bookmark = [self.path bookmarkDataWithOptions:0
                       includingResourceValuesForKeys:nil
                                        relativeToURL:nil
                                                error:&err];
        if (!bookmark) {
            completion(err);
            return;
        }
    }
    if (bookmarkPath) {
        [service stopAccessingPath:bookmarkPath]; // in case old path is still accessed
    }
    [service accessDataWithBookmark:bookmark securityScoped:existing completion:^(BOOL success, NSData *newBookmark, NSString *newPath) {
        (void)service; // required to capture service so it is not released by ARC
        if (success) {
            self.viewState.shortcutBookmark = newBookmark;
            self.viewState.shortcutBookmarkPath = newPath;
            completion(nil);
        } else {
            completion([self errorWithMessage:NSLocalizedString(@"Failed to access data from shortcut.", @"UTMQemuVirtualMachine")]);
        }
    }];
}

#pragma mark - VM actions

- (void)_vmStartWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state != kVMStopped) {
        completion([self errorGeneric]);
        return;
    }
    // start logging
    if (self.qemuConfig.debugLogEnabled) {
        [self.logging logToFile:[self.path URLByAppendingPathComponent:[UTMQemuConfiguration debugLogName]]];
    }
    
    if (!self.system) {
        self.system = [[UTMQemuSystem alloc] initWithConfiguration:self.qemuConfig imgPath:self.path];
        self.system.logging = self.logging;
        self.system.qmpPort = [[UTMPortAllocator sharedInstance] allocatePort];
        _qemu = [[UTMQemuManager alloc] initWithPort:self.system.qmpPort];
        _qemu.delegate = self;
    }

    if (!self.system) {
        completion([self errorGeneric]);
        return;
    }
    
    if (self.isShortcut) {
        __block NSError *accessErr = nil;
        dispatch_semaphore_t accessCompleteEvent = dispatch_semaphore_create(0);
        [self accessShortcutWithCompletion:^(NSError *err){
            accessErr = err;
            dispatch_semaphore_signal(accessCompleteEvent);
        }];
        dispatch_semaphore_wait(accessCompleteEvent, DISPATCH_TIME_FOREVER);
        if (accessErr) {
            completion(accessErr);
            return;
        }
    }
    
    if (!_ioService) {
        _ioService = [self inputOutputService];
    }
    
    [self changeState:kVMStarting];
    
    NSError *spiceError;
    if (![_ioService startWithError:&spiceError]) {
        completion(spiceError);
        return;
    }
    if (self.viewState.suspended) {
        self.system.snapshot = kSuspendSnapshotName;
    }
    // start QEMU (this can be in parallel with QMP connect below)
    __weak typeof(self) weakSelf = self;
    [self.system startWithCompletion:^(BOOL success, NSString *msg){
        typeof(self) _self = weakSelf;
        if (!_self) {
            return; // outlived class
        }
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_self.delegate virtualMachine:_self didErrorWithMessage:msg];
            });
        }
        dispatch_semaphore_signal(_self.qemuDidExitEvent);
        [_self vmStopForce:YES completion:^(NSError *error){}];
    }];
    // connect to QMP
    [self.qemu connectWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            UTMLog(@"Failed to connect to QMP: %@", error);
            completion(error);
            return;
        }
        // wait for QMP to connect
        if (dispatch_semaphore_wait(self.qemuDidConnectEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
            UTMLog(@"Timed out waiting for connect event");
            completion([self errorGeneric]);
            return;
        }
        NSError *err;
        NSString *errMsg;
        if (!self.qemuConfig.displayConsoleOnly) {
            if (![self startSharedDirectoryWithError:&err]) {
                errMsg = [NSString stringWithFormat:NSLocalizedString(@"Error trying to start shared directory: %@", @"UTMVirtualMachine"), err.localizedDescription];
                completion([self errorWithMessage:errMsg]);
                return;
            }
        }
        if (![self restoreRemovableDrivesFromBookmarksWithError:&err]) {
            errMsg = [NSString stringWithFormat:NSLocalizedString(@"Error trying to restore removable drives: %@", @"UTMVirtualMachine"), err.localizedDescription];
            completion([self errorWithMessage:errMsg]);
            return;
        }
        // start SPICE client
        [self.ioService connectWithCompletion:^(BOOL success, NSError *error) {
            if (!success) {
                UTMLog(@"Failed to connect to SPICE: %@", error);
                completion(error);
                return;
            }
            // continue VM boot
            if (![self.qemu continueBootWithError:&error]) {
                UTMLog(@"Failed to boot: %@", error);
                completion(error);
                return;
            }
            assert(self.qemu.isConnected);
            assert(self.ioService.isConnected);
            [self changeState:kVMStarted];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.ioService restoreViewState:self.viewState];
            });
            if (self.viewState.suspended) {
                [self _vmDeleteStateWithCompletion:completion];
            } else {
                completion(nil); // everything successful
            }
        }];
    } retries:kQMPMaxConnectionTries];
}

- (void)vmStartWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmStartWithCompletion:^(NSError *err){
            if (err) { // delete suspend state on error
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.viewState.suspended = NO;
                });
                [self saveViewState];
            }
            completion(err);
        }];
    });
}

- (void)_vmStopForce:(BOOL)force completion:(void (^)(NSError * _Nullable))completion {
    if (self.state == kVMStopped) {
        completion(nil);
        return;
    }
    if (!force && self.state != kVMStarted) {
        completion([self errorGeneric]);
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.ioService syncViewState:self.viewState];
    });
    if (!force) {
        [self changeState:kVMStopping];
    }
    // save view settings early to win exit race
    [self saveViewState];
    
    [self.qemu cancelConnectRetry];
    [_qemu qemuQuitWithCompletion:nil];
    if (force || dispatch_semaphore_wait(self.qemuWillQuitEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Stop operation timeout or force quit");
    }
    [_qemu disconnect];
    _qemu.delegate = nil;
    _qemu = nil;
    [_ioService disconnect];
    _ioService = nil;
    
    if (force || dispatch_semaphore_wait(self.qemuDidExitEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Exit operation timeout or force quit");
    }
    [self.system stopQemu];
    if (self.system.qmpPort) {
        [[UTMPortAllocator sharedInstance] freePort:self.system.qmpPort];
        self.system.qmpPort = 0;
    }
    self.system = nil;
    [self changeState:kVMStopped];
    // stop logging
    [self.logging endLog];
}

- (void)vmStopForce:(BOOL)force completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmStopForce:force completion:completion];
    });
}

- (void)_vmResetWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state != kVMStarted && self.state != kVMPaused) {
        completion([self errorGeneric]);
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.ioService syncViewState:self.viewState];
    });
    [self changeState:kVMStopping];
    if (self.viewState.suspended) {
        [self _vmDeleteStateWithCompletion:^(NSError *error) {}];
    }
    [self saveViewState];
    __block NSError *resetError = nil;
    dispatch_semaphore_t resetTriggeredEvent = dispatch_semaphore_create(0);
    [_qemu qemuResetWithCompletion:^(NSError *err) {
        UTMLog(@"reset callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            resetError = err;
        }
        dispatch_semaphore_signal(resetTriggeredEvent);
    }];
    if (dispatch_semaphore_wait(resetTriggeredEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Reset operation timeout");
        resetError = [self errorGeneric];;
    }
    if (!resetError) {
        [self changeState:kVMStarted];
    } else {
        [self changeState:kVMStopped];
    }
    completion(resetError);
}

- (void)vmResetWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmResetWithCompletion:completion];
    });
}

- (void)_vmPauseWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state != kVMStarted) {
        completion([self errorGeneric]);
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.ioService syncViewState:self.viewState];
    });
    [self changeState:kVMPausing];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self updateScreenshot];
    });
    [self saveScreenshot];
    __block NSError *suspendError = nil;
    dispatch_semaphore_t suspendTriggeredEvent = dispatch_semaphore_create(0);
    [_qemu qemuStopWithCompletion:^(NSError * err) {
        UTMLog(@"stop callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            suspendError = err;
        }
        dispatch_semaphore_signal(suspendTriggeredEvent);
    }];
    if (dispatch_semaphore_wait(suspendTriggeredEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Stop operation timeout");
        suspendError = [self errorGeneric];
    }
    if (!suspendError) {
        [self changeState:kVMPaused];
    } else {
        [self changeState:kVMStopped];
    }
    completion(suspendError);
}

- (void)vmPauseWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmPauseWithCompletion:completion];
    });
}

- (void)_vmSaveStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state != kVMPaused && self.state != kVMStarted) {
        completion([self errorGeneric]);
        return;
    }
    __block NSError *saveError = nil;
    dispatch_semaphore_t saveTriggeredEvent = dispatch_semaphore_create(0);
    [_qemu qemuSaveStateWithCompletion:^(NSString *result, NSError *err) {
        UTMLog(@"save callback: %@", result);
        if (err) {
            UTMLog(@"error: %@", err);
            saveError = err;
        } else if ([result localizedCaseInsensitiveContainsString:@"Error"]) {
            UTMLog(@"save result: %@", result);
            saveError = [self errorWithMessage:result]; // error message
        }
        if (saveError) {
            // replace error with detailed message
            NSString *newMsg = [NSString stringWithFormat:NSLocalizedString(@"Failed to save VM snapshot. Usually this means at least one device does not support snapshots. %@", @"UTMQemuVirtualMachine"), saveError.localizedDescription];
            saveError = [self errorWithMessage:newMsg];
        }
        dispatch_semaphore_signal(saveTriggeredEvent);
    } snapshotName:kSuspendSnapshotName];
    if (dispatch_semaphore_wait(saveTriggeredEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Save operation timeout");
        saveError = [self errorGeneric];
    } else if (!saveError) {
        UTMLog(@"Save completed");
        self.viewState.suspended = YES;
        [self saveViewState];
        [self saveScreenshot];
    }
    completion(saveError);
}

- (void)vmSaveStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmSaveStateWithCompletion:completion];
    });
}

- (void)_vmDeleteStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    __block NSError *deleteError = nil;
    if (self.qemu) { // if QEMU is running
        dispatch_semaphore_t deleteTriggeredEvent = dispatch_semaphore_create(0);
        [_qemu qemuDeleteStateWithCompletion:^(NSString *result, NSError *err) {
            UTMLog(@"delete save callback: %@", result);
            if (err) {
                UTMLog(@"error: %@", err);
                deleteError = err;
            } else if ([result localizedCaseInsensitiveContainsString:@"Error"]) {
                UTMLog(@"save result: %@", result);
                deleteError = [self errorWithMessage:result]; // error message
            }
            dispatch_semaphore_signal(deleteTriggeredEvent);
        } snapshotName:kSuspendSnapshotName];
        if (dispatch_semaphore_wait(deleteTriggeredEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
            UTMLog(@"Delete save operation timeout");
            deleteError = [self errorGeneric];
        } else {
            UTMLog(@"Delete save completed");
        }
    } // otherwise we mark as deleted
    self.viewState.suspended = NO;
    [self saveViewState];
    completion(deleteError);
}

- (void)vmDeleteStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmDeleteStateWithCompletion:completion];
    });
}

- (void)_vmResumeWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state != kVMPaused) {
        completion([self errorGeneric]);
        return;
    }
    [self changeState:kVMResuming];
    __block NSError *resumeError = nil;
    dispatch_semaphore_t resumeTriggeredEvent = dispatch_semaphore_create(0);
    [_qemu qemuResumeWithCompletion:^(NSError *err) {
        UTMLog(@"resume callback: err? %@", err);
        if (err) {
            UTMLog(@"error: %@", err);
            resumeError = err;
        }
        dispatch_semaphore_signal(resumeTriggeredEvent);
    }];
    if (dispatch_semaphore_wait(resumeTriggeredEvent, dispatch_time(DISPATCH_TIME_NOW, kStopTimeout)) != 0) {
        UTMLog(@"Resume operation timeout");
        resumeError = [self errorGeneric];
    }
    if (!resumeError) {
        [self changeState:kVMStarted];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.ioService restoreViewState:self.viewState];
        });
    } else {
        [self changeState:kVMStopped];
    }
    if (self.viewState.suspended) {
        [self _vmDeleteStateWithCompletion:^(NSError *error){}];
    } else {
        completion(nil);
    }
}

- (void)vmResumeWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(self.vmOperations, ^{
        [self _vmResumeWithCompletion:completion];
    });
}

- (UTMDisplayType)supportedDisplayType {
    if ([self.qemuConfig displayConsoleOnly]) {
        return UTMDisplayTypeConsole;
    } else {
        return UTMDisplayTypeFullGraphic;
    }
}

- (id<UTMInputOutput>)inputOutputService {
    if ([self supportedDisplayType] == UTMDisplayTypeConsole) {
        return [[UTMTerminalIO alloc] initWithConfiguration:[self.qemuConfig copy]];
    } else {
        return [[UTMSpiceIO alloc] initWithConfiguration:[self.qemuConfig copy]];
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
    dispatch_semaphore_signal(self.qemuWillQuitEvent);
    [self vmStopWithCompletion:^(NSError *error) {}]; // trigger quit
}

- (void)qemuError:(UTMQemuManager *)manager error:(NSString *)error {
    UTMLog(@"qemuError: %@", error);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate virtualMachine:self didErrorWithMessage:error];
    });
    [self vmStopForce:YES completion:^(NSError *error) {}];
}

// this is called right before we execute qmp_cont so we can setup additional option
- (void)qemuQmpDidConnect:(UTMQemuManager *)manager {
    UTMLog(@"qemuQmpDidConnect");
    dispatch_semaphore_signal(self.qemuDidConnectEvent);
}

#pragma mark - Screenshot

- (void)updateScreenshot {
    self.screenshot = [self.ioService screenshot];
}

@end
