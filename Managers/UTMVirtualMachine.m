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

#import <TargetConditionals.h>
#import "UTMVirtualMachine.h"
#import "UTMVirtualMachine-Private.h"
#import "UTMQemuVirtualMachine.h"
#import "UTMLogging.h"
#import "UTM-Swift.h"
#if defined(WITH_QEMU_TCI)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

NSString *const kUTMErrorDomain = @"com.utmapp.utm";
NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";
NSString *const kUTMBundleViewFilename = @"view.plist";
NSString *const kUTMBundleScreenshotFilename = @"screenshot.png";

const dispatch_time_t kScreenshotPeriodSeconds = 60 * NSEC_PER_SEC;

@interface UTMVirtualMachine ()

@property (nonatomic, readonly) BOOL isScreenshotSaveEnabled;
@property (nonatomic, nullable) void (^screenshotTimerHandler)(void);
@property (nonatomic) BOOL isScopedAccess;

@end

@implementation UTMVirtualMachine

// MARK: - Observable properties

- (void)setConfig:(UTMConfigurationWrapper *)config {
    [self propertyWillChange];
    _config = config;
    [self subscribeToChildren];
}

- (void)setRegistryEntry:(UTMRegistryEntry *)registryEntry {
    [self propertyWillChange];
    _registryEntry = registryEntry;
    [self subscribeToChildren];
}

- (void)setState:(UTMVMState)state {
    [self propertyWillChange];
    _state = state;
}

- (void)setScreenshot:(CSScreenshot *)screenshot {
    [self propertyWillChange];
    _screenshot = screenshot;
}

- (NSURL *)detailsIconUrl {
    return self.config.iconURL;
}

- (void)setIsShortcut:(BOOL)isShortcut {
    [self propertyWillChange];
    _isShortcut = isShortcut;
}

- (void)setIsDeleted:(BOOL)isDeleted {
    [self propertyWillChange];
    _isDeleted = isDeleted;
}

- (BOOL)isBusy {
    return (_state == kVMPausing || _state == kVMResuming || _state == kVMStarting || _state == kVMStopping);
}

- (void)setIsRunningAsSnapshot:(BOOL)isNextRunAsSnapshot {
    [self propertyWillChange];
    _isRunningAsSnapshot = isNextRunAsSnapshot;
}

- (NSString *)stateLabel {
    switch (_state) {
        case kVMStopped:
            if (self.registryEntry.hasSaveState) {
                return NSLocalizedString(@"Suspended", "UTMVirtualMachine");
            } else {
                return NSLocalizedString(@"Stopped", "UTMVirtualMachine");
            }
        case kVMStarting: return NSLocalizedString(@"Starting", "UTMVirtualMachine");
        case kVMStarted: return NSLocalizedString(@"Started", "UTMVirtualMachine");
        case kVMPausing: return NSLocalizedString(@"Pausing", "UTMVirtualMachine");
        case kVMPaused: return NSLocalizedString(@"Paused", "UTMVirtualMachine");
        case kVMResuming: return NSLocalizedString(@"Resuming", "UTMVirtualMachine");
        case kVMStopping: return NSLocalizedString(@"Stopping", "UTMVirtualMachine");
    }
}

- (BOOL)hasSaveState {
    return self.registryEntry.hasSaveState;
}

// MARK: - Other properties

- (void)setPath:(NSURL *)path {
    if (_path && self.isScopedAccess) {
        [_path stopAccessingSecurityScopedResource];
    }
    _path = path;
    self.isScopedAccess = [path startAccessingSecurityScopedResource];
}

// MARK: - Constructors

+ (BOOL)URLisVirtualMachine:(NSURL *)url {
    return [url.pathExtension isEqualToString:kUTMBundleExtension];
}

+ (NSString *)virtualMachineName:(NSURL *)url {
    return [[[NSFileManager defaultManager] displayNameAtPath:url.path] stringByDeletingPathExtension];
}

