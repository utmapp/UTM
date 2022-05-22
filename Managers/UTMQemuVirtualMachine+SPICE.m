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

#import "UTMQemuVirtualMachine+SPICE.h"
#import "UTMQemuConfiguration+Display.h"
#import "UTMQemuConfiguration+Sharing.h"
#import "UTMLogging.h"
#import "UTMQemuManager.h"
#import "UTMSpiceIO.h"
#import "UTMViewState.h"
#import "UTMJailbreak.h"
#if defined(WITH_QEMU_TCI)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

extern NSString *const kUTMErrorDomain;

extern const NSURLBookmarkCreationOptions kUTMBookmarkCreationOptions;
extern const NSURLBookmarkResolutionOptions kUTMBookmarkResolutionOptions;

@interface UTMQemuVirtualMachine ()

@property (nonatomic, readonly, nullable) UTMQemuManager *qemu;
@property (nonatomic, readonly, nullable) UTMSpiceIO *ioService;
@property (nonatomic) BOOL changeCursorRequestInProgress;

- (void)saveViewState;

@end

@implementation UTMQemuVirtualMachine (SPICE)

- (UTMSpiceIO *)spiceIoWithError:(NSError * _Nullable __autoreleasing *)error {
    if (![self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"VM frontend does not support shared directories.", "UTMVirtualMachine+Sharing")}];
        }
        return nil;
    }
    return (UTMSpiceIO *)self.ioService;
}

#pragma mark - Shared Directory

- (BOOL)hasShareDirectoryEnabled {
    return self.qemuConfig.shareDirectoryEnabled && !self.qemuConfig.displayConsoleOnly;
}

- (BOOL)saveSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    [url startAccessingSecurityScopedResource];
    NSData *bookmark = [url bookmarkDataWithOptions:kUTMBookmarkCreationOptions
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    [url stopAccessingSecurityScopedResource];
    if (!bookmark) {
        return NO;
    } else {
        self.viewState.sharedDirectory = bookmark;
        self.viewState.sharedDirectoryPath = url.path;
        [self saveViewState];
        return YES;
    }
}

- (BOOL)changeSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        // if we haven't started the VM yet, save the URL for when the VM starts
        return [self saveSharedDirectory:url error:error];
    }
    UTMSpiceIO *spiceIO = [self spiceIoWithError:error];
    if (!spiceIO) {
        return NO;
    }
    [spiceIO changeSharedDirectory:url];
    return [self saveSharedDirectory:url error:error];
}

- (void)clearSharedDirectory {
    self.viewState.sharedDirectory = nil;
    self.viewState.sharedDirectoryPath = nil;
    [self saveViewState];
}

- (BOOL)startSharedDirectoryWithError:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot start shared directory before SPICE starts.", "UTMVirtualMachine+Sharing")}];
        }
        return NO;
    }
    if (!self.qemuConfig.shareDirectoryEnabled) {
        return YES;
    }
    UTMSpiceIO *spiceIO = [self spiceIoWithError:error];
    if (!spiceIO) {
        return NO;
    }
    
    NSData *bookmark = nil;
    BOOL legacy = NO;
    if (self.viewState.sharedDirectory) {
        UTMLog(@"found shared directory bookmark");
        bookmark = self.viewState.sharedDirectory;
    } else if (self.qemuConfig.shareDirectoryBookmark) {
        UTMLog(@"found shared directory bookmark (legacy)");
        bookmark = self.qemuConfig.shareDirectoryBookmark;
        legacy = YES;
    }
    if (bookmark) {
        BOOL stale;
        NSURL *shareURL = [NSURL URLByResolvingBookmarkData:bookmark
                                                    options:kUTMBookmarkResolutionOptions
                                              relativeToURL:nil
                                        bookmarkDataIsStale:&stale
                                                      error:error];
        if (shareURL) {
            BOOL success = YES;
            if (stale) {
                UTMLog(@"stale bookmark, attempting to recreate");
                success = [self saveSharedDirectory:shareURL error:error];
            }
            if (success) {
                [spiceIO changeSharedDirectory:shareURL];
            }
            return success;
        } else if (legacy) { // ignore errors for legacy sharing since we don't have a good way of handling it
            UTMLog(@"Ignoring error on legacy shared directory");
            return YES;
        } else {
            // clear the broken bookmark
            [self clearSharedDirectory];
            return NO;
        }
    }
    return YES;
}

#pragma mark - Input device switching

- (void)requestInputTablet:(BOOL)tablet {
    UTMQemuManager *qemu;
    @synchronized (self) {
        qemu = self.qemu;
        if (self.changeCursorRequestInProgress || !qemu) {
            return;
        }
        self.changeCursorRequestInProgress = YES;
    }
    [qemu mouseIndexForAbsolute:tablet withCompletion:^(int64_t index, NSError *err) {
        if (err) {
            UTMLog(@"error finding index: %@", err);
            self.changeCursorRequestInProgress = NO;
        } else {
            UTMLog(@"found index:%lld absolute:%d", index, tablet);
            [self.qemu mouseSelect:index withCompletion:^(NSString *res, NSError *err) {
                if (err) {
                    UTMLog(@"input select returned error: %@", err);
                } else {
                    UTMSpiceIO *spiceIO = [self spiceIoWithError:&err];
                    if (spiceIO) {
                        [spiceIO.primaryInput requestMouseMode:!tablet];
                    } else {
                        UTMLog(@"failed to get SPICE manager: %@", err);
                    }
                }
                self.changeCursorRequestInProgress = NO;
            }];
        }
    }];
}

#pragma mark - USB redirection

- (BOOL)hasUsbRedirection {
    return jb_has_usb_entitlement();
}

@end
