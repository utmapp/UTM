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
#import "QEMUHelperDelegate.h"
#import <stdio.h>

@interface QEMUHelper ()

@property NSMutableArray<NSURL *> *urls;
@property NSTask *childTask;

@end

@implementation QEMUHelper

@synthesize environment;

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
        // if we fail, try again with read-only access
        if (!bookmark) {
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&err];
        }
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

- (void)stopAccessingPath:(nullable NSString *)path {
    if (!path) {
        return;
    }
    for (NSURL *url in _urls) {
        if ([url.path isEqualToString:path]) {
            [url stopAccessingSecurityScopedResource];
            [_urls removeObject:url];
            return;
        }
    }
    NSLog(@"Cannot find '%@' in existing scoped access.", path);
}

- (void)startQemu:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryBookmark:(NSData *)libBookmark argv:(NSArray<NSString *> *)argv completion:(void(^)(BOOL,NSString *))completion {
    NSError *err;
    NSURL *libraryPath = [NSURL URLByResolvingBookmarkData:libBookmark
                                                   options:0
                                             relativeToURL:nil
                                       bookmarkDataIsStale:nil
                                                     error:&err];
    if (!libraryPath || ![[NSFileManager defaultManager] fileExistsAtPath:libraryPath.path]) {
        NSLog(@"Cannot resolve library path: %@", err);
        completion(NO, NSLocalizedString(@"Cannot find QEMU support libraries.", @"QEMUHelper"));
        return;
    }
    
    [self startQemuTask:binName standardOutput:standardOutput standardError:standardError libraryPath:libraryPath argv:argv completion:completion];
}

- (void)startQemuTask:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryPath:(NSURL *)libraryPath argv:(NSArray<NSString *> *)argv completion:(void(^)(BOOL,NSString *))completion {
    NSError *err;
    NSTask *task = [NSTask new];
    NSMutableArray<NSString *> *newArgv = [argv mutableCopy];
    NSString *path = [libraryPath URLByAppendingPathComponent:binName].path;
    __weak typeof(self) _self = self;
    [newArgv insertObject:path atIndex:0];
    task.executableURL = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"QEMULauncher.app"] URLByAppendingPathComponent:@"Contents/MacOS/QEMULauncher"];
    task.arguments = newArgv;
    task.standardOutput = standardOutput;
    task.standardError = standardError;
    NSMutableDictionary<NSString *, NSString *> *environment = [NSMutableDictionary dictionary];
    environment[@"TMPDIR"] = NSFileManager.defaultManager.temporaryDirectory.path;
    if (self.environment) {
        [environment addEntriesFromDictionary:self.environment];
    }
    task.environment = environment;
    task.qualityOfService = NSQualityOfServiceUserInitiated;
    task.terminationHandler = ^(NSTask *task) {
        _self.childTask = nil;
        [_self.connection.remoteObjectProxy qemuHasExited:task.terminationStatus message:nil];
    };
    if (![task launchAndReturnError:&err]) {
        NSLog(@"Error starting QEMU: %@", err);
        completion(NO, err.localizedDescription);
    } else {
        self.childTask = task;
        completion(YES, nil);
    }
}

- (void)terminate {
    [self.childTask terminate];
    self.childTask = nil;
}

@end