+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent {
    NSCharacterSet *illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/:\\?%*|\"<>"];
    name = [[name componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@"-"];
    return [[parent URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

+ (nullable UTMVirtualMachine *)virtualMachineWithURL:(NSURL *)url {
    [url startAccessingSecurityScopedResource];
    UTMConfigurationWrapper *config = [[UTMConfigurationWrapper alloc] initFrom:url];
    [url stopAccessingSecurityScopedResource];
    if (config) {
        UTMVirtualMachine *vm = [UTMVirtualMachine virtualMachineWithConfiguration:config packageURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            [vm updateConfigFromRegistry];
        });
        return vm;
    } else {
        return nil;
    }
}

+ (UTMVirtualMachine *)virtualMachineWithConfiguration:(UTMConfigurationWrapper *)configuration packageURL:(nonnull NSURL *)packageURL {
#if TARGET_OS_OSX
    if (@available(macOS 11, *)) {
        if (configuration.isAppleVirtualization) {
            return [[UTMAppleVirtualMachine alloc] initWithConfiguration:configuration packageURL:packageURL];
        }
    }
#endif
    return [[UTMQemuVirtualMachine alloc] initWithConfiguration:configuration packageURL:packageURL];
}

- (instancetype)initWithConfiguration:(UTMConfigurationWrapper *)configuration packageURL:(NSURL *)packageURL {
    self = [super init];
    if (self) {
        _state = kVMStopped;
#if TARGET_OS_IPHONE
        self.logging = [UTMLogging sharedInstance];
#else
        self.logging = [UTMLogging new];
#endif
        _config = configuration;
        self.path = packageURL;
        _registryEntry = [UTMRegistry.shared entryFor:self];
        // migrate legacy view state
        NSURL *viewStateURL = [packageURL URLByAppendingPathComponent:kUTMBundleViewFilename];
        [self.registryEntry migrateUnsafeWithViewStateURL:viewStateURL];
        [self.registryEntry migrateFromConfig:configuration];
        [self loadScreenshot];
        [self subscribeToChildren];
    }
    return self;
}

- (void)dealloc {
    if (self.isScopedAccess) {
        [self.path stopAccessingSecurityScopedResource];
    }
}

- (void)startScreenshotTimer {
    if (self.screenshotTimerHandler) {
        return; // already started
    }
    // delete existing screenshot if required
    if (!self.isScreenshotSaveEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self deleteScreenshot];
        });
    }
    typeof(self) __weak weakSelf = self;
    self.screenshotTimerHandler = ^{
        typeof(weakSelf) _self = weakSelf;
        if (!_self) {
            return;
        }
        if (_self.state == kVMStarted) {
            [_self updateScreenshot];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kScreenshotPeriodSeconds), dispatch_get_main_queue(), _self.screenshotTimerHandler);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kScreenshotPeriodSeconds), dispatch_get_main_queue(), self.screenshotTimerHandler);
}

- (void)changeState:(UTMVMState)state {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.state = state;
        [self.delegate virtualMachine:self didTransitionToState:state];
        if (state == kVMStopped) {
            [self setIsRunningAsSnapshot:NO];
        }
    });
    if (state == kVMStarted) {
        [self startScreenshotTimer];
    }
}

- (NSError *)errorGeneric {
    return [self errorWithMessage:NSLocalizedString(@"An internal error has occurred.", "UTMVirtualMachine")];
}

- (NSError *)errorWithMessage:(nullable NSString *)message {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)requestVmStart {
    [self vmStartWithCompletion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmStop {
    [self vmStopWithCompletion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmStopForce:(BOOL)force {
    [self vmStopForce:force completion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmReset {
    [self vmResetWithCompletion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmPauseSave:(BOOL)save {
    [self vmPauseSave:save completion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmSaveState {
    [self vmSaveStateWithCompletion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void)requestVmDeleteState {
    [self vmDeleteStateWithCompletion:^(NSError *error) {
        /* we don't care about errors in this context
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
         */
    }];
}

- (void)requestVmResume {
    [self vmResumeWithCompletion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate virtualMachine:self didErrorWithMessage:error.localizedDescription];
            });
        }
    }];
}

#define notImplemented @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass.", __PRETTY_FUNCTION__] userInfo:nil]

- (void)accessShortcutWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmStartWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmStopWithCompletion:(void (^)(NSError * _Nullable))completion {
    return [self vmStopForce:NO completion:completion];
}

- (void)vmStopForce:(BOOL)force completion:(nonnull void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmResetWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmPauseSave:(BOOL)save completion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmSaveStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmDeleteStateWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

- (void)vmResumeWithCompletion:(void (^)(NSError * _Nullable))completion {
    notImplemented;
}

#pragma mark - Screenshot

- (BOOL)isScreenshotSaveEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return ![defaults boolForKey:@"NoSaveScreenshot"] && !self.isRunningAsSnapshot;
}

- (void)loadScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        _screenshot = [[CSScreenshot alloc] initWithContentsOfURL:url];
    }
}

- (void)saveScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    if (self.isScreenshotSaveEnabled && self.screenshot) {
        [self.screenshot writeToURL:url atomically:NO];
    }
}

- (void)deleteScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    self.screenshot = nil;
}

- (void)updateScreenshot {
    return; // handled by subclass
}

@end
