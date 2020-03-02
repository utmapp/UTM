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

#import "VMTerminalViewController.h"

NSString *const kVMSendInputHandler = @"UTMSendInput";

@implementation VMTerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // ...get vm name
    // terminal setup
    _terminal = [[UTMTerminal alloc] initWithName: @"vmName"];
    [_terminal setDelegate: self];
    // message handlers
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([[message name] isEqualToString: kVMSendInputHandler]) {
        NSLog(@"Received input from HTerm: %@", (NSString*) message.body);
        [_terminal sendInput: (NSString*) message.body];
    }
}

- (void)terminal:(UTMTerminal *)terminal didReceiveData:(NSData *)data {
    NSString* dataString;
    NSString* jsString = [NSString stringWithFormat: @"writeData(new Uint8Array(%@));", dataString];
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error == nil) {
            NSLog(@"JS evaluation success");
        } else {
            NSLog(@"JS evaluation failed: %@", [error localizedDescription]);
        }
    }];
}

@end
