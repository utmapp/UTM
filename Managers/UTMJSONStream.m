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
#import "UTMLogging.h"

extern NSString *const kUTMErrorDomain;
const int kMaxBufferSize = 1024;

enum ParserState {
    PARSER_NOT_IN_STRING,
    PARSER_IN_STRING,
    PARSER_IN_STRING_ESCAPE,
    PARSER_INVALID
};

@interface UTMJSONStream ()

@property (nonatomic, nullable) NSMutableData *data;
@property (nonatomic, nullable) NSInputStream *inputStream;
@property (nonatomic, nullable) NSOutputStream *outputStream;
@property (nonatomic, nullable) dispatch_queue_t streamQueue;
@property (nonatomic) NSUInteger parsedBytes;
@property (nonatomic) enum ParserState state;
@property (nonatomic) NSInteger openCurlyCount;

@end

@implementation UTMJSONStream

- (instancetype)initHost:(NSString *)host port:(NSInteger)port {
    self = [super init];
    if (self) {
        self.host = host;
        self.port = port;
        self.streamQueue = dispatch_queue_create("com.utmapp.UTM.JSONStream", NULL);
    }
    return self;
}

- (void)dealloc {
    if (self.inputStream || self.outputStream) {
        [self disconnect];
    }
}

- (void)connect {
    @synchronized (self) {
        if (self.inputStream != nil || self.outputStream != nil) {
            assert(self.inputStream != nil && self.outputStream != nil);
            return;
        }
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)self.host, (UInt32)self.port, &readStream, &writeStream);
        self.inputStream = CFBridgingRelease(readStream);
        self.outputStream = CFBridgingRelease(writeStream);
        self.data = [NSMutableData data];
        self.parsedBytes = 0;
        self.openCurlyCount = -1;
        [self.inputStream setDelegate:self];
        CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)self.inputStream, self.streamQueue);
        [self.inputStream open];
        [self.outputStream setDelegate:self];
        CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)self.outputStream, self.streamQueue);
        [self.outputStream open];
    }
}

- (void)disconnect {
    @synchronized (self) {
        if (self.inputStream == nil || self.outputStream == nil) {
            assert(self.inputStream == nil && self.outputStream == nil);
            return;
        }
        CFReadStreamRef readStream = (CFReadStreamRef)CFBridgingRetain(self.inputStream);
        CFWriteStreamRef writeStream = (CFWriteStreamRef)CFBridgingRetain(self.outputStream);
        self.inputStream = nil;
        self.outputStream = nil;
        self.inputStream.delegate = nil;
        self.outputStream.delegate = nil;
        self.data = nil;
        CFReadStreamSetDispatchQueue(readStream, NULL);
        CFWriteStreamSetDispatchQueue(writeStream, NULL);
        CFReadStreamClose(readStream);
        CFWriteStreamClose(writeStream);
        dispatch_async(self.streamQueue, ^{
            CFRelease(readStream);
            CFRelease(writeStream);
        });
    }
}

- (void)parseData {
    __block NSUInteger endIndex = 0;
    [self.data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        const char *str = (const char *)bytes;
        if (byteRange.location + byteRange.length < self.parsedBytes) {
            return;
        }
        for (NSUInteger i = self.parsedBytes - byteRange.location; i < byteRange.length; i++) {
            if (self.state == PARSER_IN_STRING_ESCAPE) {
                self.state = PARSER_IN_STRING;
            } else {
                switch (str[i]) {
                    case '{': {
                        if (self.state == PARSER_NOT_IN_STRING) {
                            if (self.openCurlyCount == -1) {
                                self.openCurlyCount = 0;
                            }
                            self.openCurlyCount++;
                        }
                        break;
                    }
                    case '}': {
                        if (self.state == PARSER_NOT_IN_STRING) {
                            self.openCurlyCount--;
                            if (self.openCurlyCount < 0) {
                                UTMLog(@"Saw too many close curly!");
                                self.state = PARSER_INVALID;
                                NSError *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Error parsing JSON.", "UTMJSONStream")}];
                                [self.delegate jsonStream:self seenError:err];
                            }
                        }
                        break;
                    }
                    case '\\': {
                        if (self.state == PARSER_IN_STRING) {
                            self.state = PARSER_IN_STRING_ESCAPE;
                        } else {
                            UTMLog(@"Saw escape in invalid context");
                            self.state = PARSER_INVALID;
                            NSError *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Error parsing JSON.", "UTMJSONStream")}];
                            [self.delegate jsonStream:self seenError:err];
                        }
                        break;
                    }
                    case '"': {
                        if (self.state == PARSER_IN_STRING) {
                            self.state = PARSER_NOT_IN_STRING;
                        } else {
                            self.state = PARSER_IN_STRING;
                        }
                        break;
                    }
                    default: {
                        // force reset parser
                        if (str[i] == (char)0xFF ||
                            (str[i] >= '\0' && str[i] < ' ' && str[i] != '\t' && str[i] != '\r' && str[i] != '\n')) {
                            UTMLog(@"Resetting parser...");
                            self.state = PARSER_NOT_IN_STRING;
                            self.openCurlyCount = 0;
                        }
                    }
                }
            }
            self.parsedBytes++;
            if (self.openCurlyCount == 0) {
                endIndex = self.parsedBytes;
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
    NSData *jsonData = [self.data subdataWithRange:NSMakeRange(0, length)];
    self.data = [NSMutableData dataWithData:[self.data subdataWithRange:NSMakeRange(length, self.data.length - length)]];
    self.parsedBytes = 0;
    self.openCurlyCount = -1;
    NSError *err;
    id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&err];
    if (err) {
        [self.delegate jsonStream:self seenError:err];
        return;
    }
    NSAssert([json isKindOfClass:[NSDictionary class]], @"JSON data not dictionary");
    UTMLog(@"Debug JSON recieved <- %@", json);
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
                NSStream *inputStream = self.inputStream;
                if (!inputStream) {
                    return; // stream is closing
                }
                NSAssert(aStream == inputStream, @"Invalid stream");
                res = [self.inputStream read:buf maxLength:kMaxBufferSize];
                if (res > 0) {
                    [self.data appendBytes:buf length:res];
                    while (self.parsedBytes < [self.data length]) {
                        [self parseData];
                    }
                } else if (res < 0) {
                    [self.delegate jsonStream:self seenError:[self.inputStream streamError]];
                }
            }
            break;
        }
        case NSStreamEventErrorOccurred: {
            UTMLog(@"Stream error %@", [aStream streamError]);
            [self.delegate jsonStream:self seenError:[aStream streamError]];
        }
        case NSStreamEventEndEncountered: {
            [self disconnect];
            break;
        }
        case NSStreamEventOpenCompleted: {
            UTMLog(@"Connected to stream %p", aStream);
            [self.delegate jsonStream:self connected:(aStream == self.inputStream)];
            break;
        }
        default: {
            break;
        }
    }
}

- (BOOL)sendDictionary:(NSDictionary *)dict {
    @synchronized (self) {
        if (!self.outputStream || (self.outputStream.streamStatus != NSStreamStatusOpen && self.outputStream.streamStatus != NSStreamStatusWriting)) {
            return NO;
        }
        UTMLog(@"Debug JSON send -> %@", dict);
        NSError *err;
        [NSJSONSerialization writeJSONObject:dict toStream:self.outputStream options:0 error:&err];
        if (err) {
            UTMLog(@"Error sending dict: %@", err);
            return NO;
        }
    }
    return YES;
}

@end
