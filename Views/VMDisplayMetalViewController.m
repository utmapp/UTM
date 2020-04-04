//
// Copyright © 2019 osy. All rights reserved.
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

#import "VMDisplayMetalViewController.h"
#import "VMDisplayMetalViewController+Keyboard.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "VMDisplayMetalViewController+Pointer.h"
#import "UTMRenderer.h"
#import "UTMVirtualMachine.h"
#import "VMKeyboardView.h"
#import "UTMQemuManager.h"
#import "VMConfigExistingViewController.h"
#import "VMKeyboardButton.h"
#import "UIViewController+Extensions.h"
#import "UTMConfiguration.h"
#import "CSDisplayMetal.h"
#import "UTMSpiceIO.h"

@interface VMDisplayMetalViewController ()

@property (nonatomic, readwrite, weak) UTMSpiceIO *spiceIO;
@property (nonatomic, readonly) BOOL largeScreen;

@end

@implementation VMDisplayMetalViewController {
    UTMRenderer *_renderer;
    
    // status bar
    BOOL _prefersStatusBarHidden;
    
    // visibility
    BOOL _toolbarVisible;
    BOOL _keyboardVisible;
    
    // save state
    BOOL _hasAutoSave;
}

@synthesize vmMessage;
@synthesize vmConfiguration;
@synthesize vmDisplay;
@synthesize vmInput;

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

- (BOOL)serverModeCursor {
    return self.vmInput.serverModeCursor;
}

- (BOOL)autosaveBackground {
    return [self boolForSetting:@"AutosaveBackground"];
}

- (BOOL)autosaveLowMemory {
    return [self boolForSetting:@"AutosaveLowMemory"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set the view to use the default device
    self.mtkView.device = MTLCreateSystemDefaultDevice();
    if (!self.mtkView.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    
    _renderer = [[UTMRenderer alloc] initWithMetalKitView:self.mtkView];
    if (!_renderer) {
        NSLog(@"Renderer failed initialization");
        return;
    }
    
    // Initialize our renderer with the view size
    [_renderer mtkView:self.mtkView drawableSizeWillChange:self.mtkView.drawableSize];
    _renderer.sourceScreen = self.vmDisplay;
    _renderer.sourceCursor = self.vmInput;
    
    self.mtkView.delegate = _renderer;
    
    [self initTouch];
    // Pointing device support on iPadOS 13.4 GM or later
    if (@available(iOS 13.4, *)) {
        // Betas of iPadOS 13.4 did not include this API, that's why I check if the class exists
        if (NSClassFromString(@"UIPointerInteraction") != nil) {
            [self initPointerInteraction];
        }
    }

    // view state and observers
    _toolbarVisible = YES;
    _keyboardVisible = NO;
    
    if (self.largeScreen) {
        self.prefersStatusBarHidden = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.vm.state == kVMStopped || self.vm.state == kVMSuspended) {
        [self.vm startVM];
        NSAssert([[self.vm ioService] isKindOfClass: [UTMSpiceIO class]], @"VM ioService must be UTMSpiceIO, but is: %@!", NSStringFromClass([[self.vm ioService] class]));
        UTMSpiceIO* spiceIO = (UTMSpiceIO*) [self.vm ioService];
        self.spiceIO = spiceIO;
        self.spiceIO.delegate = self;
    }
}

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    static BOOL hasStartedOnce = NO;
    if (hasStartedOnce && state == kVMStopped) {
        exit(0);
    }
    switch (state) {
        case kVMError: {
            [self.placeholderIndicator stopAnimating];
            self.resumeBigButton.hidden = YES;
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured. UTM will terminate.", @"VMDisplayMetalViewController");
            [self showAlert:msg actions:nil completion:^(UIAlertAction *action){
                exit(0);
            }];
            break;
        }
        case kVMStopped:
        case kVMPaused:
        case kVMSuspended: {
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.mtkView.hidden = YES;
                self.placeholderView.hidden = NO;
                self.placeholderImageView.hidden = NO;
                self.placeholderImageView.image = self.vm.screenshot;
                if (state == kVMPaused) {
                    self.resumeBigButton.hidden = NO;
                }
            } completion:nil];
            [self.placeholderIndicator stopAnimating];
            self.toolbarVisible = YES; // always show toolbar when paused
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
            self.resumeBigButton.hidden = YES;
            self.pauseResumeButton.enabled = NO;
            self.restartButton.enabled = NO;
            self.placeholderView.hidden = NO;
            [self.placeholderIndicator startAnimating];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Exit"] forState:UIControlStateNormal];
            break;
        }
        case kVMStarted: {
            hasStartedOnce = YES; // auto-quit after VM ends
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.mtkView.hidden = NO;
                self.placeholderView.hidden = YES;
                self.placeholderImageView.hidden = YES;
                self.resumeBigButton.hidden = YES;
            } completion:nil];
            [self.placeholderIndicator stopAnimating];
            self.pauseResumeButton.enabled = YES;
            self.restartButton.enabled = YES;
            [self.pauseResumeButton setImage:[UIImage imageNamed:@"Toolbar Pause"] forState:UIControlStateNormal];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Power"] forState:UIControlStateNormal];
            self->_renderer.sourceScreen = self.vmDisplay;
            self->_renderer.sourceCursor = self.vmInput;
            break;
        }
    }
}

#pragma mark - Helper Functions

