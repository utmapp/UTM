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
#import "UTMConfiguration.h"
#import "UIViewController+Extensions.h"

NSString *const kVMSendInputHandler = @"UTMSendInput";

@implementation VMTerminalViewController {
    // status bar
    BOOL _prefersStatusBarHidden;
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
}

@synthesize vmScreenshot;
@synthesize vmMessage;
@synthesize vmConfiguration;

- (BOOL)prefersStatusBarHidden {
    return _prefersStatusBarHidden;
}

- (void)setPrefersStatusBarHidden:(BOOL)prefersStatusBarHidden {
    _prefersStatusBarHidden = prefersStatusBarHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES; // always hide home indicator
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // UI setup
    [self.navigationController setNavigationBarHidden:YES animated: YES];
    [self setUpGestures];
    
    // webview setup
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWebViewScrollOffset: [self.toolbarAccessoryView isHidden]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];

    // terminal setup
    [_terminal setDelegate: self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)changeVM:(UTMVirtualMachine *)vm {
    NSAssert([[vm ioService] isKindOfClass: [UTMTerminalIO class]], @"VM ioService must be UTMTerminalIO, but is: %@!", NSStringFromClass([[vm ioService] class]));
    UTMTerminalIO* io = (UTMTerminalIO*) [vm ioService];
    self.vm = vm;
    self.terminal = io.terminal;
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
    NSLog(@"GEsture!!");
    if (sender.direction == UISwipeGestureRecognizerDirectionUp) {
        if (!self.toolbarAccessoryView.isHidden) {
            [self hideToolbar];
        }
    } else if (sender.direction == UISwipeGestureRecognizerDirectionDown) {
        if (self.toolbarAccessoryView.isHidden) {
            [self showToolbar];
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
        if (error == nil) {
            NSLog(@"JS evaluation success");
        } else {
            NSLog(@"JS evaluation failed: %@", [error localizedDescription]);
        }
    }];
}

#pragma mark - UTMVirtualMachineDelegate

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    switch (state) {
        case kVMError: {
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"UTMQemuManager");
            [self showAlert:msg completion:^(UIAlertAction *action){
                [self performSegueWithIdentifier:@"returnToList" sender:self];
            }];
            break;
        }
        case kVMStopping:
        case kVMStopped:
        case kVMPausing:
        case kVMPaused: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSegueWithIdentifier:@"returnToList" sender:self];
            });
            break;
        }
        default: {
            break; // TODO: Implement
        }
    }
}

#pragma mark - Toolbar IBActions

- (IBAction)resumePressed:(UIButton *)sender {
}

- (IBAction)powerPressed:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"Are you sure you want to stop this VM?", @"VMDisplayMetalViewController") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayMetalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm quitVM];
        });
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayMetalViewController") style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:yes];
    [alert addAction:no];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)showKeyboardPressed:(UIButton *)sender {
    // FIXME: element.focus() from JS doesn't work in WKWebView, needs some workaround
    // set focus on some element in JS
    NSString* jsString = @"focusTerminal()";
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error == nil) {
            NSLog(@"Successfuly focused terminal element");
        } else {
            NSLog(@"Error while focusing terminal element");
        }
    }];
}

- (IBAction)hideToolbarPressed:(UIButton *)sender {
    [self hideToolbar];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownHideToolbarAlert"]) {
        [self showAlert:NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"Shown once when hiding toolbar.") completion:^(UIAlertAction *action){
            [defaults setBool:YES forKey:@"HasShownHideToolbarAlert"];
        }];
    }
}

#pragma mark - Toolbar actions

- (void)hideToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = YES;
        self.prefersStatusBarHidden = YES;
    } completion:nil];
    [self updateWebViewScrollOffset:YES];
}

- (void)showToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = NO;
        self.prefersStatusBarHidden = NO;
    } completion:nil];
    [self updateWebViewScrollOffset:NO];
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
