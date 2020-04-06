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
#import "UTMViewState.h"
#import "CocoaSpice.h"

const int kMaxConnectionTries = 10; // qemu needs to start spice server first

@implementation UTMSpiceIO {
    CSConnection *_spice_connection;
    CSMain *_spice;
    void (^_connectionBlock)(BOOL, NSError*);
}

- (id)initWithConfiguration:(UTMConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
    }
    
    return self;
}

- (void)setDelegate:(id<UTMSpiceIODelegate>)delegate {
    _delegate = delegate;
    _delegate.vmDisplay = self.primaryDisplay;
    _delegate.vmInput = self.primaryInput;
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
    _primaryInput = nil;
    _delegate.vmDisplay = nil;
    _delegate.vmInput = nil;
}

- (BOOL)isSpiceInitialized {
    return _spice != nil && _spice_connection != nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    // make sure the CSDisplay properties are synced with the CSInput
    if ([keyPath isEqualToString:@"primaryDisplay.viewportScale"]) {
        self.primaryInput.viewportScale = self.primaryDisplay.viewportScale;
    } else if ([keyPath isEqualToString:@"primaryDisplay.displaySize"]) {
        self.primaryInput.displaySize = self.primaryDisplay.displaySize;
    }
}

#pragma mark - UTMInputOutput

- (BOOL)startWithError:(NSError **)err {
    [self initializeSpiceIfNeeded];
    if (![_spice spiceStart]) {
        // error
        return NO;
    }
    
    return YES;
}

- (void)connectWithCompletion: (void(^)(BOOL, NSError*)) block {
    int tries = kMaxConnectionTries;
    do {
        [NSThread sleepForTimeInterval:0.1f];
        if ([_spice_connection connect]) {
            break;
        }
    } while (tries-- > 0);
    if (tries == 0) {
        //TODO: error
        block(NO, nil);
    } else {
        _connectionBlock = block;
    }
}

- (void)disconnect {
    [self removeObserver:self forKeyPath:@"primaryDisplay.viewportScale"];
    [self removeObserver:self forKeyPath:@"primaryDisplay.displaySize"];
    [_spice_connection disconnect];
    _spice_connection.delegate = nil;
    _spice_connection = nil;
    [_spice spiceStop];
    _spice = nil;
}

- (UIImage*)screenshot {
    return [self.primaryDisplay screenshot];
}

- (void)setDebugMode:(BOOL)debugMode {
    [_spice spiceSetDebug: debugMode];
}

- (void)syncViewState:(UTMViewState *)viewState {
    viewState.displayOriginX = self.primaryDisplay.viewportOrigin.x;
    viewState.displayOriginY = self.primaryDisplay.viewportOrigin.y;
    viewState.displaySizeWidth = self.primaryDisplay.displaySize.width;
    viewState.displaySizeHeight = self.primaryDisplay.displaySize.height;
    viewState.displayScale = self.primaryDisplay.viewportScale;
}

- (void)restoreViewState:(UTMViewState *)viewState {
    self.primaryDisplay.viewportOrigin = CGPointMake(viewState.displayOriginX, viewState.displayOriginY);
    self.primaryDisplay.displaySize = CGSizeMake(viewState.displaySizeWidth, viewState.displaySizeHeight);
    self.primaryDisplay.viewportScale = viewState.displayScale;
}

#pragma mark - CSConnectionDelegate

- (void)spiceConnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceDisconnected:(CSConnection *)connection {
    NSAssert(connection == _spice_connection, @"Unknown connection");
}

- (void)spiceError:(CSConnection *)connection err:(NSString *)msg {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    //[self errorTriggered:msg];
    if (_connectionBlock) {
        _connectionBlock(NO, nil);
        _connectionBlock = nil;
    }
}

- (void)spiceDisplayCreated:(CSConnection *)connection display:(CSDisplayMetal *)display input:(CSInput *)input {
    NSAssert(connection == _spice_connection, @"Unknown connection");
    if (display.channelID == 0 && display.monitorID == 0) {
        _primaryDisplay = display;
        _primaryInput = input;
        _delegate.vmDisplay = display;
        _delegate.vmInput = input;
        [self addObserver:self forKeyPath:@"primaryDisplay.viewportScale" options:0 context:nil];
        [self addObserver:self forKeyPath:@"primaryDisplay.displaySize" options:0 context:nil];
        if (_connectionBlock) {
            _connectionBlock(YES, nil);
            _connectionBlock = nil;
        }
    }
}

- (void)spiceSessionCreated:(CSConnection *)connection session:(CSSession *)session {
    session.shareClipboard = self.configuration.sharingClipboardEnabled;
}

@end
