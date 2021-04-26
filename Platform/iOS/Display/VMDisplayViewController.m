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

#import "VMDisplayViewController.h"
#import "AppDelegate.h"
#import "UIViewController+Extensions.h"
#import "UTMLocationManager.h"
#import "UTMLogging.h"
#import "UTMVirtualMachine.h"
#import "VMConfigExistingViewController.h"
#import "UTM-Swift.h"

@implementation VMDisplayViewController {
    // status bar
    BOOL _prefersStatusBarHidden;
    
    // save state
    BOOL _hasAutoSave;
}

#pragma mark - NIB Loading

- (void)loadDisplayViewFromNib {
    UINib *nib = [UINib nibWithNibName:@"VMDisplayView" bundle:nil];
    NSArray *arr = [nib instantiateWithOwner:self options:nil];
    NSAssert(arr != nil, @"Failed to load VMDisplayView nib");
    NSAssert(self.displayView != nil, @"Failed to load main view from VMDisplayView nib");
    NSAssert(self.inputAccessoryView != nil, @"Failed to load input view from VMDisplayView nib");
    self.displayView.frame = self.view.bounds;
    self.displayView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.displayView];
    
    // set up other nibs
    self.removableDrivesViewController = [[VMRemovableDrivesViewController alloc] initWithNibName:@"VMRemovableDrivesView" bundle:nil];
#if !defined(WITH_QEMU_TCI)
    self.usbDevicesViewController = [[VMUSBDevicesViewController alloc] initWithNibName:@"VMUSBDevicesView" bundle:nil];
#endif
    
    // hide USB icon if not supported
    self.usbButton.hidden = !self.vm.hasUsbRedirection;
}

#pragma mark - Properties

@synthesize vmConfiguration;
@synthesize vmMessage;
@synthesize keyboardVisible = _keyboardVisible;
@synthesize toolbarVisible = _toolbarVisible;

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

- (BOOL)autosaveBackground {
    return [self boolForSetting:@"AutosaveBackground"];
}

- (BOOL)autosaveLowMemory {
    return [self boolForSetting:@"AutosaveLowMemory"];
}

- (BOOL)runInBackground {
    return [self boolForSetting:@"RunInBackground"];
}

- (BOOL)disableIdleTimer {
    return [self boolForSetting:@"DisableIdleTimer"];
}

#pragma mark - View handling

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadDisplayViewFromNib];

    // view state and observers
    _toolbarVisible = YES;
    
    if (self.largeScreen) {
        self.prefersStatusBarHidden = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChangeFrame:) name:UIKeyboardDidChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(importUTM:) name:UTMImportNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UTMImportNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.runInBackground) {
        UTMLog(@"Start location tracking to enable running in background");
        [[UTMLocationManager sharedInstance] startUpdatingLocation];
    }
}

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    static BOOL hasStartedOnce = NO;
    if (hasStartedOnce && state == kVMStopped) {
        [self terminateApplication];
    }
    switch (state) {
        case kVMError: {
            [self.placeholderIndicator stopAnimating];
            self.resumeBigButton.hidden = YES;
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured. UTM will terminate.", @"VMDisplayViewController");
            [self showAlert:msg actions:nil completion:^(UIAlertAction *action){
                [self terminateApplication];
            }];
            break;
        }
        case kVMStopped:
        case kVMPaused:
        case kVMSuspended: {
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.placeholderView.hidden = NO;
                if (state == kVMPaused) {
                    self.resumeBigButton.hidden = NO;
                }
            } completion:nil];
            [self.placeholderIndicator stopAnimating];
            self.toolbarVisible = YES; // always show toolbar when paused
            self.pauseResumeButton.enabled = YES;
            self.restartButton.enabled = NO;
            self.zoomButton.enabled = NO;
            self.keyboardButton.enabled = NO;
            self.drivesButton.enabled = NO;
            self.usbButton.enabled = NO;
            [self.pauseResumeButton setImage:[UIImage imageNamed:@"Toolbar Start"] forState:UIControlStateNormal];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Exit"] forState:UIControlStateNormal];
            [UIApplication sharedApplication].idleTimerDisabled = NO;
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
            self.zoomButton.enabled = NO;
            self.keyboardButton.enabled = NO;
            self.drivesButton.enabled = NO;
            self.usbButton.enabled = NO;
            [self.placeholderIndicator startAnimating];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Exit"] forState:UIControlStateNormal];
            break;
        }
        case kVMStarted: {
            hasStartedOnce = YES; // auto-quit after VM ends
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.placeholderView.hidden = YES;
                self.resumeBigButton.hidden = YES;
            } completion:nil];
            [self.placeholderIndicator stopAnimating];
            self.pauseResumeButton.enabled = YES;
            self.restartButton.enabled = YES;
            self.zoomButton.enabled = YES;
            self.keyboardButton.enabled = YES;
            self.drivesButton.enabled = YES;
            self.usbButton.enabled = self.vm.hasUsbRedirection;
            [self.pauseResumeButton setImage:[UIImage imageNamed:@"Toolbar Pause"] forState:UIControlStateNormal];
            [self.powerExitButton setImage:[UIImage imageNamed:@"Toolbar Power"] forState:UIControlStateNormal];
            [UIApplication sharedApplication].idleTimerDisabled = self.disableIdleTimer;
            break;
        }
    }
}

- (BOOL)inputViewIsFirstResponder {
    return NO;
}

- (void)updateKeyboardAccessoryFrame {
}

#pragma mark - Termination

