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
#import "WKWebView+Workarounds.h"
#import "VMKeyboardView.h"
#import <CoreGraphics/CoreGraphics.h>

NSString *const kVMSendInputHandler = @"UTMSendInput";
NSString* const kVMDebugHandler = @"UTMDebug";

@interface VMTerminalViewController ()

@property (nonatomic, readonly) BOOL largeScreen;

@end

@implementation VMTerminalViewController {
    // status bar
    BOOL _prefersStatusBarHidden;
    BOOL _isKeyboardActive;
    BOOL _toolbarVisible;
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
}

@synthesize vmMessage;
@synthesize vmConfiguration;
@synthesize keyboardVisible;

- (BOOL)largeScreen {
    return self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular;
}

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
    NSLog(@"Input accessory : %d", _inputAccessoryView == nil);
    // webview setup
    [_webView setCustomInputAccessoryView: _inputAccessoryView];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMDebugHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
    
    if (self.largeScreen) {
        self.prefersStatusBarHidden = YES;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWebViewScrollOffset: [self.toolbarAccessoryView isHidden]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];

    if (self.vm.state == kVMStopped || self.vm.state == kVMSuspended) {
        [self.vm startVM];
        NSAssert([[self.vm ioService] isKindOfClass: [UTMTerminalIO class]], @"VM ioService must be UTMTerminalIO, but is: %@!", NSStringFromClass([[self.vm ioService] class]));
        UTMTerminalIO* io = (UTMTerminalIO*) [self.vm ioService];
        self.terminal = io.terminal;
        [self.terminal setDelegate: self];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

#pragma mark - Input accessory view

- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender {
    if (!sender.toggleable) {
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyDown(%d);", [sender scanCode]];
        [_webView evaluateJavaScript:jsString completionHandler:nil];
    }
}

- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender {
    if (sender.toggleable) {
        sender.toggled = !sender.toggled;
    }
    
    if (sender.toggleable) {
        NSString* jsKey = [self jsModifierForScanCode: sender.scanCode];
        if (jsKey == nil) {
            return;
        }
        
        NSString* jsTemplate = sender.toggled ? @"modifierDown(\"%@\");" : @"modifierUp(\"%@\");";
        NSString* jsString = [NSString stringWithFormat: jsTemplate, jsKey];
        [_webView evaluateJavaScript:jsString completionHandler: nil];
    } else {
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyUp(%d);", [sender scanCode]];
        [_webView evaluateJavaScript:jsString completionHandler:nil];
    }
}

- (IBAction)keyboardPastePressed:(UIButton *)sender {
    UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
    NSString* string = pasteboard.string;
    if (string != nil) {
        [_terminal sendInput: string];
    }
}

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    [self showKeyboardPressed: sender];
}

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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAccessoryViewHeight];
    NSLog(@"Trait collection did change");
}

- (void)updateAccessoryViewHeight {
    CGRect currentFrame = self.inputAccessoryView.frame;
    CGFloat height;
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
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
    static BOOL hasStartedOnce = NO;
    if (hasStartedOnce && state == kVMStopped) {
        exit(0);
    }
    
    switch (state) {
        case kVMError: {
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"UTMQemuManager");
            [self showAlert:msg actions:nil completion:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];
            break;
        }
        case kVMStopped:
        case kVMPaused:
        case kVMSuspended: {
            self.toolbarVisible = YES;
            self.pauseResumeButton.enabled = YES;
            self.restartButton.enabled = NO;
            [self.pauseResumeButton setImage:[UIImage imageNamed:@"Toolbar Start"] forState:UIControlStateNormal];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Exit"] forState:UIControlStateNormal];
            break;
        }
        case kVMPausing:
        case kVMStopping:
        case kVMStarting:
        case kVMResuming: {
            self.pauseResumeButton.enabled = NO;
            self.restartButton.enabled = NO;
            self.webView.userInteractionEnabled = NO;
            self.keyboardButton.enabled = NO;
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Exit"] forState:UIControlStateNormal];
            break;
        }
        case kVMStarted: {
            hasStartedOnce = YES; // auto-quit after VM ends
            self.pauseResumeButton.enabled = YES;
            self.restartButton.enabled = YES;
            self.keyboardButton.enabled = YES;
            self.webView.userInteractionEnabled = YES;
            [self.pauseResumeButton setImage:[UIImage imageNamed:@"Toolbar Pause"] forState:UIControlStateNormal];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Power"] forState:UIControlStateNormal];
            break;
        }
    }
}

#pragma mark - Toolbar IBActions

- (IBAction)pauseResumePressed:(UIButton *)sender {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        if (self.vm.state == kVMStarted) {
            [self.vm pauseVM];
            [self.vm saveVM];
        } else if (self.vm.state == kVMPaused) {
            [self.vm resumeVM];
        }
    });
}

- (IBAction)powerPressed:(UIButton *)sender {
    if (self.vm.state == kVMStarted) {
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMTerminalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                [self.vm quitVM];
                exit(0);
            });
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMTerminalViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to stop this VM and exit? Any unsaved changes will be lost.", @"VMDisplayMetalViewController")
                actions:@[yes, no]
             completion:nil];
    } else {
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMTerminalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            exit(0);
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMTerminalViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to exit UTM?.", @"VMTerminalViewController")
                actions:@[yes, no]
             completion:nil];
    }
}

- (IBAction)restartPressed:(UIButton *)sender {
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMTerminalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm resetVM];
        });
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMTerminalViewController") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to reset this VM? Any unsaved changes will be lost.", @"VMTerminalViewController")
            actions:@[yes, no]
         completion:nil];
}

- (IBAction)showKeyboardPressed:(UIButton *)sender {    
    if (_isKeyboardActive) {
        [self hideKeyboard];
        _isKeyboardActive = NO;
    } else {
        [self showKeyboard];
        _isKeyboardActive = YES;
    }
}

- (IBAction)hideToolbarPressed:(UIButton *)sender {
    [self hideToolbar];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownHideToolbarAlert"]) {
        NSString* msg = NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"Shown once when hiding toolbar.");
        [self showAlert:msg actions:nil completion:^(UIAlertAction *action){
            [defaults setBool:YES forKey:@"HasShownHideToolbarAlert"];
        }];
    }
}

#pragma mark - Toolbar actions

- (BOOL)keyboardVisible {
    return _isKeyboardActive;
}

- (void)setKeyboardVisible:(BOOL)keyboardVisible {
    if (keyboardVisible) {
        [self showKeyboard];
    } else {
        [self hideKeyboard];
    }
    _isKeyboardActive = keyboardVisible;
}

- (BOOL)toolbarVisible {
    return _toolbarVisible;
}

- (void)setToolbarVisible:(BOOL)toolbarVisible {
    if (toolbarVisible) {
        [self showToolbar];
    } else {
        [self hideToolbar];
    }
    _toolbarVisible = toolbarVisible;
}

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
        if (!self.largeScreen) {
            self.prefersStatusBarHidden = NO;
        }
    } completion:nil];
    [self updateWebViewScrollOffset:NO];
}

- (void)hideKeyboard {
    [_webView endEditing:YES];
}

- (void)showKeyboard {
    [_webView toggleKeyboardDisplayRequiresUserAction:NO];
    NSString* jsString = @"focusTerminal()";
    [_webView evaluateJavaScript: jsString completionHandler:^(id _Nullable _, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error while focusing terminal element");
        }
        [self->_webView toggleKeyboardDisplayRequiresUserAction:YES];
    }];
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
