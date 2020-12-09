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

#import "VMDisplayTerminalViewController.h"
#import "VMDisplayTerminalViewController+Keyboard.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Display.h"
#import "UTMLogging.h"
#import "UTMVirtualMachine.h"
#import "UTMVirtualMachine+Terminal.h"
#import "UIViewController+Extensions.h"
#import "WKWebView+Workarounds.h"

NSString *const kVMDefaultResizeCmd = @"stty cols $COLS rows $ROWS\\n";

NSString *const kVMSendInputHandler = @"UTMSendInput";
NSString* const kVMDebugHandler = @"UTMDebug";
NSString* const kVMSendGestureHandler = @"UTMSendGesture";
NSString* const kVMSendTerminalSizeHandler = @"UTMSendTerminalSize";

@interface VMDisplayTerminalViewController ()

@end

@implementation VMDisplayTerminalViewController {
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // webview setup
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Disable this bar in Settings -> General -> Keyboards -> Shortcuts", @"VMDisplayTerminalViewController")
                                                             style:UIBarButtonItemStylePlain
                                                            target:nil
                                                            action:nil];
    UIBarButtonItemGroup *group = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[ item ]
                                                                    representativeItem:nil];
    
    _webView.inputAssistantItem.leadingBarButtonGroups = @[ group ];
    _webView.inputAssistantItem.trailingBarButtonGroups = @[];
    [_webView setCustomInputAccessoryView: self.inputAccessoryView];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMDebugHandler];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendGestureHandler];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendTerminalSizeHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
    _webView.navigationDelegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    if (self.vm.state == kVMStopped || self.vm.state == kVMSuspended) {
        if ([self.vm startVM]) {
            self.vm.ioDelegate = self;
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self updateSettings];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // hack to make sure keyboard is shown
        self.keyboardVisible = self.keyboardVisible;
    });
}

- (void)updateSettings {
    [_webView evaluateJavaScript:[NSString stringWithFormat:@"changeFont('%@', %ld);", self.vmConfiguration.consoleFont, self.vmConfiguration.consoleFontSize.integerValue] completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        UTMLog(@"changeFont error: %@", error);
    }];
    [_webView evaluateJavaScript:[NSString stringWithFormat:@"setCursorBlink(%@);", self.vmConfiguration.consoleCursorBlink ? @"true" : @"false"] completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        UTMLog(@"setCursorBlink error: %@", error);
    }];
}

#pragma mark - Keyboard

- (void)setKeyboardVisible:(BOOL)keyboardVisible {
    if (keyboardVisible) {
        [self showKeyboard];
    } else {
        [self hideKeyboard];
    }
    [super setKeyboardVisible:keyboardVisible];
}

- (void)hideKeyboard {
    [_webView endEditing:YES];
}

- (void)showKeyboard {
    [_webView toggleKeyboardDisplayRequiresUserAction:NO];
    NSString* jsString = @"focusTerminal()";
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error != nil) {
            UTMLog(@"Error while focusing terminal element: %@", error);
        }
        [self->_webView toggleKeyboardDisplayRequiresUserAction:YES];
    }];
}

#pragma mark - Resize console

- (void)changeDisplayZoom:(UIButton *)sender {
    NSString *cmd = self.vmConfiguration.consoleResizeCommand;
    if (cmd.length == 0) {
        cmd = kVMDefaultResizeCmd;
    }
    cmd = [cmd stringByReplacingOccurrencesOfString:@"$COLS" withString:[self.columns stringValue]];
    cmd = [cmd stringByReplacingOccurrencesOfString:@"$ROWS" withString:[self.rows stringValue]];
    cmd = [cmd stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    [self.vm sendInput:cmd];
}

#pragma mark - Gestures

- (void)handleGestureFromJs:(NSString *)gesture {
    if ([gesture isEqualToString:@"threeSwipeUp"]) {
        if (self.toolbarVisible) {
            self.toolbarVisible = NO;
        } else if (!self.keyboardVisible) {
            self.keyboardVisible = YES;
        }
    } else if ([gesture isEqualToString:@"threeSwipeDown"]) {
        if (self.keyboardVisible) {
            self.keyboardVisible = NO;
        } else if (!self.toolbarVisible) {
            self.toolbarVisible = YES;
        }
    }
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([[message name] isEqualToString: kVMSendInputHandler]) {
        UTMLog(@"Received input from HTerm: %@", (NSString*) message.body);
        [self.vm sendInput: (NSString*) message.body];
        [self resetModifierToggles];
    } else if ([[message name] isEqualToString: kVMDebugHandler]) {
        UTMLog(@"Debug message from HTerm: %@", (NSString*) message.body);
    } else if ([[message name] isEqualToString: kVMSendGestureHandler]) {
        UTMLog(@"Gesture message from HTerm: %@", (NSString*) message.body);
        [self handleGestureFromJs:message.body];
    } else if ([[message name] isEqualToString: kVMSendTerminalSizeHandler]) {
        UTMLog(@"Terminal resize: %@", message.body);
        self.columns = message.body[0];
        self.rows = message.body[1];
    }
}

#pragma mark - UTMTerminalDelegate

- (void)terminal:(UTMTerminal *)terminal didReceiveData:(NSData *)data {
    NSMutableString* dataString = [NSMutableString stringWithString: @"["];
    const uint8_t* buf = (uint8_t*) [data bytes];
    for (size_t i = 0; i < [data length]; i++) {
        [dataString appendFormat: @"%u,", buf[i]];
    }
    [dataString appendString:@"]"];
    //UTMLog(@"Array: %@", dataString);
    NSString* jsString = [NSString stringWithFormat: @"writeData(new Uint8Array(%@));", dataString];
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error != nil) {
            UTMLog(@"JS evaluation failed: %@", [error localizedDescription]);
        }
    }];
}

#pragma mark - UTMVirtualMachineDelegate

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    [super virtualMachine:vm transitionToState:state];
    
    switch (state) {
        case kVMPausing:
        case kVMStopping:
        case kVMStarting:
        case kVMResuming: {
            self.webView.userInteractionEnabled = NO;
            break;
        }
        case kVMStarted: {
            self.webView.userInteractionEnabled = YES;
            break;
        }
        default: {
            break;
        }
    }
}

@end
