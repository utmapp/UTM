//
// Copyright © 2023 osy. All rights reserved.
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

#import "UTMQemuGuestAgent.h"
#import "UTMQemuManager-Protected.h"
#import "qga-qapi-commands.h"

extern NSString *const kUTMErrorDomain;

@interface UTMQemuGuestAgent ()

@property (nonatomic) BOOL isGuestAgentResponsive;
@property (nonatomic, readwrite) BOOL shouldSynchronizeParser;
@property (nonatomic) dispatch_queue_t guestAgentQueue;

@end

@implementation UTMQemuGuestAgent

- (NSInteger)timeoutSeconds {
    if (self.isGuestAgentResponsive) {
        return 10;
    } else {
        return 1;
    }
}

- (instancetype)initWithPort:(CSPort *)port {
    if (self = [super initWithPort:port]) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, QOS_MIN_RELATIVE_PRIORITY);
        self.guestAgentQueue = dispatch_queue_create("QEMU Guest Agent Server", attr);
    }
    return self;
}

- (void)jsonStream:(UTMJSONStream *)stream seenError:(NSError *)error {
    self.isGuestAgentResponsive = NO;
    [super jsonStream:stream seenError:error];
}

- (void)synchronizeWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    self.isGuestAgentResponsive = NO;
    dispatch_async(self.guestAgentQueue, ^{
        Error *qerr = NULL;
        int64_t random = g_random_int();
        int64_t response = 0;
        self.shouldSynchronizeParser = YES;
        response = qmp_guest_sync_delimited(random, &qerr, (__bridge void *)self);
        self.shouldSynchronizeParser = NO;
        if (qerr) {
            if (completion) {
                completion([self errorForQerror:qerr]);
            }
            return;
        }
        if (response != random) {
            if (completion) {
                completion([NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Mismatched id from guest-sync-delimited.", "UTMQemuGuestAgent")}]);
            }
            return;
        }
        self.isGuestAgentResponsive = YES;
        if (completion) {
            completion(nil);
        }
    });
}

- (void)_withSynchronizeBlock:(NSError * _Nullable (^)(void))block withCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    dispatch_async(self.guestAgentQueue, ^{
        if (!self.isGuestAgentResponsive) {
            [self synchronizeWithCompletion:^(NSError *error) {
                if (error) {
                    if (completion) {
                        completion(error);
                    }
                } else {
                    NSError *error = block();
                    if (completion) {
                        completion(error);
                    }
                }
            }];
        } else {
            NSError *error = block();
            if (completion) {
                completion(error);
            }
        }
    });
}

@end
