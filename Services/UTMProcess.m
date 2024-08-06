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

#import "UTMProcess.h"
#import "UTMLogging.h"
#import "QEMUHelperDelegate.h"
#import "QEMUHelperProtocol.h"
#import <dlfcn.h>
#import <pthread.h>
#import <TargetConditionals.h>

extern NSString *const kUTMErrorDomain;

@interface UTMProcess ()

@property (nonatomic) dispatch_queue_t completionQueue;
@property (nonatomic) dispatch_semaphore_t done;
@property (nonatomic, nullable) NSString *processName;

@end

@implementation UTMProcess {
    NSMutableArray<NSString *> *_argv;
    NSMutableArray<NSURL *> *_urls;
#if TARGET_OS_OSX
    NSXPCConnection *_connection;
#endif
}

static void *startProcess(void *args) {
    UTMProcess *self = (__bridge_transfer UTMProcess *)args;
    NSArray<NSString *> *processArgv = self.argv;
    NSMutableArray<NSString *> *environment = [NSMutableArray arrayWithCapacity:self.environment.count];
    
    /* set up environment variables */
    [self.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *combined = [NSString stringWithFormat:@"%@=%@", key, value];
        [environment addObject:combined];
        setenv(key.UTF8String, value.UTF8String, 1);
    }];
    NSUInteger envc = environment.count;
    const char *envp[envc + 1];
    for (NSUInteger i = 0; i < envc; i++) {
        envp[i] = environment[i].UTF8String;
    }
    envp[envc] = NULL;
    setenv("TMPDIR", NSFileManager.defaultManager.temporaryDirectory.path.UTF8String, 1);
    
    const char *currentDirectoryPath = self.currentDirectoryUrl.path.UTF8String;
    if (currentDirectoryPath) {
        chdir(currentDirectoryPath);
    }
    
    int argc = (int)processArgv.count + 1;
    const char *argv[argc];
    argv[0] = [self.processName cStringUsingEncoding:NSUTF8StringEncoding];
    if (!argv[0]) {
        argv[0] = "process";
    }
    for (int i = 0; i < processArgv.count; i++) {
        argv[i+1] = [processArgv[i] UTF8String];
    }
    self.status = self.entry(self, argc, argv, envp);
    dispatch_semaphore_signal(self.done);
    return NULL;
}

static int defaultEntry(UTMProcess *self, int argc, const char *argv[], const char *envp[]) {
    return -1;
}

#pragma mark - Properties

@synthesize argv = _argv;

- (NSURL *)libraryURL {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *contentsURL = [bundleURL URLByAppendingPathComponent:@"Contents" isDirectory:YES];
    NSURL *frameworksURL = [contentsURL URLByAppendingPathComponent:@"Frameworks" isDirectory:YES];
    return frameworksURL;
}

- (BOOL)hasRemoteProcess {
#if TARGET_OS_OSX
    return _connection != nil;
#else
    return NO;
#endif
}

- (NSString *)arguments {
    NSString *args = @"";
    for (NSString *arg in _argv) {
        if ([arg containsString:@" "]) {
            args = [args stringByAppendingFormat:@" \"%@\"", arg];
        } else {
            args = [args stringByAppendingFormat:@" %@", arg];
        }
    }
    return args;
}

#pragma mark - Construction

- (instancetype)init {
    return [self initWithArguments:[NSArray<NSString *> array]];
}

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments {
    if (self = [super init]) {
        _argv = [arguments mutableCopy];
        _urls = [NSMutableArray<NSURL *> array];
        if (![self setupXpc]) {
            return nil;
        }
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, QOS_MIN_RELATIVE_PRIORITY);
        self.completionQueue = dispatch_queue_create("QEMU Completion Queue", attr);
        self.entry = defaultEntry;
        self.done = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)dealloc {
    [self stopProcess];
}

#pragma mark - Methods

- (BOOL)setupXpc {
#if TARGET_OS_IPHONE
    return YES;
#else // only supported on macOS
    NSString *helperIdentifier = NSBundle.mainBundle.infoDictionary[@"HelperIdentifier"];
    if (!helperIdentifier) {
        helperIdentifier = @"com.utmapp.QEMUHelper";
    }
    _connection = [[NSXPCConnection alloc] initWithServiceName:helperIdentifier];
    _connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(QEMUHelperProtocol)];
    _connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(QEMUHelperDelegate)];
    _connection.exportedObject = self;
    [_connection resume];
    return _connection != nil;
#endif
}

- (void)pushArgv:(nullable NSString *)arg {
    NSAssert(arg, @"Cannot push null argument!");
    [_argv addObject:arg];
}

- (void)clearArgv {
    [_argv removeAllObjects];
}

- (BOOL)didLoadDylib:(void *)handle {
    return YES;
}

- (void)startDylibThread:(nonnull NSString *)dylib completion:(nonnull void (^)(NSError * _Nullable))completion {
    void *dlctx;
    __block pthread_t qemu_thread;
    pthread_attr_t qosAttribute;
    __weak typeof(self) wself = self;
    
    NSAssert(self.entry != NULL, @"entry is NULL!");
    self.status = self.fatal = 0;
    UTMLog(@"Loading %@", dylib);
    dlctx = dlopen([dylib UTF8String], RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion([self errorWithMessage:err]);
        return;
    }
    if (![self didLoadDylib:dlctx]) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion([self errorWithMessage:err]);
        return;
    }
    if (atexit_b(^{
        if (pthread_self() == qemu_thread) {
            __strong typeof(self) sself = wself;
            if (sself) {
                sself->_fatal = 1;
                dispatch_semaphore_signal(sself->_done);
            }
            pthread_exit(NULL);
        }
    }) != 0) {
        completion([self errorWithMessage:NSLocalizedString(@"Internal error has occurred.", @"UTMProcess")]);
        return;
    }
    pthread_attr_init(&qosAttribute);
    pthread_attr_set_qos_class_np(&qosAttribute, QOS_CLASS_USER_INTERACTIVE, 0);
    pthread_create(&qemu_thread, &qosAttribute, startProcess, (__bridge_retained void *)self);
    dispatch_async(self.completionQueue, ^{
        if (dispatch_semaphore_wait(self.done, DISPATCH_TIME_FOREVER)) {
            dlclose(dlctx);
            [self processHasExited:-1 message:NSLocalizedString(@"Internal error has occurred.", @"UTMProcess")];
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                [self processHasExited:-1 message:err];
            } else if (self.fatal || self.status) {
                [self processHasExited:-1 message:nil];
            } else {
                [self processHasExited:0 message:nil];
            }
        }
    });
    completion(nil);
}

