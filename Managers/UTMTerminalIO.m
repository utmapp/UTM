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

#import "UTMTerminalIO.h"
#import "UTMConfiguration.h"

@implementation UTMTerminalIO

- (id)initWithConfiguration: (UTMConfiguration*) configuration {
    if (self = [super init]) {
        NSURL* terminalURL = [configuration terminalInputOutputURL];
        _terminal = [[UTMTerminal alloc] initWithURL: terminalURL];
    }
    
    return self;
}

#pragma mark - UTMInputOutput

- (BOOL)startWithError:(NSError *__autoreleasing  _Nullable * _Nullable)err {
    // tell terminal to start listening to pipes
    return [_terminal connectWithError: err];
}

- (void)connectWithCompletion: (void(^)(BOOL, NSError*)) block {
    // there's no connection to be made, so just return YES
    block(YES, nil);
}

- (void)disconnect {
    [_terminal disconnect];
}

@end
