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

#import "UTMLogging.h"
#import "UTMTerminalIO.h"
#import "UTMQemuConfiguration.h"

@class CSScreenshot;

@interface UTMTerminalIO ()

@property (nonatomic, readwrite) BOOL isConnected;

@end

@implementation UTMTerminalIO

- (id)initWithConfiguration: (UTMQemuConfiguration*) configuration {
    if (self = [super init]) {
        NSURL* terminalURL = [configuration terminalInputOutputURL];
        _terminal = [[UTMTerminal alloc] initWithURL: terminalURL];
    }
    
    return self;
}

- (void)dealloc {
    [self disconnect];
}

#pragma mark - UTMInputOutput

- (BOOL)startWithError:(NSError *__autoreleasing  _Nullable * _Nullable)err {
    // tell terminal to start listening to pipes
    return [_terminal connectWithError: err];
}

- (void)connectWithCompletion:(ioConnectCompletionHandler_t)block {
    // there's no connection to be made, so just return YES
    self.isConnected = YES;
    block(YES, nil);
}

- (void)disconnect {
    self.isConnected = NO;
    [_terminal disconnect];
}

- (CSScreenshot *)screenshot {
    return nil;
}

- (void)syncViewState:(UTMViewState *)viewState {
}

- (void)restoreViewState:(UTMViewState *)viewState {
}

@end
