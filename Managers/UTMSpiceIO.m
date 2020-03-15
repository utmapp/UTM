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

#import "UTMSpiceIO.h"
#import "UTMConfiguration.h"
#import "CocoaSpice.h"

const int kMaxConnectionTries = 10; // qemu needs to start spice server first

@implementation UTMSpiceIO {
    CSConnection *_spice_connection;
    CSMain *_spice;
}

- (id)initWithConfiguration:(UTMConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
    }
    
    return self;
}

- (void)initializeSpiceIfNeeded {
    if (!_spice) {
        _spice = [[CSMain alloc] init];
    }
    
    if (!_spice_connection) {
        _spice_connection = [[CSConnection alloc] initWithHost:@"127.0.0.1" port:@"5930"];
        _spice_connection.delegate = self;
        _spice_connection.audioEnabled = _configuration.soundEnabled;
    }
    
    _spice_connection.glibMainContext = _spice.glibMainContext;
    [_spice spiceSetDebug:YES];
    _primaryDisplay = nil;
}

- (BOOL)isSpiceInitialized {
    return _spice != nil && _spice_connection != nil;
}

- (BOOL)startWithError:(NSError **)err {
    [self initializeSpiceIfNeeded];
    if (![_spice spiceStart]) {
        // error
        return NO;
    }
    
    return YES;
}

- (BOOL)connectWithError:(NSError **)err {
    int tries = kMaxConnectionTries;
    do {
        [NSThread sleepForTimeInterval:0.1f];
        if ([_spice_connection connect]) {
            break;
        }
    } while (tries-- > 0);
    if (tries == 0) {
        // error
        return NO;
    }
    
    return YES;
}

- (void)disconnect {
    [_spice_connection disconnect];
    _spice_connection.delegate = nil;
    _spice_connection = nil;
    [_spice spiceStop];
    _spice = nil;
}

- (void)spiceConnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceDisconnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceError:(CSConnection *)connection err:(NSString *)msg {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    //[self errorTriggered:msg];
}

- (void)spiceDisplayCreated:(CSConnection *)connection display:(CSDisplayMetal *)display input:(CSInput *)input {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    if (display.channelID == 0 && display.monitorID == 0) {
//        self.delegate.vmDisplay = display;
//        self.delegate.vmInput = input;
        _primaryDisplay = display;
        _primaryInput = input;
    }
}

@end
