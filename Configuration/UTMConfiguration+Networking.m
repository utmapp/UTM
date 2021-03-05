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
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigNetworkingKey;

static const NSString *const kUTMConfigNetworkEnabledKey = @"NetworkEnabled";
static const NSString *const kUTMConfigNetworkIsolateGuestKey = @"IsolateGuest";
static const NSString *const kUTMConfigNetworkCardKey = @"NetworkCard";
static const NSString *const kUTMConfigNetworkCardMacKey = @"NetworkCardMAC";
static const NSString *const kUTMConfigNetworkIPSubnetKey = @"IPSubnet";
static const NSString *const kUTMConfigNetworkIPv6SubnetKey = @"IPv6Subnet";
static const NSString *const kUTMConfigNetworkIPHostKey = @"IPHost";
static const NSString *const kUTMConfigNetworkIPv6HostKey = @"IPv6Host";
static const NSString *const kUTMConfigNetworkDHCPStartKey = @"DHCPStart";
static const NSString *const kUTMConfigNetworkDHCPHostKey = @"DHCPHost";
static const NSString *const kUTMConfigNetworkDHCPDomainKey = @"DHCPDomain";
static const NSString *const kUTMConfigNetworkIPDNSKey = @"IPDNS";
static const NSString *const kUTMConfigNetworkIPv6DNSKey = @"IPv6DNS";
static const NSString *const kUTMConfigNetworkDNSSearchKey = @"DNSSearch";

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

#pragma mark - Migration

- (void)migrateNetworkConfigurationIfNecessary {
    // Migrate network settings
    if (!self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkCardKey]) {
        self.networkCard = @"rtl8139";
    }
    // Generate MAC if missing
    if (!self.networkCardMac) {
        self.networkCardMac = [self generateMacAddress];
    }
}

#pragma mark - Generate MAC

- (NSString *)generateMacAddress {
    uint8_t bytes[6];
    
    for (int i = 0; i < 6; i++) {
        bytes[i] = arc4random() % 256;
    }
    // byte 0 should be local
    bytes[0] = (bytes[0] & 0xFC) | 0x2;
    
    return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
}

#pragma mark - Network settings

- (void)setNetworkEnabled:(BOOL)networkEnabled {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkEnabledKey] = @(networkEnabled);
}

- (BOOL)networkEnabled {
    return [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkEnabledKey] boolValue];
}

- (void)setNetworkIsolate:(BOOL)networkLocalhostOnly {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIsolateGuestKey] = @(networkLocalhostOnly);
}

- (BOOL)networkIsolate {
    return [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIsolateGuestKey] boolValue];
}

- (void)setNetworkCard:(NSString *)networkCard {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkCardKey] = networkCard;
}

- (NSString *)networkCard {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkCardKey];
}

- (void)setNetworkCardMac:(NSString *)networkCardMac {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkCardMacKey] = networkCardMac;
}

- (NSString *)networkCardMac {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkCardMacKey];
}

- (void)setNetworkAddress:(NSString *)networkAddress {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPSubnetKey] = networkAddress;
}

- (NSString *)networkAddress {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPSubnetKey];
}

- (void)setNetworkAddressIPv6:(NSString *)networkAddressIPv6 {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6SubnetKey] = networkAddressIPv6;
}

- (NSString *)networkAddressIPv6 {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6SubnetKey];
}

- (void)setNetworkHost:(NSString *)networkHost {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPHostKey] = networkHost;
}

- (NSString *)networkHost {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPHostKey];
}

- (void)setNetworkHostIPv6:(NSString *)networkHostIPv6 {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6HostKey] = networkHostIPv6;
}

- (NSString *)networkHostIPv6 {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6HostKey];
}

- (void)setNetworkDhcpStart:(NSString *)networkDHCPStart {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPStartKey] = networkDHCPStart;
}

- (NSString *)networkDhcpStart {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPStartKey];
}

- (void)setNetworkDhcpHost:(NSString *)networkDhcpHost {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPHostKey] = networkDhcpHost;
}

- (NSString *)networkDhcpHost {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPHostKey];
}

- (void)setNetworkDhcpDomain:(NSString *)networkDhcpDomain {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPDomainKey] = networkDhcpDomain;
}

- (NSString *)networkDhcpDomain {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDHCPDomainKey];
}

- (void)setNetworkDnsServer:(NSString *)networkDnsServer {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPDNSKey] = networkDnsServer;
}

- (NSString *)networkDnsServer {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPDNSKey];
}

- (void)setNetworkDnsServerIPv6:(NSString *)networkDnsServerIPv6 {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6DNSKey] = networkDnsServerIPv6;
}

- (NSString *)networkDnsServerIPv6 {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkIPv6DNSKey];
}

- (void)setNetworkDnsSearch:(NSString *)networkDnsSearch {
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDNSSearchKey] = networkDnsSearch;
}

- (NSString *)networkDnsSearch {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkDNSSearchKey];
}

#pragma mark - Port forwarding

- (NSInteger)countPortForwards {
    return [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] count];
}

- (NSInteger)newPortForward:(UTMConfigurationPortForward *)argument {
    NSInteger index = [self countPortForwards];
    [self updatePortForwardAtIndex:index withValue:argument];
    return index;
}

- (nullable UTMConfigurationPortForward *)portForwardForIndex:(NSInteger)index {
    NSDictionary *dict = self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey][index];
    UTMConfigurationPortForward *portForward = nil;
    if (dict) {
        portForward = [[UTMConfigurationPortForward alloc] init];
        portForward.protocol = dict[kUTMConfigNetworkPortForwardProtocolKey];
        portForward.hostAddress = dict[kUTMConfigNetworkPortForwardHostAddressKey];
        portForward.hostPort = dict[kUTMConfigNetworkPortForwardHostPortKey];
        portForward.guestAddress = dict[kUTMConfigNetworkPortForwardGuestAddressKey];
        portForward.guestPort = dict[kUTMConfigNetworkPortForwardGuestPortKey];
    }
    return portForward;
}

- (void)updatePortForwardAtIndex:(NSInteger)index withValue:(UTMConfigurationPortForward *)argument {
    if (![self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] isKindOfClass:[NSMutableArray class]]) {
        self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] = [NSMutableArray array];
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kUTMConfigNetworkPortForwardProtocolKey] = argument.protocol;
    dict[kUTMConfigNetworkPortForwardHostAddressKey] = argument.hostAddress;
    dict[kUTMConfigNetworkPortForwardHostPortKey] = argument.hostPort;
    dict[kUTMConfigNetworkPortForwardGuestAddressKey] = argument.guestAddress;
    dict[kUTMConfigNetworkPortForwardGuestPortKey] = argument.guestPort;
    [self propertyWillChange];
    self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey][index] = dict;
}

- (void)removePortForwardAtIndex:(NSInteger)index {
    [self propertyWillChange];
    [self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey] removeObjectAtIndex:index];
}

- (NSArray<UTMConfigurationPortForward *> *)portForwards {
    return self.rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkPortForwardKey];
}

@end
