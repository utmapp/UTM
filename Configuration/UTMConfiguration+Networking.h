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

#import "UTMConfiguration.h"

@class UTMConfigurationPortForward;

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration (Networking)

@property (nonatomic, assign) BOOL networkEnabled;
@property (nonatomic, assign) BOOL networkIsolate;
@property (nonatomic, nullable, copy) NSString *networkMode;
@property (nonatomic, nullable, copy) NSString *networkBridgeInterface;
@property (nonatomic, nullable, copy) NSString *networkCard;
@property (nonatomic, nullable, copy) NSString *networkCardMac;
@property (nonatomic, nullable, copy) NSString *networkAddress;
@property (nonatomic, nullable, copy) NSString *networkAddressIPv6;
@property (nonatomic, nullable, copy) NSString *networkHost;
@property (nonatomic, nullable, copy) NSString *networkHostIPv6;
@property (nonatomic, nullable, copy) NSString *networkDhcpStart;
@property (nonatomic, nullable, copy) NSString *networkDhcpHost;
@property (nonatomic, nullable, copy) NSString *networkDhcpDomain;
@property (nonatomic, nullable, copy) NSString *networkDnsServer;
@property (nonatomic, nullable, copy) NSString *networkDnsServerIPv6;
@property (nonatomic, nullable, copy) NSString *networkDnsSearch;
@property (nonatomic, readonly) NSInteger countPortForwards;

- (void)migrateNetworkConfigurationIfNecessary;

- (NSInteger)newPortForward:(UTMConfigurationPortForward *)argument;
- (nullable UTMConfigurationPortForward *)portForwardForIndex:(NSInteger)index;
- (void)updatePortForwardAtIndex:(NSInteger)index withValue:(UTMConfigurationPortForward *)argument;
- (void)removePortForwardAtIndex:(NSInteger)index;
- (NSArray<UTMConfigurationPortForward *> *)portForwards;

@end

NS_ASSUME_NONNULL_END
