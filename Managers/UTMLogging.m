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

#import <pthread.h>
#import <stdio.h>
#import <TargetConditionals.h>
#import <unistd.h>
#import "UTMLogging.h"

static UTMLogging *gLoggingInstance;

void UTMLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:[format stringByAppendingString:@"\n"] arguments:args];
    [[UTMLogging sharedInstance] writeLine:line];
    va_end(args);
    NSLog(@"%@", line);
}

@interface UTMLogging ()

@property (nonatomic, readwrite) NSPipe *standardOutput;
@property (nonatomic, readwrite) NSPipe *standardError;
@property (nonatomic, nullable) NSOutputStream *fileOutputStream;
@property (nonatomic, nullable) NSFileHandle *originalStdoutWrite;
@property (nonatomic, nullable) NSFileHandle *originalStderrWrite;

@end

@implementation UTMLogging

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        gLoggingInstance = [[UTMLogging alloc] init];
#if TARGET_OS_IPHONE // not supported on macOS
        [gLoggingInstance redirectStandardFds];
#endif
    }
}

+ (UTMLogging *)sharedInstance {
    return gLoggingInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        __weak typeof(self) _weakSelf = self;
        self.standardOutput = [NSPipe pipe];
        self.standardOutput.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
            typeof(self) _self = _weakSelf;
            NSData *data = [handle availableData];
            [_self.originalStdoutWrite writeData:data];
            [_self.fileOutputStream write:data.bytes maxLength:data.length];
        };
        self.standardError = [NSPipe pipe];
        __block NSString *errorBuffer = [NSString string];
        self.standardError.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
            typeof(self) _self = _weakSelf;
            NSData *data = [handle availableData];
            [_self.originalStderrWrite writeData:data];
            [_self.fileOutputStream write:data.bytes maxLength:data.length];
            _self.lastErrorLine = [_self parseLastLine:data buffer:&errorBuffer];
        };
    }
    return self;
}

- (BOOL)redirectStandardFds {
    int real_stdout = -1;
    int real_stderr = -1;
    if ((real_stdout = dup(STDOUT_FILENO)) < 0) {
        perror("dup");
        goto error;
    }
    if ((real_stderr = dup(STDERR_FILENO)) < 0) {
        perror("dup");
        goto error;
    }
    if (dup2(self.standardOutput.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) < 0) {
        perror("dup2");
        goto error;
    }
    if (dup2(self.standardError.fileHandleForWriting.fileDescriptor, STDERR_FILENO) < 0) {
        perror("dup2");
        goto error;
    }
    [self.standardOutput.fileHandleForWriting closeFile];
    [self.standardError.fileHandleForWriting closeFile];
    self.originalStdoutWrite = [[NSFileHandle alloc] initWithFileDescriptor:real_stdout closeOnDealloc:YES];
    self.originalStderrWrite = [[NSFileHandle alloc] initWithFileDescriptor:real_stderr closeOnDealloc:YES];
    return YES;
error:
    close(real_stdout);
    close(real_stderr);
    self.originalStdoutWrite = nil;
    self.originalStderrWrite = nil;
    return NO;
}

- (NSString *)parseLastLine:(NSData *)data buffer:(NSString **)buffer {
    NSString *string = [*buffer stringByAppendingString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    *buffer = [lines lastObject];
    if (lines.count > 0) {
        lines = [lines subarrayWithRange:NSMakeRange(0, lines.count - 1)];
    }
    return [lines lastObject];
}

- (void)logToFile:(NSURL *)path {
    [self endLog];
    self.fileOutputStream = [NSOutputStream outputStreamWithURL:path append:NO];
    [self.fileOutputStream open];
    __weak typeof(self) weakSelf = self;
    atexit_b(^{
        typeof(self) _self = weakSelf;
        if (_self) {
            NSStreamStatus status = _self.fileOutputStream.streamStatus;
            if (status == NSStreamStatusOpen || status == NSStreamStatusWriting) {
                [_self.fileOutputStream close];
            }
        }
    });
}

- (void)endLog {
    [self.fileOutputStream close];
    self.fileOutputStream = nil;
}

- (void)writeLine:(NSString *)line {
    [self.fileOutputStream write:(void *)[line cStringUsingEncoding:NSASCIIStringEncoding] maxLength:line.length];
}

@end
