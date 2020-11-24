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
#import <unistd.h>
#import "UTMLogging.h"

static const int kLogBufferSize = 4096;
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

@property (nonatomic, nullable) NSOutputStream *fileOutputStream;

- (void)didRecieveNewLine:(NSString *)line onDescriptor:(int)fd;

@end

@implementation UTMLogging {
    pthread_t _stdout_thread;
    pthread_t _stderr_thread;
    int _real_stdout;
    int _real_stderr;
    int _stdout;
    int _stderr;
}

void *utm_logging_thread_stdout(void *arg) {
    UTMLogging *self = (__bridge_transfer UTMLogging *)arg;
    char ch;
    NSMutableData *data = [NSMutableData dataWithCapacity:kLogBufferSize];
    while (read(self->_stdout, &ch, 1) > 0) {
        [data appendBytes:&ch length:1];
        if (ch == '\n') {
            NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            data = [NSMutableData dataWithCapacity:kLogBufferSize];
            [self didRecieveNewLine:line onDescriptor:self->_stdout];
        }
    }
    return NULL;
}

void *utm_logging_thread_stderr(void *arg) {
    UTMLogging *self = (__bridge_transfer UTMLogging *)arg;
    char ch;
    NSMutableData *data = [NSMutableData dataWithCapacity:kLogBufferSize];
    while (read(self->_stderr, &ch, 1) > 0) {
        [data appendBytes:&ch length:1];
        if (ch == '\n') {
            NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            data = [NSMutableData dataWithCapacity:kLogBufferSize];
            [self didRecieveNewLine:line onDescriptor:self->_stderr];
        }
    }
    return NULL;
}

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        gLoggingInstance = [[UTMLogging alloc] initGlobal];
    }
}

+ (UTMLogging *)sharedInstance {
    return gLoggingInstance;
}

- (instancetype)initGlobal {
    self = [super init];
    if (self) {
        if (gLoggingInstance != nil) {
            UTMLog(@"Trying to init more than one instance of UTMLogging!");
            return nil;
        }
        int success = 0;
        int new_stdout[2];
        int new_stderr[2];
        _stdout = _stderr = -1;
        _real_stdout = _real_stderr = -1;
        new_stdout[0] = new_stdout[1] = -1;
        new_stderr[0] = new_stderr[1] = -1;
        do {
            if ((_real_stdout = dup(STDOUT_FILENO)) < 0) {
                perror("dup");
                break;
            }
            if ((_real_stderr = dup(STDERR_FILENO)) < 0) {
                perror("dup");
                break;
            }
            if (pipe(new_stdout) < 0) {
                perror("pipe");
                break;
            }
            if (pipe(new_stderr) < 0) {
                perror("pipe");
                break;
            }
            if (dup2(new_stdout[1], STDOUT_FILENO) < 0) {
                perror("dup2");
                break;
            }
            if (dup2(new_stderr[1], STDERR_FILENO) < 0) {
                perror("dup2");
                break;
            }
            if (close(new_stdout[1]) < 0) {
                perror("close");
                break;
            }
            new_stdout[1] = -1;
            if (close(new_stderr[1]) < 0) {
                perror("close");
                break;
            }
            new_stderr[1] = -1;
            _stdout = new_stdout[0];
            _stderr = new_stderr[0];
            if (pthread_create(&_stdout_thread, NULL, utm_logging_thread_stdout, (__bridge_retained void *)self) < 0) {
                perror("pthread_create");
                break;
            }
            if (pthread_create(&_stderr_thread, NULL, utm_logging_thread_stderr, (__bridge_retained void *)self) < 0) {
                perror("pthread_create");
                break;
            }
            success = 1;
        } while (0);
        if (!success) {
            close(new_stdout[0]);
            close(new_stdout[1]);
            close(new_stderr[0]);
            close(new_stderr[1]);
            [self cleanup];
            self = nil;
        }
    }
    return self;
}

- (void)cleanup {
    if (_real_stdout != -1) {
        dup2(_real_stdout, STDOUT_FILENO);
        close(_real_stdout);
        _real_stdout = -1;
    }
    if (_real_stderr != -1) {
        dup2(_real_stderr, STDERR_FILENO);
        close(_real_stderr);
        _real_stderr = -1;
    }
    if (_stdout != -1) {
        close(_stdout);
        _stdout = -1;
    }
    if (_stderr != -1) {
        close(_stderr);
        _stderr = -1;
    }
    if (_stdout_thread != NULL) {
        void *res;
        pthread_join(_stdout_thread, &res);
        _stdout_thread = NULL;
    }
    if (_stderr_thread != NULL) {
        void *res;
        pthread_join(_stderr_thread, &res);
        _stderr_thread = NULL;
    }
    [self endLog];
}

- (void)dealloc {
    [self cleanup];
}

- (void)didRecieveNewLine:(NSString *)line onDescriptor:(int)fd {
    if (fd == _stdout) {
        write(_real_stdout, [line cStringUsingEncoding:NSASCIIStringEncoding], line.length);
    } else if (fd == _stderr) {
        self.lastErrorLine = line;
        write(_real_stderr, [line cStringUsingEncoding:NSASCIIStringEncoding], line.length);
    } else {
        NSAssert(0, @"Invalid descriptor %d", fd);
    }
    [self writeLine:line];
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
