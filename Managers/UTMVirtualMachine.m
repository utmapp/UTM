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
#import "UTMConfiguration.h"
#import "UTMConfiguration+Drives.h"
#import "UTMLogging.h"
#import "UTMScreenshot.h"
#import "UTMViewState.h"

NSString *const kUTMErrorDomain = @"com.utmapp.utm";
NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";
NSString *const kUTMBundleViewFilename = @"view.plist";
NSString *const kUTMBundleScreenshotFilename = @"screenshot.png";

@implementation UTMVirtualMachine

- (void)setDelegate:(id<UTMVirtualMachineDelegate>)delegate {
    _delegate = delegate;
    _delegate.vmConfiguration = self.config;
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

+ (nullable UTMVirtualMachine *)virtualMachineWithURL:(NSURL *)url {
    return [[UTMQemuVirtualMachine alloc] initWithURL:url];
}

+ (UTMVirtualMachine *)virtualMachineWithConfiguration:(UTMConfiguration *)configuration withDestinationURL:(NSURL *)dstUrl {
    return [[UTMQemuVirtualMachine alloc] initWithConfiguration:configuration withDestinationURL:dstUrl];
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
        if (![self loadConfigurationWithReload:NO error:nil]) {
            self = nil;
            return self;
        }
        [self loadViewState];
        [self loadScreenshot];
        if (self.viewState.suspended) {
            self.state = kVMSuspended;
        } else {
            self.state = kVMStopped;
        }
    }
    return self;
}

- (instancetype)initWithConfiguration:(UTMConfiguration *)configuration withDestinationURL:(NSURL *)dstUrl {
    self = [self init];
    if (self) {
        self.parentPath = dstUrl;
        self.config = configuration;
        self.viewState = [[UTMViewState alloc] init];
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

- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err {
    return YES;
}

- (BOOL)reloadConfigurationWithError:(NSError * _Nullable __autoreleasing *)err {
    return [self loadConfigurationWithReload:YES error:err];
}

- (BOOL)saveConfigurationWithError:(NSError * _Nullable __autoreleasing *)err {
    return YES;
}

- (BOOL)saveUTMWithError:(NSError * _Nullable *)err {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [self packageURLForName:self.config.name];
    __block NSError *_err;
    if (!self.config.existingPath) { // new package
        if (![fileManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&_err]) {
            goto error;
        }
    } else if (![self.config.existingPath.URLByStandardizingPath isEqual:url.URLByStandardizingPath]) { // rename if needed
        if (![fileManager moveItemAtURL:self.config.existingPath toURL:url error:&_err]) {
            goto error;
        }
    }
    // save icon
    if (self.config.iconCustom && self.config.selectedCustomIconPath) {
        NSURL *oldIconPath = [url URLByAppendingPathComponent:self.config.icon];
        NSString *newIcon = self.config.selectedCustomIconPath.lastPathComponent;
        NSURL *newIconPath = [url URLByAppendingPathComponent:newIcon];
        
        // delete old icon
        if ([fileManager fileExistsAtPath:oldIconPath.path]) {
            [fileManager removeItemAtURL:oldIconPath error:&_err]; // ignore error
        }
        // copy new icon
        if (![fileManager copyItemAtURL:self.config.selectedCustomIconPath toURL:newIconPath error:&_err]) {
            goto error;
        }
        // commit icon
        self.config.icon = newIcon;
        self.config.selectedCustomIconPath = nil;
    }
    // save config
    if (![self saveConfigurationWithError:err]) {
        return NO;
    }
    // create disk images directory
    if (!self.config.existingPath) {
        NSURL *dstPath = [url URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
        NSURL *tmpPath = [fileManager.temporaryDirectory URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
        
        // create images directory
        if ([fileManager fileExistsAtPath:tmpPath.path]) {
            // delete any orphaned images
            NSArray<NSString *> *orphans = self.config.orphanedDrives;
            for (NSInteger i = 0; i < orphans.count; i++) {
                NSURL *orphanPath = [tmpPath URLByAppendingPathComponent:orphans[i]];
                UTMLog(@"Deleting orphaned image '%@'", orphans[i]);
                if (![fileManager removeItemAtURL:orphanPath error:&_err]) {
                    UTMLog(@"Ignoring error deleting orphaned image: %@", _err.localizedDescription);
                    _err = nil;
                }
            }
            // move remaining drives to VM package
            if (![fileManager moveItemAtURL:tmpPath toURL:dstPath error:&_err]) {
                goto error;
            }
        } else if (![fileManager fileExistsAtPath:dstPath.path]) {
            if (![fileManager createDirectoryAtURL:dstPath withIntermediateDirectories:NO attributes:nil error:&_err]) {
                goto error;
            }
        }
    }
    self.config.existingPath = url;
    self.path = url;
    return YES;
error:
    if (err) {
        *err = _err;
    }
    return NO;
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

#define notImplemented @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass.", __PRETTY_FUNCTION__] userInfo:nil]

- (BOOL)startVM {
    notImplemented;
}

- (BOOL)quitVM {
    return [self quitVMForce:false];
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