// from: https://stackoverflow.com/a/17802404/4236245
- (void)terminateApplication {
    dispatch_async(dispatch_get_main_queue(), ^{
        // animate to home screen
        UIApplication *app = [UIApplication sharedApplication];
        [app performSelector:@selector(suspend)];

        // wait 2 seconds while app is going background
        [NSThread sleepForTimeInterval:2.0];

        // exit app when app is in background
        exit(0);
    });
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
    if (![self boolForSetting:@"HasShownHideToolbarAlert"]) {
        [self showAlert:NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"VMDisplayViewController") actions:nil completion:^(UIAlertAction *action){
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasShownHideToolbarAlert"];
        }];
    }
}

- (void)showToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = NO;
        if (!self.largeScreen) {
            self.prefersStatusBarHidden = NO;
        }
    } completion:nil];
}

- (void)setToolbarVisible:(BOOL)toolbarVisible {
    if (toolbarVisible) {
        [self showToolbar];
    } else {
        [self hideToolbar];
    }
    _toolbarVisible = toolbarVisible;
}

- (IBAction)changeDisplayZoom:(UIButton *)sender {
    
}

- (IBAction)pauseResumePressed:(UIButton *)sender {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        if (self.vm.state == kVMStarted) {
            [self.vm pauseVM];
            if (![self.vm saveVM]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlert:NSLocalizedString(@"Failed to save VM state. Do you have at least one read-write drive attached that supports snapshots?", @"VMDisplayViewController") actions:nil completion:nil];
                });
            }
        } else if (self.vm.state == kVMPaused) {
            [self.vm resumeVM];
        }
    });
}

- (IBAction)powerPressed:(UIButton *)sender {
    if (self.vm.state == kVMStarted) {
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                [self.vm quitVM];
                [self terminateApplication];
            });
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to stop this VM and exit? Any unsaved changes will be lost.", @"VMDisplayViewController")
                actions:@[yes, no]
             completion:nil];
    } else {
        UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            [self terminateApplication];
        }];
        UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayViewController") style:UIAlertActionStyleCancel handler:nil];
        [self showAlert:NSLocalizedString(@"Are you sure you want to exit UTM?.", @"VMDisplayViewController")
                actions:@[yes, no]
             completion:nil];
    }
}

- (IBAction)restartPressed:(UIButton *)sender {
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMDisplayViewController") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm resetVM];
        });
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMDisplayViewController") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to reset this VM? Any unsaved changes will be lost.", @"VMDisplayViewController")
            actions:@[yes, no]
         completion:nil];
}

- (IBAction)showKeyboardButton:(UIButton *)sender {
    self.keyboardVisible = !self.keyboardVisible;
}

- (IBAction)usbPressed:(UIButton *)sender {
#if !defined(WITH_QEMU_TCI)
    self.usbDevicesViewController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:self.usbDevicesViewController animated:YES completion:nil];
#endif
}

- (IBAction)drivesPressed:(UIButton *)sender {
    self.removableDrivesViewController.modalPresentationStyle = UIModalPresentationPageSheet;
    self.removableDrivesViewController.vm = self.vm;
    [self presentViewController:self.removableDrivesViewController animated:YES completion:nil];
}

- (IBAction)hideToolbarButton:(UIButton *)sender {
    self.toolbarVisible = NO;
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"editVMConfig"]){
#if 0 // deprecated, will remove in future
        NSAssert([segue.destinationViewController isKindOfClass:[UINavigationController class]], @"Destination not a navigation view");
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        NSAssert([navController.topViewController isKindOfClass:[VMConfigExistingViewController class]], @"Invalid segue destination");
        VMConfigExistingViewController *controller = (VMConfigExistingViewController *)navController.topViewController;
        controller.configuration = self.vmConfiguration;
        controller.nameReadOnly = YES;
#endif
    }
}

#pragma mark - Notification Handling

- (void)handleEnteredBackground:(NSNotification *)notification {
    UTMLog(@"Entering background");
    if (self.autosaveBackground && self.vm.state == kVMStarted) {
        UTMLog(@"Saving snapshot");
        __block UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            UTMLog(@"Background task end");
            [[UIApplication sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [self.vm saveVM];
            self->_hasAutoSave = YES;
            UTMLog(@"Save snapshot complete");
            [[UIApplication sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        });
    }
}

- (void)handleEnteredForeground:(NSNotification *)notification {
    UTMLog(@"Entering foreground!");
    if (_hasAutoSave && self.vm.state == kVMStarted) {
        UTMLog(@"Deleting snapshot");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm deleteSaveVM];
        });
    }
}

- (void)didReceiveMemoryWarning {
    static BOOL memoryAlertOnce = NO;
    
    [super didReceiveMemoryWarning];
    
    if (self.autosaveLowMemory) {
        UTMLog(@"Saving VM state on low memory warning.");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self.vm saveVM];
        });
    }
    
    if (!memoryAlertOnce) {
        memoryAlertOnce = YES;
        [self showAlert:NSLocalizedString(@"Running low on memory! UTM might soon be killed by iOS. You can prevent this by decreasing the amount of memory and/or JIT cache assigned to this VM", @"VMDisplayViewController")
                actions:nil
             completion:nil];
    }
}

- (void)keyboardDidShow:(NSNotification *)notification {
    _keyboardVisible = YES;
}

- (void)keyboardDidHide:(NSNotification *)notification {
    _keyboardVisible = [self inputViewIsFirstResponder]; // workaround for notification when hw keyboard connected
}

- (void)keyboardDidChangeFrame:(NSNotification *)notification {
    [self updateKeyboardAccessoryFrame];
}

- (void)importUTM:(NSNotification *)notification {
    [self showAlert:NSLocalizedString(@"You must terminate the running VM before you can import a new VM.", @"VMDisplayViewController") actions:nil completion:nil];
}

@end