- (void)sendExtendedKey:(SendKeyType)type code:(int)code {
    uint32_t x = __builtin_bswap32(code);
    while ((x & 0xFF) == 0) {
        x = x >> 8;
    }
    while (x) {
        [self.vmInput sendKey:type code:(x & 0xFF)];
        x = x >> 8;
    }
}

- (void)onDelay:(float)delay action:(void (^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*0.1), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), block);
}

- (BOOL)boolForSetting:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (NSInteger)integerForSetting:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

#pragma mark - Toolbar actions

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)hideToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = YES;
        self.prefersStatusBarHidden = YES;
    } completion:nil];
}

- (void)showToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = NO;
        if (!self.largeScreen) {
            self.prefersStatusBarHidden = NO;
        }
    } completion:nil];
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

- (BOOL)keyboardVisible {
    return _keyboardVisible;
}

- (void)setKeyboardVisible:(BOOL)keyboardVisible {
    if (keyboardVisible) {
        [self.keyboardView becomeFirstResponder];
    } else {
        [self.keyboardView resignFirstResponder];
    }
    _keyboardVisible = keyboardVisible;
}

- (void)setLastDisplayChangeResize:(BOOL)lastDisplayChangeResize {
    _lastDisplayChangeResize = lastDisplayChangeResize;
    if (lastDisplayChangeResize) {
        [self.zoomButton setImage:[UIImage imageNamed:@"Toolbar Minimize"] forState:UIControlStateNormal];
    } else {
        [self.zoomButton setImage:[UIImage imageNamed:@"Toolbar Maximize"] forState:UIControlStateNormal];
    }
}

- (void)resizeDisplayToFit {
    CGSize viewSize = self.mtkView.drawableSize;
    CGSize displaySize = self.vmDisplay.displaySize;
    CGSize scaled = CGSizeMake(viewSize.width / displaySize.width, viewSize.height / displaySize.height);
    self.vmDisplay.viewportScale = MIN(scaled.width, scaled.height);
    self.vmDisplay.viewportOrigin = CGPointMake(0, 0);
}

- (void)resetDisplay {
    self.vmDisplay.viewportScale = 1.0;
    self.vmDisplay.viewportOrigin = CGPointMake(0, 0);
}

- (IBAction)changeDisplayZoom:(UIButton *)sender {
    if (self.lastDisplayChangeResize) {
        [self resetDisplay];
    } else {
        [self resizeDisplayToFit];
    }
    self.lastDisplayChangeResize = !self.lastDisplayChangeResize;
}

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
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayMetalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                [self.vm quitVM];
                exit(0);
            });
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayMetalViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to stop this VM and exit? Any unsaved changes will be lost.", @"VMDisplayMetalViewController")
                actions:@[yes, no]
             completion:nil];
    } else {
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayMetalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            exit(0);
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayMetalViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to exit UTM?.", @"VMDisplayMetalViewController")
                actions:@[yes, no]
             completion:nil];
    }
}

- (IBAction)restartPressed:(UIButton *)sender {
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayMetalViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm resetVM];
        });
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayMetalViewController") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to reset this VM? Any unsaved changes will be lost.", @"VMDisplayMetalViewController")
            actions:@[yes, no]
         completion:nil];
}

- (IBAction)showKeyboardButton:(UIButton *)sender {
    self.keyboardVisible = !self.keyboardVisible;
}

- (IBAction)hideToolbarButton:(UIButton *)sender {
    self.toolbarVisible = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownHideToolbarAlert"]) {
        [self showAlert:NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"VMDisplayMetalViewController") actions:nil completion:^(UIAlertAction *action){
            [defaults setBool:YES forKey:@"HasShownHideToolbarAlert"];
        }];
    }
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"editVMConfig"]){
        NSAssert([segue.destinationViewController isKindOfClass:[UINavigationController class]], @"Destination not a navigation view");
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        NSAssert([navController.topViewController isKindOfClass:[VMConfigExistingViewController class]], @"Invalid segue destination");
        VMConfigExistingViewController *controller = (VMConfigExistingViewController *)navController.topViewController;
        controller.configuration = self.vmConfiguration;
        controller.nameReadOnly = YES;
    }
}

#pragma mark - Notification Handling

- (void)handleEnteredBackground:(NSNotification *)notification {
    NSLog(@"Entering background");
    if (self.autosaveBackground && self.vm.state == kVMStarted) {
        NSLog(@"Saving snapshot");
        __block UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            NSLog(@"Background task end");
            [[UIApplication sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [self.vm saveVM];
            self->_hasAutoSave = YES;
            NSLog(@"Save snapshot complete");
            [[UIApplication sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        });
    }
}

- (void)handleEnteredForeground:(NSNotification *)notification {
    NSLog(@"Entering foreground!");
    if (_hasAutoSave && self.vm.state == kVMStarted) {
        NSLog(@"Deleting snapshot");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm deleteSaveVM];
        });
    }
}

- (void)didReceiveMemoryWarning {
    static BOOL memoryAlertOnce = NO;
    
    [super didReceiveMemoryWarning];
    
    if (self.autosaveLowMemory) {
        NSLog(@"Saving VM state on low memory warning.");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm saveVM];
        });
    }
    
    if (!memoryAlertOnce) {
        memoryAlertOnce = YES;
        [self showAlert:NSLocalizedString(@"Running low on memory! UTM might soon be killed by iOS. You can prevent this by decreasing the amount of memory and/or JIT cache assigned to this VM", @"VMDisplayMetalViewController")
                actions:nil
             completion:nil];
    }
}

@end
