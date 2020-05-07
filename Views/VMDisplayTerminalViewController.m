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
#import "VMKeyboardView.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Display.h"
#import "UIViewController+Extensions.h"
#import "WKWebView+Workarounds.h"

NSString *const kVMSendInputHandler = @"UTMSendInput";
NSString* const kVMDebugHandler = @"UTMDebug";

@interface VMDisplayTerminalViewController ()

@end

@implementation VMDisplayTerminalViewController {
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // UI setup
    [self setUpGestures];
    // webview setup
    [_webView setCustomInputAccessoryView: self.inputAccessoryView];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMDebugHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
    _webView.navigationDelegate = self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWebViewScrollOffset: [self.toolbarAccessoryView isHidden]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    if (self.vm.state == kVMStopped || self.vm.state == kVMSuspended) {
        [self.vm startVM];
        NSAssert([[self.vm ioService] isKindOfClass: [UTMTerminalIO class]], @"VM ioService must be UTMTerminalIO, but is: %@!", NSStringFromClass([[self.vm ioService] class]));
        UTMTerminalIO* io = (UTMTerminalIO*) [self.vm ioService];
        self.terminal = io.terminal;
        [self.terminal setDelegate: self];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self updateSettings];
}

- (void)updateSettings {
    [_webView evaluateJavaScript:[NSString stringWithFormat:@"changeFont('%@', %ld);", self.vmConfiguration.consoleFont, self.vmConfiguration.consoleFontSize.integerValue] completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        NSLog(@"changeFont error: %@", error);
    }];
    [_webView evaluateJavaScript:[NSString stringWithFormat:@"setCursorBlink(%@);", self.vmConfiguration.consoleCursorBlink ? @"true" : @"false"] completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        NSLog(@"setCursorBlink error: %@", error);
    }];
}

#pragma mark - Keyboard

- (NSString* _Nullable)jsModifierForScanCode: (int) scanCode {
    if (scanCode == 29) {
        return @"ctrlKey";
    } else if (scanCode == 56) {
        return @"altKey";
    } else if (scanCode == 57435) {
        return @"metaKey";
    } else if (scanCode == 42) {
        return @"shiftKey";
    } else {
        return nil;
    }
}

- (void)sendExtendedKey:(SendKeyType)type code:(int)code {
    NSString* jsString;
    NSString* jsKey = [self jsModifierForScanCode: code];
    if (jsKey) {
        NSString* jsTemplate = type == SEND_KEY_PRESS ? @"modifierDown(\"%@\");" : @"modifierUp(\"%@\");";
        jsString = [NSString stringWithFormat: jsTemplate, jsKey];
    } else {
        NSString* jsTemplate = type == SEND_KEY_PRESS ? @"programmaticKeyDown(%d);" : @"programmaticKeyUp(%d);";
        jsString = [NSString stringWithFormat: jsTemplate, code];
    }
    [_webView evaluateJavaScript:jsString completionHandler:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAccessoryViewHeight];
    NSLog(@"Trait collection did change");
}

- (void)updateAccessoryViewHeight {
    CGRect currentFrame = self.inputAccessoryView.frame;
    CGFloat height;
    if (self.largeScreen) {
        // we want large keys
        height = kLargeAccessoryViewHeight;
    } else {
        height = kSmallAccessoryViewHeight;
    }

    if (height != currentFrame.size.height) {
        currentFrame.size.height = height;
        self.inputAccessoryView.frame = currentFrame;
        [self reloadInputViews];
    }
}

#pragma mark - Gestures

- (void)setUpGestures {
    _swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipe:)];
    _swipeUp.numberOfTouchesRequired = 3;
    _swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeUp.delegate = self;
    _swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipe:)];
    _swipeDown.numberOfTouchesRequired = 3;
    _swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeDown.delegate = self;
    [_webView addGestureRecognizer: _swipeUp];
    [_webView addGestureRecognizer: _swipeDown];
}

- (void)gestureSwipe: (UISwipeGestureRecognizer*) sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (sender.direction == UISwipeGestureRecognizerDirectionUp) {
            if (self.toolbarVisible) {
                self.toolbarVisible = NO;
            } else if (!self.keyboardVisible) {
                self.keyboardVisible = YES;
            }
        } else if (sender.direction == UISwipeGestureRecognizerDirectionDown) {
            if (self.keyboardVisible) {
                self.keyboardVisible = NO;
            } else if (!self.toolbarVisible) {
                self.toolbarVisible = YES;
            }
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([[message name] isEqualToString: kVMSendInputHandler]) {
        NSLog(@"Received input from HTerm: %@", (NSString*) message.body);
        [_terminal sendInput: (NSString*) message.body];
    } else if ([[message name] isEqualToString: kVMDebugHandler]) {
        NSLog(@"Debug message from HTerm: %@", (NSString*) message.body);
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
    //NSLog(@"Array: %@", dataString);
    NSString* jsString = [NSString stringWithFormat: @"writeData(new Uint8Array(%@));", dataString];
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"JS evaluation failed: %@", [error localizedDescription]);
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

- (void)updateWebViewScrollOffset: (BOOL) toolbarHidden {
    CGFloat offset = 0.0;
    if (!toolbarHidden) {
        offset = self.toolbarAccessoryView.bounds.size.height;
    }
    [UIView animateWithDuration:0.3 animations:^{
        [self.webViewTopConstraint setConstant: offset];
        [self.webView layoutIfNeeded];
    }];
}

@end
