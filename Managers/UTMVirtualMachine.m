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
#import "UTMVirtualMachine-Private.h"
#import "UTMQemuVirtualMachine.h"
#import "UTMConfigurable.h"
#import "UTMQemuConfiguration+Constants.h"
#import "UTMLogging.h"
#import "UTMScreenshot.h"
#import "UTMViewState.h"
#import "UTM-Swift.h"

NSString *const kUTMErrorDomain = @"com.utmapp.utm";
NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";
NSString *const kUTMBundleViewFilename = @"view.plist";
NSString *const kUTMBundleScreenshotFilename = @"screenshot.png";

@interface UTMVirtualMachine ()

@property (nonatomic) NSArray *anyCancellable;

@end

@implementation UTMVirtualMachine

- (void)setDelegate:(id<UTMVirtualMachineDelegate>)delegate {
    _delegate = delegate;
    _delegate.vmConfiguration = self.config;
    [self restoreViewState];
}

- (void)setState:(UTMVMState)state {
    [self propertyWillChange];
    _state = state;
}

- (void)setScreenshot:(UTMScreenshot *)screenshot {
    [self propertyWillChange];
    _screenshot = screenshot;
}

- (void)setViewState:(UTMViewState *)viewState {
    [self propertyWillChange];
    _viewState = viewState;
    self.anyCancellable = [self subscribeToConfiguration];
}

- (void)setConfig:(id<UTMConfigurable>)config {
    [self propertyWillChange];
    _config = config;
    self.anyCancellable = [self subscribeToConfiguration];
}

- (NSURL *)icon {
    return self.config.iconUrl;
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

+ (nullable UTMVirtualMachine *)virtualMachineWithURL:(NSURL *)url {
#if TARGET_OS_OSX
    if (@available(macOS 11, *)) {
        if ([UTMAppleVirtualMachine isAppleVMForPath:url]) {
            return [[UTMAppleVirtualMachine alloc] initWithURL:url];
        }
    }
#endif
    return [[UTMQemuVirtualMachine alloc] initWithURL:url];
}

+ (UTMVirtualMachine *)virtualMachineWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl {
#if TARGET_OS_OSX
    if (@available(macOS 11, *)) {
        if (configuration.isAppleVirtualization) {
            return [[UTMAppleVirtualMachine alloc] initWithConfiguration:configuration withDestinationURL:dstUrl];
        }
    }
#endif
    return [[UTMQemuVirtualMachine alloc] initWithConfiguration:configuration withDestinationURL:dstUrl];
}

+ (BOOL)isAppleVMForPath:(NSURL *)path {
    return NO;
}

- (instancetype)init {
    self = [super init];
    if (self) {
#if TARGET_OS_IPHONE
        self.logging = [UTMLogging sharedInstance];
#else
        self.logging = [UTMLogging new];
#endif
    }
    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url {
    self = [self init];
    if (self) {
        self.path = url;
        self.parentPath = url.URLByDeletingLastPathComponent;
        [self loadViewState];
        if (![self loadConfigurationWithReload:NO error:nil]) {
            self = nil;
            return self;
        }
        [self loadScreenshot];
        if (self.viewState.suspended) {
            self.state = kVMSuspended;
        } else {
            self.state = kVMStopped;
        }
    }
    return self;
}

- (instancetype)initWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl {
    self = [self init];
    if (self) {
        self.parentPath = dstUrl;
        self.viewState = [[UTMViewState alloc] init];
        self.config = configuration;
        self.config.selectedCustomIconPath = configuration.selectedCustomIconPath;
        self.config = configuration;
    }
    return self;
}

- (void)changeState:(UTMVMState)state {
    @synchronized (self) {
        self.state = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate virtualMachine:self transitionToState:state];
        });
    }
    self.viewState.active = (state == kVMStarted);
}

- (NSURL *)packageURLForName:(NSString *)name {
    return [[self.parentPath URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (void)errorTriggered:(nullable NSString *)msg {
    if (self.state != kVMStopped && self.state != kVMError) {
        self.viewState.suspended = NO;
        [self saveViewState];
        [self quitVMForce:true];
    }
    if (self.state != kVMError) { // don't stack errors
        self.delegate.vmMessage = msg;
        [self changeState:kVMError];
    }
}

- (BOOL)reloadConfigurationWithError:(NSError * _Nullable *)err {
    return [self loadConfigurationWithReload:YES error:err];
}

#define notImplemented @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass.", __PRETTY_FUNCTION__] userInfo:nil]

- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err {
    notImplemented;
}

- (BOOL)saveUTMWithError:(NSError * _Nullable *)err {
    notImplemented;
}

- (BOOL)startVM {
    notImplemented;
}

- (BOOL)quitVM {
    return [self quitVMForce:NO];
}

- (BOOL)quitVMForce:(BOOL)force {
    notImplemented;
}

- (BOOL)resetVM {
    notImplemented;
}

- (BOOL)pauseVM {
    notImplemented;
}

- (BOOL)saveVM {
    return [self saveVMInBackground:NO];
}

- (BOOL)saveVMInBackground:(BOOL)background {
    notImplemented;
}

- (BOOL)deleteSaveVM {
    notImplemented;
}

- (BOOL)resumeVM {
    notImplemented;
}

#pragma mark - Plist Handling

- (NSDictionary *)loadPlist:(NSURL *)path withError:(NSError **)err {
    NSData *data = [NSData dataWithContentsOfURL:path];
    if (!data) {
        if (err) {
            *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to load plist", @"UTMVirtualMachine")}];
        }
        return nil;
    }
    id plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:err];
    if (!plist) {
        return nil;
    }
    if (![plist isKindOfClass:[NSDictionary class]]) {
        if (err) {
            *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Config format incorrect.", @"UTMVirtualMachine")}];
        }
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
    self.viewState.showToolbar = self.delegate.toolbarVisible;
    self.viewState.showKeyboard = self.delegate.keyboardVisible;
}

- (void)restoreViewState {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.delegate.toolbarVisible = self.viewState.showToolbar;
        self.delegate.keyboardVisible = self.viewState.showKeyboard;
    });
}

- (void)loadViewState {
    NSDictionary *plist = [self loadPlist:[self.path URLByAppendingPathComponent:kUTMBundleViewFilename] withError:nil];
    if (plist) {
        self.viewState = [[UTMViewState alloc] initWithDictionary:plist];
    } else {
        self.viewState = [[UTMViewState alloc] init];
    }
}

- (void)saveViewState {
    [self savePlist:[self.path URLByAppendingPathComponent:kUTMBundleViewFilename]
               dict:self.viewState.dictRepresentation
          withError:nil];
}

#pragma mark - Screenshot

- (void)loadScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    self.screenshot = [[UTMScreenshot alloc] initWithContentsOfURL:url];
}

- (void)saveScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    if (self.screenshot) {
        [self.screenshot writeToURL:url atomically:NO];
    }
}

- (void)deleteScreenshot {
    NSURL *url = [self.path URLByAppendingPathComponent:kUTMBundleScreenshotFilename];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    self.screenshot = nil;
}

@end
