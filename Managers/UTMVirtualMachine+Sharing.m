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

#import <TargetConditionals.h>
#import "UTMVirtualMachine+Sharing.h"
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMLogging.h"
#import "UTMSpiceIO.h"
#import "UTMViewState.h"

extern NSString *const kUTMErrorDomain;

#if TARGET_OS_IPHONE
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = 0;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = 0;
#else
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = NSURLBookmarkCreationWithSecurityScope;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = NSURLBookmarkResolutionWithSecurityScope;
#endif

@interface UTMVirtualMachine ()

@property (nonatomic, readonly, nullable) id<UTMInputOutput> ioService;
@property (nonatomic) UTMViewState *viewState;

- (void)saveViewState;

@end

@implementation UTMVirtualMachine (Sharing)

- (BOOL)hasShareDirectoryEnabled {
    return self.configuration.shareDirectoryEnabled && !self.configuration.displayConsoleOnly;
}

- (BOOL)saveSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSData *bookmark = [url bookmarkDataWithOptions:kBookmarkCreationOptions
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        return NO;
    } else {
        self.viewState.sharedDirectory = bookmark;
        [self saveViewState];
        return YES;
    }
}

- (BOOL)changeSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        // if we haven't started the VM yet, save the URL for when the VM starts
        return [self saveSharedDirectory:url error:error];
    } else if (![self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"VM frontend does not support shared directories.", "UTMVirtualMachine+Sharing")}];
        }
        return NO;
    }
    UTMSpiceIO *spiceIO = (UTMSpiceIO *)self.ioService;
    [spiceIO changeSharedDirectory:url];
    return [self saveSharedDirectory:url error:error];
}

- (void)clearSharedDirectory {
    self.viewState.sharedDirectory = nil;
    [self saveViewState];
}

- (BOOL)startSharedDirectoryWithError:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot start shared directory before SPICE starts.", "UTMVirtualMachine+Sharing")}];
        }
        return NO;
    }
    if (!self.configuration.shareDirectoryEnabled) {
        return YES;
    }
    
    NSData *bookmark = nil;
    if (self.viewState.sharedDirectory) {
        UTMLog(@"found shared directory bookmark");
        bookmark = self.viewState.sharedDirectory;
    } else if (self.configuration.shareDirectoryBookmark) {
        UTMLog(@"found shared directory bookmark (legacy)");
        bookmark = self.configuration.shareDirectoryBookmark;
    }
    if (bookmark) {
        BOOL stale;
        NSURL *shareURL = [NSURL URLByResolvingBookmarkData:bookmark
                                                    options:kBookmarkResolutionOptions
                                              relativeToURL:nil
                                        bookmarkDataIsStale:&stale
                                                      error:error];
        if (shareURL) {
            [self changeSharedDirectory:shareURL error:nil];
        } else {
            return NO;
        }
    }
    return YES;
}

@end
