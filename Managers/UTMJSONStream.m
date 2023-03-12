//
// Copyright © 2022 osy. All rights reserved.
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
    PARSER_WAITING_FOR_DELIMITER,
    PARSER_INVALID
};

@interface UTMJSONStream ()

@property (nonatomic, readwrite) CSPort *port;
@property (nonatomic, nullable) NSMutableData *data;
@property (nonatomic, nullable) dispatch_queue_t streamQueue;
@property (nonatomic) NSUInteger parsedBytes;
@property (nonatomic) enum ParserState state;
@property (nonatomic) NSInteger openCurlyCount;

@end

@implementation UTMJSONStream

- (void)setDelegate:(id<UTMJSONStreamDelegate>)delegate {
    _delegate = delegate;
    self.port.delegate = self; // consume any cached data
}

- (instancetype)initWithPort:(CSPort *)port {
    self = [super init];
    if (self) {
        self.streamQueue = dispatch_queue_create("com.utmapp.UTM.JSONStream", NULL);
        self.port = port;
        self.data = [NSMutableData data];
    }
    return self;
}

- (void)parseData {
    __block NSUInteger skipLength = 0;
    __block NSUInteger endIndex = 0;
    [self.data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        const char *str = (const char *)bytes;
        if (byteRange.location + byteRange.length < self.parsedBytes) {
            return;
        }
        for (NSUInteger i = self.parsedBytes - byteRange.location; i < byteRange.length; i++) {
            if (self.state == PARSER_WAITING_FOR_DELIMITER) {
                skipLength++;
                if (str[i] == (char)0xFF) {
                    self.state = PARSER_NOT_IN_STRING;
                    self.openCurlyCount = 0;
                }
                self.parsedBytes++;
                continue;
            } else if (self.state == PARSER_IN_STRING_ESCAPE) {
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
    if (skipLength > 0) {
        // discard any data before delimiter
        [self.data replaceBytesInRange:NSMakeRange(0, skipLength) withBytes:NULL length:0];
        self.parsedBytes -= skipLength;
    }
    if (endIndex > 0) {
        [self consumeJSONLength:endIndex-skipLength];
    }
}

- (void)consumeJSONLength:(NSUInteger)length {
    NSRange range = NSMakeRange(0, length);
    NSData *jsonData = [self.data subdataWithRange:range];
    [self.data replaceBytesInRange:range withBytes:NULL length:0];
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
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self.delegate jsonStream:self receivedDictionary:(NSDictionary *)json];
    });
}

- (void)portDidDisconect:(CSPort *)port {
    assert(self.port == port);
    [self.delegate jsonStream:self connected:NO];
}

- (void)port:(CSPort *)port didError:(NSString *)error {
    [self.delegate jsonStream:self seenError:[NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: error}]];
}

- (void)port:(CSPort *)port didRecieveData:(NSData *)data {
    assert(self.port == port);
    [self.data appendData:data];
    dispatch_async(self.streamQueue, ^{
        while (self.parsedBytes < [self.data length]) {
            [self parseData];
        }
    });
}

- (BOOL)sendDictionary:(NSDictionary *)dict shouldSynchronize:(BOOL)shouldSynchronize error:(NSError * _Nullable *)error {
    UTMLog(@"Debug JSON send -> %@", dict);
    if (!self.port || !self.port.isOpen) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Port is not connected.", "UTMJSONStream")}];
        }
        return NO;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:error];
    if (!data) {
        return NO;
    }
    if (shouldSynchronize) {
        dispatch_async(self.streamQueue, ^{
            [self.port writeData:[NSData dataWithBytes:"\xFF" length:1]];
            [self.port writeData:data];
            self.state = PARSER_WAITING_FOR_DELIMITER;
        });
    } else {
        [self.port writeData:data];
    }
    return YES;
}

@end