#if TARGET_OS_OSX
- (void)startQemuRemote:(nonnull NSString *)name completion:(nonnull void (^)(NSError * _Nullable))completion {
    NSError *error;
    NSData *libBookmark = [self.libraryURL bookmarkDataWithOptions:0
                                    includingResourceValuesForKeys:nil
                                                     relativeToURL:nil
                                                             error:&error];
    if (!libBookmark) {
        completion(error);
        return;
    }
    __weak typeof(self) _self = self;
    NSFileHandle *standardOutput = self.standardOutput.fileHandleForWriting;
    NSFileHandle *standardError = self.standardError.fileHandleForWriting;
    [_connection.remoteObjectProxy setEnvironment:self.environment];
    [_connection.remoteObjectProxy setCurrentDirectoryPath:self.currentDirectoryUrl.path];
    // this is needed to prevent XNU from terminating an idle XPC helper
    [_connection.remoteObjectProxy assertActiveWithToken:^(BOOL ignored) {
        // do nothing
    }];
    [[_connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        if (error.domain == NSCocoaErrorDomain && error.code == NSXPCConnectionInvalid) {
            // inhibit this error since we always see it on quit
            [_self processHasExited:0 message:nil];
        } else {
            [_self processHasExited:error.code message:error.localizedDescription];
        }
    }] startQemu:name standardOutput:standardOutput standardError:standardError libraryBookmark:libBookmark argv:self.argv completion:^(BOOL success, NSString *msg){
        if (!success) {
            completion([self errorWithMessage:msg]);
        } else {
            completion(nil);
        }
    }];
}
#endif

- (void)startProcess:(nonnull NSString *)name completion:(nonnull void (^)(NSError * _Nullable))completion {
#if TARGET_OS_IPHONE
    NSString *base = @"";
#else
    NSString *base = @"Versions/A/";
#endif
    NSString *dylib = [NSString stringWithFormat:@"%@.framework/%@%@", name, base, name];
    self.processName = name;
#if TARGET_OS_OSX
    if (_connection) {
        [self startQemuRemote:dylib completion:completion];
    } else {
#endif
        [self startDylibThread:dylib completion:completion];
#if TARGET_OS_OSX
    }
#endif
}

- (void)stopProcess {
#if TARGET_OS_OSX
    if (_connection) {
        [[_connection remoteObjectProxy] terminate];
        [_connection invalidate];
    }
#endif
    for (NSURL *url in _urls) {
        [url stopAccessingSecurityScopedResource];
    }
}

- (void)accessDataWithBookmarkThread:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion  {
    BOOL stale = NO;
    NSError *err;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                           options:0
                                     relativeToURL:nil
                               bookmarkDataIsStale:&stale
                                             error:&err];
    if (!url) {
        UTMLog(@"Failed to access bookmark data.");
        completion(NO, nil, nil);
        return;
    }
    if (stale || !securityScoped) {
        bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                 includingResourceValuesForKeys:nil
                                  relativeToURL:nil
                                          error:&err];
        if (!bookmark) {
            UTMLog(@"Failed to create new bookmark!");
            completion(NO, bookmark, url.path);
            return;
        }
    }
    if ([url startAccessingSecurityScopedResource]) {
        [_urls addObject:url];
    } else {
        UTMLog(@"Failed to access security scoped resource for: %@", url);
    }
    completion(YES, bookmark, url.path);
}

- (void)accessDataWithBookmark:(NSData *)bookmark {
    [self accessDataWithBookmark:bookmark securityScoped:NO completion:^(BOOL success, NSData *bookmark, NSString *path) {
        if (!success) {
            UTMLog(@"Access bookmark failed for: %@", path);
        }
    }];
}

- (void)accessDataWithBookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion {
#if TARGET_OS_OSX
    if (_connection) {
        [[_connection remoteObjectProxy] accessDataWithBookmark:bookmark securityScoped:securityScoped completion:completion];
    } else {
#endif
        [self accessDataWithBookmarkThread:bookmark securityScoped:securityScoped completion:completion];
#if TARGET_OS_OSX
    }
#endif
}

- (void)stopAccessingPathThread:(nullable NSString *)path {
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
    UTMLog(@"Cannot find '%@' in existing scoped access.", path);
}

- (void)stopAccessingPath:(nullable NSString *)path {
#if TARGET_OS_OSX
    if (_connection) {
        [[_connection remoteObjectProxy] stopAccessingPath:path];
    } else {
#endif
        [self stopAccessingPathThread:path];
#if TARGET_OS_OSX
    }
#endif
}

- (NSError *)errorWithMessage:(nullable NSString *)message {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)processHasExited:(NSInteger)exitCode message:(nullable NSString *)message {
    UTMLog(@"QEMU has exited with code %ld and message %@", exitCode, message);
}

@end
