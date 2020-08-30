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

#import "UTMVirtualMachine+Sharing.h"
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMLogging.h"
#import "UTMSpiceIO.h"

extern NSString *const kUTMErrorDomain;

@interface UTMVirtualMachine ()

@property (nonatomic, readonly, nullable) id<UTMInputOutput> ioService;

@end

@implementation UTMVirtualMachine (Sharing)

- (BOOL)hasShareDirectoryEnabled {
    return self.configuration.shareDirectoryEnabled && !self.configuration.displayConsoleOnly;
}

- (BOOL)changeSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    if (![self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"VM frontend does not support shared directories.", "UTMVirtualMachine+Sharing")}];
        }
        return NO;
    }
    UTMSpiceIO *spiceIO = (UTMSpiceIO *)self.ioService;
    [spiceIO changeSharedDirectory:url];
    return YES;
}

- (void)legacyEnableSharedDirectory {
    if (self.configuration.shareDirectoryEnabled) {
        BOOL stale;
        NSError *err;
        NSURL *shareURL = [NSURL URLByResolvingBookmarkData:self.configuration.shareDirectoryBookmark
                                                    options:0
                                              relativeToURL:nil
                                        bookmarkDataIsStale:&stale
                                                      error:&err];
        if (shareURL) {
            UTMLog(@"enabling shared directory from legacy settings");
            [self changeSharedDirectory:shareURL error:nil];
        }
    }
}

@end
