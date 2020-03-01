//
//  UTMTerminal.m
//  UTM
//
//  Created by Kacper Raczy on 29/02/2020.
//  Copyright © 2020 Kacper Raczy. All rights reserved.
//

#import "UTMTerminal.h"
#include <sys/types.h>
#include <sys/stat.h>

#define kTerminalBufferSize 2048

@implementation UTMTerminal {
    int32_t _namedPipeFd;
    dispatch_source_t _fdObserveSource;
    uint8_t _byteBuffer[kTerminalBufferSize];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self->_queue = dispatch_queue_create("terminal_queue", NULL);
        self->_namedPipeFd = -1;
        if (![self configure]) {
            NSLog(@"Terminal configutation failed!");
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
}

- (BOOL)configure {
    if ([self isConfigured]) {
        return YES;
    }
    
    // create pipe name
    NSString* uuidString = [[NSUUID new] UUIDString];
    NSString* pipeName = [NSString stringWithFormat: @"pipe_%@", uuidString];
    // path in temp dir
    NSURL* tmpDir = [[NSFileManager defaultManager] temporaryDirectory];
    NSURL* pipeURL = [tmpDir URLByAppendingPathComponent: pipeName];
    
    const char* pipeCPath = [[pipeURL path] cStringUsingEncoding: NSUTF8StringEncoding];
    if (mkfifo(pipeCPath, 0666) != 0) {
        NSLog(@"Failed to mkfifo!");
        // TODO Error
        return NO;
    }
    
    self->_pipeURL = pipeURL;
    
    return YES;
}

- (BOOL)isConfigured {
    if (_pipeURL == nil) {
        return NO;
    }
    
    return [[NSFileManager defaultManager] fileExistsAtPath: [_pipeURL path]];
}

- (BOOL)connectWithError: (NSError**) error {
    if (![self isConfigured]) {
        *error = [UTMTerminal notInitializedError];
        return NO;
    }
    
    const char* pipeCPath = [[_pipeURL path] cStringUsingEncoding: NSUTF8StringEncoding];
    _namedPipeFd = open(pipeCPath, O_RDONLY | O_NONBLOCK);
    if (_namedPipeFd == -1) {
        *error = [UTMTerminal namedPipeError];
        return NO;
    }
    
    _fdObserveSource = [self startObservationUsingDescriptor: _namedPipeFd queue: _queue];
    return YES;
}

- (void)disconnect {
    if (_fdObserveSource != nil) {
        dispatch_source_cancel(_fdObserveSource);
    }
}

- (dispatch_source_t)startObservationUsingDescriptor: (int32_t) fd queue: (dispatch_queue_t) queue {
    dispatch_source_t source =
    dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    dispatch_source_set_event_handler(source, ^{
        size_t estimated = dispatch_source_get_data(source);
        NSData* bytesRead = [self evaluateChangesForDescriptor: fd estimatedSize: estimated];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self delegate] terminal: self DidReceiveData: bytesRead];
        });
    });
    dispatch_source_set_cancel_handler(source, ^{
        NSLog(@"Source got cancelled");
    });
    dispatch_resume(source);
    
    return source;
}

- (NSData*)evaluateChangesForDescriptor: (int32_t) fd estimatedSize: (size_t) estimated {
    NSMutableData* data = [NSMutableData data];
    size_t step = (estimated > kTerminalBufferSize) ? kTerminalBufferSize : estimated;
    size_t totalRead = 0;
    size_t bytesRead;
    
    while (totalRead < estimated) {
        if ((bytesRead = read(fd, self->_byteBuffer, step)) > 0) {
            [data appendBytes: self->_byteBuffer length: bytesRead];
            totalRead += bytesRead;
        } else {
            break;
        }
    }
    
    return data;
}

- (void)sendInput:(NSString *)inputStr {
    
}

#pragma mark - Custom errors

+ (NSString*)errorDomain {
    return @"com.raczy.TerminalError";
}

+ (NSError*)namedPipeError {
    NSString* domain = [self errorDomain];
    NSDictionary* userInfo = @{
        NSLocalizedDescriptionKey: @"Unable to create/open named pipe."
    };
    return [NSError errorWithDomain: domain code: 1 userInfo: userInfo];
}

+ (NSError*)notInitializedError {
    NSString* domain = [self errorDomain];
    NSDictionary* userInfo = @{
        NSLocalizedDescriptionKey: @"Terminal not initialized"
    };
    return [NSError errorWithDomain: domain code: 1 userInfo: userInfo];
}

@end
