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

#import "UTMQemuManager-Protected.h"
#import "UTMJSONStream.h"
#import "UTMLogging.h"
#import "qapi-emit-events.h"

extern NSString *const kUTMErrorDomain;
const int64_t kRPCTimeout = (int64_t)10*NSEC_PER_SEC;

typedef void(^rpcCompletionHandler_t)(NSDictionary *, NSError *);

@interface UTMQemuManager ()

@property (nonatomic, nullable) rpcCompletionHandler_t rpcCallback;
@property (nonatomic) UTMJSONStream *jsonStream;
@property (nonatomic) dispatch_semaphore_t cmdLock;

@end

@implementation UTMQemuManager

@synthesize isConnected = _isConnected;

- (void)setIsConnected:(BOOL)isConnected {
    _isConnected = isConnected;
}

void qmp_rpc_call(CFDictionaryRef args, CFDictionaryRef *ret, Error **err, void *ctx) {
    UTMQemuManager *self = (__bridge UTMQemuManager *)ctx;
    dispatch_semaphore_t rpc_sema = dispatch_semaphore_create(0);
    __block NSDictionary *dict;
    __block NSError *nserr;
    __weak typeof(self) _self = self;
    dispatch_semaphore_wait(self.cmdLock, DISPATCH_TIME_FOREVER);
    self.rpcCallback = ^(NSDictionary *ret_dict, NSError *ret_err){
        NSCAssert(ret_dict || ret_err, @"Both dict and err are null");
        nserr = ret_err;
        dict = ret_dict;
        _self.rpcCallback = nil;
        dispatch_semaphore_signal(rpc_sema); // copy to avoid race condition
    };
    if (![self.jsonStream sendDictionary:(__bridge NSDictionary *)args error:&nserr] && self.rpcCallback) {
        self.rpcCallback(nil, nserr);
    }
    if (dispatch_semaphore_wait(rpc_sema, dispatch_time(DISPATCH_TIME_NOW, kRPCTimeout)) != 0) {
        // possible race between this timeout and the callback being triggered
        self.rpcCallback = ^(NSDictionary *ret_dict, NSError *ret_err){
            _self.rpcCallback = nil;
        };
        nserr = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Timed out waiting for RPC.", "UTMQemuManager")}];
    }
    if (ret) {
        *ret = CFBridgingRetain(dict);
    }
    dict = nil;
    if (nserr) {
        if (err) {
            error_setg(err, "%s", [nserr.localizedDescription cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        UTMLog(@"RPC: %@", nserr);
    }
    dispatch_semaphore_signal(self.cmdLock);
}

- (instancetype)initWithPort:(CSPort *)port {
    self = [super init];
    if (self) {
        self.jsonStream = [[UTMJSONStream alloc] initWithPort:port];
        self.jsonStream.delegate = self;
        self.cmdLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)dealloc {
    if (self.rpcCallback) {
        self.rpcCallback(nil, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Manager being deallocated, killing pending RPC.", "UTMQemuManager")}]);
    }
}

- (void)jsonStream:(UTMJSONStream *)stream connected:(BOOL)connected {
    UTMLog(@"QMP %@", connected ? @"connected" : @"disconnected");
    if (!connected) {
        self.isConnected = NO;
    }
}

- (void)jsonStream:(UTMJSONStream *)stream seenError:(NSError *)error {
    UTMLog(@"QMP stream error seen: %@", error);
    if (self.rpcCallback) {
        self.rpcCallback(nil, error);
    }
}

- (void)jsonStream:(UTMJSONStream *)stream receivedDictionary:(NSDictionary *)dict {
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        if ([key isEqualToString:@"return"]) {
            if (self.rpcCallback) {
                self.rpcCallback(dict, nil);
            } else {
                UTMLog(@"Got unexpected 'return' response: %@", dict);
            }
            *stop = YES;
        } else if ([key isEqualToString:@"error"]) {
            if (self.rpcCallback) {
                self.rpcCallback(nil, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: dict[@"error"][@"desc"]}]);
            } else {
                UTMLog(@"Got unexpected 'error' response: %@", dict);
            }
            *stop = YES;
        } else if ([key isEqualToString:@"event"]) {
            const char *event = [dict[@"event"] cStringUsingEncoding:NSASCIIStringEncoding];
            qapi_event_dispatch(event, (__bridge CFTypeRef)dict, (__bridge void *)self);
            *stop = YES;
        } else if ([self didGetUnhandledKey:key value:val]) {
            *stop = YES;
        }
    }];
}

- (__autoreleasing NSError *)errorForQerror:(Error *)qerr {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithCString:error_get_pretty(qerr) encoding:NSASCIIStringEncoding]}];
}

- (BOOL)didGetUnhandledKey:(NSString *)key value:(id)value {
    return NO;
}

@end
