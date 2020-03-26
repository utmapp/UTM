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

#import "UTMJSONStream.h"

extern NSString *const kUTMErrorDomain;
const int kMaxBufferSize = 1024;

enum ParserState {
    PARSER_NOT_IN_STRING,
    PARSER_IN_STRING,
    PARSER_IN_STRING_ESCAPE,
    PARSER_INVALID
};

@implementation UTMJSONStream {
    NSMutableData *_data;
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    NSUInteger _parsedBytes;
    enum ParserState _state;
    int _open_curly_count;
}

- (id)initHost:(NSString *)host port:(UInt32)port {
    self = [self init];
    if (self) {
        self.host = host;
        self.port = port;
    }
    return self;
}

- (void)dealloc {
    if (_inputStream || _outputStream) {
        [self disconnect];
    }
}

- (void)connect {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)self.host, self.port, &readStream, &writeStream);
    @synchronized (self) {
        _inputStream = CFBridgingRelease(readStream);
        _outputStream = CFBridgingRelease(writeStream);
        _data = [NSMutableData data];
        _parsedBytes = 0;
        _open_curly_count = -1;
        [_inputStream setDelegate:self];
        [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_inputStream open];
        [_outputStream setDelegate:self];
        [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream open];
    }
}

- (void)disconnect {
    @synchronized (self) {
        [_inputStream close];
        [_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_inputStream setDelegate:nil];
        _inputStream = nil;
        [_outputStream close];
        [_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream setDelegate:nil];
        _outputStream = nil;
        _data = nil;
    }
}

- (void)parseData {
    __block NSUInteger endIndex = 0;
    [_data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        const char *str = (const char *)bytes;
        if (byteRange.location + byteRange.length < self->_parsedBytes) {
            return;
        }
        for (NSUInteger i = self->_parsedBytes - byteRange.location; i < byteRange.length; i++) {
            if (self->_state == PARSER_IN_STRING_ESCAPE) {
                self->_state = PARSER_IN_STRING;
            } else {
                switch (str[i]) {
                    case '{': {
                        if (self->_state == PARSER_NOT_IN_STRING) {
                            if (self->_open_curly_count == -1) {
                                self->_open_curly_count = 0;
                            }
                            self->_open_curly_count++;
                        }
                        break;
                    }
                    case '}': {
                        if (self->_state == PARSER_NOT_IN_STRING) {
                            self->_open_curly_count--;
                            if (self->_open_curly_count < 0) {
                                NSLog(@"Saw too many close curly!");
                                self->_state = PARSER_INVALID;
                                NSError *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Error parsing JSON.", "UTMJSONStream")}];
                                [self.delegate jsonStream:self seenError:err];
                            }
                        }
                        break;
                    }
                    case '\\': {
                        if (self->_state == PARSER_IN_STRING) {
                            self->_state = PARSER_IN_STRING_ESCAPE;
                        } else {
                            NSLog(@"Saw escape in invalid context");
                            self->_state = PARSER_INVALID;
                            NSError *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Error parsing JSON.", "UTMJSONStream")}];
                            [self.delegate jsonStream:self seenError:err];
                        }
                        break;
                    }
                    case '"': {
                        if (self->_state == PARSER_IN_STRING) {
                            self->_state = PARSER_NOT_IN_STRING;
                        } else {
                            self->_state = PARSER_IN_STRING;
                        }
                        break;
                    }
                    default: {
                        // force reset parser
                        if (str[i] == (char)0xFF ||
                            (str[i] >= '\0' && str[i] < ' ' && str[i] != '\t' && str[i] != '\r' && str[i] != '\n')) {
                            NSLog(@"Resetting parser...");
                            self->_state = PARSER_NOT_IN_STRING;
                            self->_open_curly_count = 0;
                        }
                    }
                }
            }
            self->_parsedBytes++;
            if (self->_open_curly_count == 0) {
                endIndex = self->_parsedBytes;
                *stop = YES;
                break;
            }
        }
    }];
    if (endIndex > 0) {
        [self consumeJSONLength:endIndex];
    }
}

- (void)consumeJSONLength:(NSUInteger)length {
    NSData *jsonData = [_data subdataWithRange:NSMakeRange(0, length)];
    _data = [NSMutableData dataWithData:[_data subdataWithRange:NSMakeRange(length, _data.length - length)]];
    _parsedBytes = 0;
    _open_curly_count = -1;
    NSError *err;
    id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&err];
    if (err) {
        [self.delegate jsonStream:self seenError:err];
        return;
    }
    NSAssert([json isKindOfClass:[NSDictionary class]], @"JSON data not dictionary");
    NSLog(@"Debug JSON recieved <- %@", json);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self.delegate jsonStream:self receivedDictionary:(NSDictionary *)json];
    });
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable: {
            uint8_t buf[kMaxBufferSize];
            NSInteger res;
            @synchronized (self) {
                NSAssert(aStream == _inputStream, @"Invalid stream");
                res = [_inputStream read:buf maxLength:kMaxBufferSize];
            }
            if (res > 0) {
                [_data appendBytes:buf length:res];
                while (_parsedBytes < [_data length]) {
                    [self parseData];
                }
            } else if (res < 0) {
                [self.delegate jsonStream:self seenError:[_inputStream streamError]];
            }
            break;
        }
        case NSStreamEventErrorOccurred: {
            NSLog(@"Stream error %@", [aStream streamError]);
            [self.delegate jsonStream:self seenError:[aStream streamError]];
        }
        case NSStreamEventEndEncountered: {
            [self disconnect];
            break;
        }
        case NSStreamEventOpenCompleted: {
            NSLog(@"Connected to stream");
            [self.delegate jsonStream:self connected:(aStream == _inputStream)];
            break;
        }
        default: {
            break;
        }
    }
}

- (BOOL)sendDictionary:(NSDictionary *)dict {
    NSError *err;
    @synchronized (self) {
        if (!_outputStream || _outputStream.streamStatus != NSStreamStatusOpen) {
            return NO;
        }
        NSLog(@"Debug JSON send -> %@", dict);
        [NSJSONSerialization writeJSONObject:dict toStream:_outputStream options:0 error:&err];
    }
    if (err) {
        NSLog(@"Error sending dict: %@", err);
        return NO;
    } else {
        return YES;
    }
}

@end
