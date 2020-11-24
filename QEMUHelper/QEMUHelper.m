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

#import "QEMUHelper.h"
#import <stdio.h>

@interface QEMUHelper ()

@property NSMutableArray<NSURL *> *urls;

@end

@implementation QEMUHelper

- (instancetype)init {
    if (self = [super init]) {
        self.urls = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    for (NSURL *url in self.urls) {
        [url stopAccessingSecurityScopedResource];
    }
}

- (void)accessDataWithBookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion  {
    BOOL stale = NO;
    NSError *err;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                           options:(securityScoped ? NSURLBookmarkResolutionWithSecurityScope : 0)
                                     relativeToURL:nil
                               bookmarkDataIsStale:&stale
                                             error:&err];
    if (!url) {
        NSLog(@"Failed to access bookmark data.");
        completion(NO, nil, nil);
        return;
    }
    if (stale || !securityScoped) {
        bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                 includingResourceValuesForKeys:nil
                                  relativeToURL:nil
                                          error:&err];
        if (!bookmark) {
            NSLog(@"Failed to create new bookmark!");
            completion(NO, bookmark, url.path);
            return;
        }
    }
    if ([url startAccessingSecurityScopedResource]) {
        [self.urls addObject:url];
    } else {
        NSLog(@"Failed to access security scoped resource for: %@", url);
    }
    completion(YES, bookmark, url.path);
}

- (void)startQemu:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryBookmark:(NSData *)libBookmark argv:(NSArray<NSString *> *)argv onExit:(void(^)(BOOL,NSString *))onExit {
    NSURL *qemuURL = [[NSBundle mainBundle] URLForAuxiliaryExecutable:binName];
    if (!qemuURL || ![[NSFileManager defaultManager] fileExistsAtPath:qemuURL.path]) {
        NSLog(@"Cannot find executable for %@", binName);
        onExit(NO, NSLocalizedString(@"Cannot find QEMU executable.", @"QEMUHelper"));
        return;
    }
    
    NSError *err;
    NSURL *libraryPath = [NSURL URLByResolvingBookmarkData:libBookmark
                                                   options:0
                                             relativeToURL:nil
                                       bookmarkDataIsStale:nil
                                                     error:&err];
    if (!libraryPath || ![[NSFileManager defaultManager] fileExistsAtPath:libraryPath.path]) {
        NSLog(@"Cannot resolve library path: %@", err);
        onExit(NO, NSLocalizedString(@"Cannot find QEMU support libraries.", @"QEMUHelper"));
        return;
    }
    
    NSTask *task = [NSTask new];
    task.executableURL = qemuURL;
    task.arguments = argv;
    task.standardOutput = standardOutput;
    task.standardError = standardError;
    //task.environment = @{@"DYLD_LIBRARY_PATH": libraryPath.path};
    task.qualityOfService = NSQualityOfServiceUserInitiated;
    task.terminationHandler = ^(NSTask *task) {
        BOOL normalExit = task.terminationReason == NSTaskTerminationReasonExit && task.terminationStatus == 0;
        onExit(normalExit, nil); // TODO: get last error line
    };
    if (![task launchAndReturnError:&err]) {
        NSLog(@"Error starting QEMU: %@", err);
        onExit(NO, NSLocalizedString(@"Error starting QEMU.", @"QEMUHelper"));
    }
}

@end
