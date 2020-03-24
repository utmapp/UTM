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

#define kUTMTerminalBufferSize 2048

dispatch_io_t createInputIO(NSURL* url, dispatch_queue_t queue) {
    const char* cPath = [[url path] cStringUsingEncoding: NSUTF8StringEncoding];
    dispatch_io_t io =
        dispatch_io_create_with_path(
            DISPATCH_IO_STREAM,
            cPath,
            O_RDWR | O_NONBLOCK,
            0,
            queue,
            ^(int error) {
            NSLog(@"Input dispatch_io is being closed");
        });
    
    return io;
}

@interface UTMTerminal ()

@property (strong, nonatomic, nonnull) dispatch_queue_t inputQueue;
@property (strong, nonatomic, nonnull) dispatch_queue_t outputQueue;
@property (strong, nonatomic, nonnull) dispatch_io_t inputPipeIO;
@property (strong, nonatomic, nullable) dispatch_source_t outputObservationSource;

@end

@implementation UTMTerminal {
    int32_t _outPipeFd;
    uint8_t _byteBuffer[kUTMTerminalBufferSize];
}

- (id)initWithURL: (NSURL*) url {
    self = [super init];
    if (self) {
        // serial queues for input/output processing
        self->_outputQueue = dispatch_queue_create("com.osy86.UTM.TerminalOutputQueue", NULL);
        self->_inputQueue = dispatch_queue_create("com.osy86.UTM.TerminalInputQueue", NULL);
        
        self->_outPipeFd = -1;
        if (![self configurePipesUsingURL: url]) {
            NSLog(@"Terminal configutation failed!");
            [self cleanup];
            return nil;
        }
        // setup non-blocking io for writing
        self->_inputPipeIO = createInputIO(_inPipeURL, _inputQueue);
        if (self->_inputPipeIO == nil) {
            NSLog(@"Terminal configutation failed!");
            [self cleanup];
            return nil;
        }
    }
    return self;
}

#pragma mark - Configuration

- (BOOL)configurePipesUsingURL: (NSURL*) url {
    if ([self isConfigured]) {
        return YES;
    }
    
    // paths
    NSURL* outPipeURL = [url URLByAppendingPathExtension: @"out"];
    NSURL* inPipeURL = [url URLByAppendingPathExtension: @"in"];
    // create named pipes usign mkfifos
    const char* outPipeCPath = [[outPipeURL path] cStringUsingEncoding: NSUTF8StringEncoding];
    if (access(outPipeCPath, F_OK) != -1 && remove(outPipeCPath) != 0) {
        NSLog(@"Failed to remove existing out pipe");
        return NO;
    }
    if (mkfifo(outPipeCPath, 0666) != 0) {
        NSLog(@"Failed to create output pipe using mkfifo!");
        return NO;
    }
    
    const char* inPipeCPath = [[inPipeURL path] cStringUsingEncoding: NSUTF8StringEncoding];
    if (access(inPipeCPath, F_OK) != -1 && remove(inPipeCPath) != 0) {
        NSLog(@"Failed to remove existing in pipe");
        return NO;
    }
    if (mkfifo(inPipeCPath, 0666) != 0) {
        NSLog(@"Failed to create input pipe using mkfifo!");
        return NO;
    }
    
    self->_outPipeURL = outPipeURL;
    self->_inPipeURL = inPipeURL;
    
    return YES;
}

- (BOOL)isConfigured {
    if (_outPipeURL == nil || _inPipeURL == nil) {
        return NO;
    }
    
    return
        [[NSFileManager defaultManager] fileExistsAtPath: [_outPipeURL path]] &&
        [[NSFileManager defaultManager] fileExistsAtPath: [_inPipeURL path]];
}

#pragma mark - Connection

- (BOOL)connectWithError: (NSError** _Nullable) error {
    if (![self isConfigured]) {
        *error = [UTMTerminal notInitializedError];
        return NO;
    }
    
    const char* pipeCPath = [[_outPipeURL path] cStringUsingEncoding: NSUTF8StringEncoding];
    _outPipeFd = open(pipeCPath, O_RDONLY | O_NONBLOCK);
    if (_outPipeFd == -1) {
        *error = [UTMTerminal namedPipeError];
        return NO;
    }
    
    _outputObservationSource = [self startObservationUsingDescriptor: _outPipeFd queue: _outputQueue];
    return YES;
}

- (void)disconnect {
    if (_outputObservationSource != nil) {
        dispatch_source_cancel(_outputObservationSource);
    }
    
    if (_outPipeFd != -1) {
        close(_outPipeFd);
    }
    
    if (_inputPipeIO != nil) {
        dispatch_io_close(_inputPipeIO, DISPATCH_IO_STOP);
    }
    NSLog(@"Successfuly disconnected!");
}

- (BOOL)isConnected {
    return _outputObservationSource != nil;
}

#pragma mark - Output pipe observation

- (dispatch_source_t)startObservationUsingDescriptor: (int32_t) fd queue: (dispatch_queue_t) queue {
    dispatch_source_t source =
    dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    dispatch_source_set_event_handler(source, ^{
        size_t estimated = dispatch_source_get_data(source);
        NSData* bytesRead = [self evaluateChangesForDescriptor: fd estimatedSize: estimated];
        if (bytesRead != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self delegate] terminal: self didReceiveData: bytesRead];
            });
        }
    });
    dispatch_source_set_cancel_handler(source, ^{
        NSLog(@"Source got cancelled");
    });
    dispatch_resume(source);
    
    return source;
}

- (NSData* _Nullable)evaluateChangesForDescriptor: (int32_t) fd estimatedSize: (size_t) estimated {
    NSData* data;
    size_t step = (estimated > kUTMTerminalBufferSize) ? kUTMTerminalBufferSize : estimated;
    ssize_t bytesRead;
    
    if ((bytesRead = read(fd, self->_byteBuffer, step)) > 0) {
        data = [NSData dataWithBytes: self->_byteBuffer length: bytesRead];
    }
    
    return data;
}

- (void)sendInput:(NSString *)inputStr {
    const char* bytes = [inputStr UTF8String];
    NSUInteger length = [inputStr lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
    dispatch_data_t messageData = dispatch_data_create(bytes, length, _inputQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(_inputPipeIO, 0, messageData, _inputQueue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
        NSLog(@"Input write done: %d with error: %d", done, error);
    });
}

#pragma mark - Cleanup

- (void)dealloc {
    [self disconnect];
    [self cleanup];
}

- (void)cleanup {
    NSFileManager* fm = [NSFileManager defaultManager];
    
    if (_inputPipeIO != nil) {
        dispatch_io_close(_inputPipeIO, DISPATCH_IO_STOP);
    }
    
    if (_inPipeURL != nil) {
        [fm removeItemAtURL: _inPipeURL error: nil];
    }
    
    if (_outPipeURL != nil) {
        [fm removeItemAtURL: _outPipeURL error: nil];
    }
    NSLog(@"Cleanup completed!");
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
