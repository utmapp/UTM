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

#import "UTMConfigurationPortForward.h"
#import "UTM-Swift.h"

@implementation UTMConfigurationPortForward

@synthesize protocol = _protocol;
@synthesize hostAddress = _hostAddress;
@synthesize hostPort = _hostPort;
@synthesize guestAddress = _guestAddress;
@synthesize guestPort = _guestPort;

- (void)setProtocol:(NSString *)protocol {
    [self propertyWillChange];
    _protocol = protocol;
}

- (NSString *)protocol {
    if (_protocol) {
        return _protocol;
    } else {
        return @"tcp";
    }
}

- (void)setHostAddress:(NSString *)hostAddress {
    [self propertyWillChange];
    _hostAddress = hostAddress;
}

- (NSString *)hostAddress {
    if (_hostAddress) {
        return _hostAddress;
    } else {
        return @"";
    }
}

- (void)setHostPort:(NSNumber *)hostPort {
    [self propertyWillChange];
    _hostPort = hostPort;
}

- (NSNumber *)hostPort {
    if (_hostPort) {
        return _hostPort;
    } else {
        return @(0);
    }
}

- (void)setGuestAddress:(NSString *)guestAddress {
    [self propertyWillChange];
    _guestAddress = guestAddress;
}

- (NSString *)guestAddress {
    if (_guestAddress) {
        return _guestAddress;
    } else {
        return @"";
    }
}

- (void)setGuestPort:(NSNumber *)guestPort {
    [self propertyWillChange];
    _guestPort = guestPort;
}

- (NSNumber *)guestPort {
    if (_guestPort) {
        return _guestPort;
    } else {
        return @(0);
    }
}

@end
