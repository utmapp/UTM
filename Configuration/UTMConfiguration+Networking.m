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

#import "UTMConfiguration+Networking.h"
#import "UTMConfigurationPortForward.h"

static const NSString *const kUTMConfigNetworkingKey = @"Networking";

static const NSString *const kUTMConfigNetworkPortForwardKey = @"PortForward";
static const NSString *const kUTMConfigNetworkPortForwardProtocolKey = @"Protocol";
static const NSString *const kUTMConfigNetworkPortForwardHostAddressKey = @"HostAddress";
static const NSString *const kUTMConfigNetworkPortForwardHostPortKey = @"HostPort";
static const NSString *const kUTMConfigNetworkPortForwardGuestAddressKey = @"GuestAddress";
static const NSString *const kUTMConfigNetworkPortForwardGuestPortKey = @"GuestPort";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Networking)

- (NSUInteger)countPortForwards {
    return [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] count];
}

- (NSUInteger)newPortForward:(UTMConfigurationPortForward *)argument {
    if (![self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] isKindOfClass:[NSMutableArray class]]) {
        self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] = [NSMutableArray array];
    }
    NSUInteger index = [self countPortForwards];
    [self updatePortForwardAtIndex:index withValue:argument];
    return index;
}

- (nullable UTMConfigurationPortForward *)portForwardForIndex:(NSUInteger)index {
    NSDictionary *dict = self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey][index];
    UTMConfigurationPortForward *portForward = nil;
    if (dict) {
        portForward = [[UTMConfigurationPortForward alloc] init];
        portForward.protocol = dict[kUTMConfigNetworkPortForwardProtocolKey];
        portForward.hostAddress = dict[kUTMConfigNetworkPortForwardHostAddressKey];
        portForward.hostPort = [dict[kUTMConfigNetworkPortForwardHostPortKey] integerValue];
        portForward.guestAddress = dict[kUTMConfigNetworkPortForwardGuestAddressKey];
        portForward.guestPort = [dict[kUTMConfigNetworkPortForwardGuestPortKey] integerValue];
    }
    return portForward;
}

- (void)updatePortForwardAtIndex:(NSUInteger)index withValue:(UTMConfigurationPortForward *)argument {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kUTMConfigNetworkPortForwardProtocolKey] = argument.protocol;
    dict[kUTMConfigNetworkPortForwardHostAddressKey] = argument.hostAddress;
    dict[kUTMConfigNetworkPortForwardHostPortKey] = @(argument.hostPort);
    dict[kUTMConfigNetworkPortForwardGuestAddressKey] = argument.guestAddress;
    dict[kUTMConfigNetworkPortForwardGuestPortKey] = @(argument.guestPort);
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey][index] = dict;
}

- (void)removePortForwardAtIndex:(NSUInteger)index {
    [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] removeObjectAtIndex:index];
}

- (NSArray<UTMConfigurationPortForward *> *)portForwards {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey];
}

@end
