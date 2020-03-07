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

NSString *const kVMSendInputHandler = @"UTMSendInput";

@implementation VMTerminalViewController {
    // status bar
    BOOL _prefersStatusBarHidden;
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
    // terminal setup
    NSURL* terminalIOURL = [[_vm configuration] terminalInputOutputURL];
    _terminal = [[UTMTerminal alloc] initWithURL: terminalIOURL];
    [_terminal setDelegate: self];
    
    NSError* error;
    [_terminal connectWithError: &error];
    if (error != nil) {
        NSLog(@"Terminal connection error!");
    }
    
    [_vm startVM];
    // message handlers
    [[[_webView configuration] userContentController] addScriptMessageHandler: self name: kVMSendInputHandler];
    
    // load terminal.html
    NSURL* resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL* indexFile = [resourceURL URLByAppendingPathComponent: @"terminal.html"];
    [_webView loadFileURL: indexFile allowingReadAccessToURL: resourceURL];
    
    [self updateWebViewScrollOffset: NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWebViewScrollOffset: [self.toolbarAccessoryView isHidden]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([[message name] isEqualToString: kVMSendInputHandler]) {
        NSLog(@"Received input from HTerm: %@", (NSString*) message.body);
        [_terminal sendInput: (NSString*) message.body];
    }
}

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
    // set focus on some element in JS 
}

- (IBAction)hideToolbarPressed:(UIButton *)sender {
    [self hideToolbar];
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
//    CGFloat offset = 0.0;
//    if (!toolbarHidden) {
//        offset = self.toolbarAccessoryView.bounds.size.height;
//    }
}

@end
