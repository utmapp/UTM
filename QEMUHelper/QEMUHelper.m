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
#import "Bootstrap.h"

@interface QEMUHelper ()

@property NSMutableArray<NSURL *> *urls;
@property dispatch_queue_t childWaitQueue;

@end

@implementation QEMUHelper

- (instancetype)init {
    if (self = [super init]) {
        self.urls = [NSMutableArray array];
        self.childWaitQueue = dispatch_queue_create("childWaitQueue", DISPATCH_QUEUE_CONCURRENT);
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

- (void)startQemu:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryBookmark:(NSData *)libBookmark argv:(NSArray<NSString *> *)argv onExit:(void(^)(BOOL,NSString *))onExit {
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
    
    if (@available(macOS 11.3, *)) { // macOS 11.3 fixed sandbox bug for hypervisor to work
        [self startQemuTask:binName standardOutput:standardOutput standardError:standardError libraryPath:libraryPath argv:argv onExit:onExit];
    } else { // old deprecated fork() method
        [self startQemuFork:binName standardOutput:standardOutput standardError:standardError libraryPath:libraryPath argv:argv onExit:onExit];
    }
}

- (void)startQemuTask:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryPath:(NSURL *)libraryPath argv:(NSArray<NSString *> *)argv onExit:(void(^)(BOOL,NSString *))onExit {
    NSError *err;
    NSTask *task = [NSTask new];
    NSMutableArray<NSString *> *newArgv = [argv mutableCopy];
    NSString *path = [libraryPath URLByAppendingPathComponent:binName].path;
    [newArgv insertObject:path atIndex:0];
    task.executableURL = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"QEMULauncher"];
    task.arguments = newArgv;
    task.standardOutput = standardOutput;
    task.standardError = standardError;
    //task.environment = @{@"DYLD_LIBRARY_PATH": libraryPath.path};
    task.qualityOfService = NSQualityOfServiceUserInitiated;
    task.terminationHandler = ^(NSTask *task) {
        BOOL normalExit = task.terminationReason == NSTaskTerminationReasonExit && task.terminationStatus == 0;
        onExit(normalExit, nil);
    };
    if (![task launchAndReturnError:&err]) {
        NSLog(@"Error starting QEMU: %@", err);
        onExit(NO, NSLocalizedString(@"Error starting QEMU.", @"QEMUHelper"));
    }
}


- (void)startQemuFork:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryPath:(NSURL *)libraryPath argv:(NSArray<NSString *> *)argv onExit:(void(^)(BOOL,NSString *))onExit {
    // convert all the Objective-C strings to C strings as we should not use objects in this context after fork()
    NSString *path = [libraryPath URLByAppendingPathComponent:binName].path;
    char *cpath = strdup(path.UTF8String);
    int argc = (int)argv.count + 1;
    char **cargv = calloc(argc, sizeof(char *));
    cargv[0] = cpath;
    for (int i = 0; i < argc-1; i++) {
        cargv[i+1] = strdup(argv[i].UTF8String);
    }
    int newStdOut = standardOutput.fileDescriptor;
    int newStdErr = standardError.fileDescriptor;
    pid_t pid = startQemuFork(cpath, argc, (const char **)cargv, newStdOut, newStdErr);
    // free all resources regardless of error because on success, child has a copy
    [standardOutput closeFile];
    [standardError closeFile];
    for (int i = 0; i < argc; i++) {
        free(cargv[i]);
    }
    free(cargv);
    if (pid < 0) {
        NSLog(@"Error starting QEMU: %d", pid);
        onExit(NO, NSLocalizedString(@"Error starting QEMU.", @"QEMUHelper"));
    } else {
        // a new thread to reap the child and wait on its status
        dispatch_async(self.childWaitQueue, ^{
            do {
                int status;
                if (waitpid(pid, &status, 0) < 0) {
                    NSLog(@"waitpid(%d) returned error: %d", pid, errno);
                    onExit(NO, NSLocalizedString(@"QEMU exited unexpectedly.", @"QEMUHelper"));
                } else if (WIFEXITED(status)) {
                    NSLog(@"child process %d terminated", pid);
                    onExit(WEXITSTATUS(status) == 0, nil);
                } else {
                    continue; // another reason, we ignore
                }
            } while (0);
        });
    }
}

@end
