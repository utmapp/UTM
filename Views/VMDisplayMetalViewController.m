//
// Copyright © 2019 Halts. All rights reserved.
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
#import "UTMRenderer.h"
#import "UTMVirtualMachine.h"
#import "VMKeyboardView.h"
#import "CSInput.h"

@interface VMDisplayMetalViewController ()

@end

@implementation VMDisplayMetalViewController {
    UTMRenderer *_renderer;
    CGPoint _lastTwoPanOrigin;
    CGPoint _lastCursor;
    CGFloat _keyboardViewHeight;
    
    // status bar
    BOOL _prefersStatusBarHidden;
    
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
    UIPanGestureRecognizer *_pan;
    UIPanGestureRecognizer *_twoPan;
    UITapGestureRecognizer *_tap;
    UITapGestureRecognizer *_twoTap;
    UIPinchGestureRecognizer *_pinch;
}

@synthesize vmScreenshot;
@synthesize vmMessage;
@synthesize vmRendering;

- (BOOL)prefersStatusBarHidden {
    return _prefersStatusBarHidden;
}

- (void)setPrefersStatusBarHidden:(BOOL)prefersStatusBarHidden {
    _prefersStatusBarHidden = prefersStatusBarHidden;
    [self setNeedsStatusBarAppearanceUpdate];
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
    _renderer.source = self.vmRendering;
    
    self.mtkView.delegate = _renderer;
    
    // Setup keyboard accessory
    self.keyboardView.inputAccessoryView = self.inputAccessoryView;
    
    // Set up gesture recognizers because Storyboards is BROKEN and doing it there crashes!
    _swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeUp:)];
    _swipeUp.numberOfTouchesRequired = 3;
    _swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeUp.delegate = self;
    _swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeDown:)];
    _swipeDown.numberOfTouchesRequired = 3;
    _swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeDown.delegate = self;
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePan:)];
    _pan.minimumNumberOfTouches = 1;
    _pan.maximumNumberOfTouches = 1;
    _pan.delegate = self;
    _twoPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoPan:)];
    _twoPan.minimumNumberOfTouches = 2;
    _twoPan.maximumNumberOfTouches = 2;
    _twoPan.delegate = self;
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    _tap.delegate = self;
    _twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoTap:)];
    _twoTap.numberOfTouchesRequired = 2;
    _twoTap.delegate = self;
    _pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    _pinch.delegate = self;
    [self.view addGestureRecognizer:_swipeUp];
    [self.view addGestureRecognizer:_swipeDown];
    [self.view addGestureRecognizer:_pan];
    [self.view addGestureRecognizer:_twoPan];
    [self.view addGestureRecognizer:_tap];
    [self.view addGestureRecognizer:_twoTap];
    [self.view addGestureRecognizer:_pinch];
    
    // Feedback generator for clicks
    self.clickFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    self.resizeFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    switch (state) {
        case kVMError: {
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"Alert message");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okay];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:alert animated:YES completion:^{
                    [self performSegueWithIdentifier:@"returnToList" sender:self];
                }];
            });
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
        case kVMStarted: {
            _renderer.source = self.vmRendering;
            break;
        }
        default: {
            break; // TODO: Implement
        }
    }
}

#pragma mark - Converting view points to VM display points

static CGRect CGRectClipToBounds(CGRect rect1, CGRect rect2) {
    if (rect2.origin.x < rect1.origin.x) {
        rect2.origin.x = rect1.origin.x;
    } else if (rect2.origin.x + rect2.size.width > rect1.origin.x + rect1.size.width) {
        rect2.origin.x = rect1.origin.x + rect1.size.width - rect2.size.width;
    }
    if (rect2.origin.y < rect1.origin.y) {
        rect2.origin.y = rect1.origin.y;
    } else if (rect2.origin.y + rect2.size.height > rect1.origin.y + rect1.size.height) {
        rect2.origin.y = rect1.origin.y + rect1.size.height - rect2.size.height;
    }
    return rect2;
}

static CGFloat CGPointToPixel(CGFloat point) {
    return point * [UIScreen mainScreen].scale; // FIXME: multiple screens?
}

- (CGPoint)clipCursorToDisplay:(CGPoint)pos {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmRendering.displaySize.width * _renderer.viewportScale,
        self.vmRendering.displaySize.height * _renderer.viewportScale
    };
    CGRect drawRect = CGRectMake(
        _renderer.viewportOrigin.x + screenSize.width/2 - scaledSize.width/2,
        _renderer.viewportOrigin.y + screenSize.height/2 - scaledSize.height/2,
        scaledSize.width,
        scaledSize.height
    );
    pos.x -= drawRect.origin.x;
    pos.y -= drawRect.origin.y;
    if (pos.x < 0) {
        pos.x = 0;
    } else if (pos.x > scaledSize.width) {
        pos.x = scaledSize.width;
    }
    if (pos.y < 0) {
        pos.y = 0;
    } else if (pos.y > scaledSize.height) {
        pos.y = scaledSize.height;
    }
    pos.x /= _renderer.viewportScale;
    pos.y /= _renderer.viewportScale;
    return pos;
}

- (CGPoint)clipDisplayToView:(CGPoint)target {
    CGSize screenSize = self.mtkView.drawableSize;
    CGSize scaledSize = {
        self.vmRendering.displaySize.width * _renderer.viewportScale,
        self.vmRendering.displaySize.height * _renderer.viewportScale
    };
    CGRect drawRect = CGRectMake(
        target.x + screenSize.width/2 - scaledSize.width/2,
        target.y + screenSize.height/2 - scaledSize.height/2,
        scaledSize.width,
        scaledSize.height
    );
    CGRect boundRect = {
        {
            screenSize.width - MAX(screenSize.width, scaledSize.width),
            screenSize.height - MAX(screenSize.height, scaledSize.height)
            
        },
        {
            2*MAX(screenSize.width, scaledSize.width) - screenSize.width,
            2*MAX(screenSize.height, scaledSize.height) - screenSize.height
        }
    };
    CGRect clippedRect = CGRectClipToBounds(boundRect, drawRect);
    clippedRect.origin.x -= (screenSize.width/2 - scaledSize.width/2);
    clippedRect.origin.y -= (screenSize.height/2 - scaledSize.height/2);
    return CGPointMake(clippedRect.origin.x, clippedRect.origin.y);
}

#pragma mark - Gestures

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender {
    if (self.vm.primaryInput.serverModeCursor) {
        CGPoint translation = [sender translationInView:sender.view];
        if (sender.state == UIGestureRecognizerStateBegan) {
            _lastCursor = translation;
        }
        if (sender.state != UIGestureRecognizerStateCancelled) {
            CGPoint cursor;
            cursor.x = CGPointToPixel(translation.x - _lastCursor.x) / _renderer.viewportScale;
            cursor.y = CGPointToPixel(translation.y - _lastCursor.y) / _renderer.viewportScale;
            _lastCursor = translation;
            [self.vm.primaryInput sendMouseMotion:SEND_BUTTON_NONE point:cursor];
        }
        if (sender.state == UIGestureRecognizerStateEnded) {
            // TODO: decelerate
        }
    }
}

- (IBAction)gestureTwoPan:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        _lastTwoPanOrigin = _renderer.viewportOrigin;
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        CGPoint translation = [sender translationInView:sender.view];
        CGPoint viewport = _renderer.viewportOrigin;
        viewport.x = CGPointToPixel(translation.x) + _lastTwoPanOrigin.x;
        viewport.y = CGPointToPixel(translation.y) + _lastTwoPanOrigin.y;
        _renderer.viewportOrigin = [self clipDisplayToView:viewport];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        // TODO: decelerate
    }
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint translated = [sender locationInView:sender.view];
        translated.x = CGPointToPixel(translated.x);
        translated.y = CGPointToPixel(translated.y);
        translated = [self clipCursorToDisplay:translated];
        if (self.vm.primaryInput.serverModeCursor) {
            translated = _lastCursor;
        }
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_LEFT pressed:YES point:translated];
        [self.clickFeedbackGenerator selectionChanged];
    }
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint translated = [sender locationInView:sender.view];
        translated.x = CGPointToPixel(translated.x);
        translated.y = CGPointToPixel(translated.y);
        translated = [self clipCursorToDisplay:translated];
        if (self.vm.primaryInput.serverModeCursor) {
            translated = _lastCursor;
        }
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_RIGHT pressed:YES point:translated];
        [self.clickFeedbackGenerator selectionChanged];
    }
}

- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender {
    _renderer.viewportScale *= sender.scale;
    sender.scale = 1.0;
}

- (IBAction)gestureSwipeUp:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (!self.toolbarAccessoryView.hidden) {
            [self hideToolbar];
        } else if (!self.keyboardView.isFirstResponder) {
            [self.keyboardView becomeFirstResponder];
        }
    }
}

- (IBAction)gestureSwipeDown:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.keyboardView.isFirstResponder) {
            [self.keyboardView resignFirstResponder];
        } else if (self.toolbarAccessoryView.hidden) {
            [self showToolbar];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _twoTap && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _twoTap && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _tap && otherGestureRecognizer == _twoTap) {
        return YES;
    }
    if (gestureRecognizer == _pinch && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    if (gestureRecognizer == _pinch && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _pan && otherGestureRecognizer == _swipeUp) {
        return YES;
    }
    if (gestureRecognizer == _pan && otherGestureRecognizer == _swipeDown) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _pinch) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    _keyboardViewHeight = keyboardSize.height;
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = self.view.frame;
        f.origin.y = -self->_keyboardViewHeight;
        self.view.frame = f;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = self.view.frame;
        f.origin.y = 0.0f;
        self->_keyboardViewHeight = 0;
        self.view.frame = f;
    }];
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyDown:(int)scancode {
    [self.vm.primaryInput sendKey:SEND_KEY_PRESS code:scancode];
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyUp:(int)scancode {
    [self.vm.primaryInput sendKey:SEND_KEY_RELEASE code:scancode];
}

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    [self.keyboardView resignFirstResponder];
}

#pragma mark - Toolbar actions

- (void)hideToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = YES;
        self.prefersStatusBarHidden = YES;
    } completion:nil];
}

- (void)showToolbar {
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.toolbarAccessoryView.hidden = NO;
        self.prefersStatusBarHidden = NO;
    } completion:nil];
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
    CGSize displaySize = self.vmRendering.displaySize;
    CGSize scaled = CGSizeMake(viewSize.width / displaySize.width, viewSize.height / displaySize.height);
    _renderer.viewportScale = MIN(scaled.width, scaled.height);
    _renderer.viewportOrigin = CGPointMake(0, _keyboardViewHeight);
}

- (void)resetDisplay {
    _renderer.viewportScale = 1.0;
    _renderer.viewportOrigin = CGPointMake(0, _keyboardViewHeight);
}

- (IBAction)changeDisplayZoom:(UIButton *)sender {
    if (self.lastDisplayChangeResize) {
        [self resetDisplay];
    } else {
        [self resizeDisplayToFit];
    }
    self.lastDisplayChangeResize = !self.lastDisplayChangeResize;
}

- (IBAction)touchResumePressed:(UIButton *)sender {
}

- (IBAction)powerPressed:(UIButton *)sender {
}

- (IBAction)showKeyboardButton:(UIButton *)sender {
    if (self.keyboardView.isFirstResponder) {
        [self.keyboardView resignFirstResponder];
    } else {
        [self.keyboardView becomeFirstResponder];
    }
}

- (IBAction)hideToolbarButton:(UIButton *)sender {
    [self hideToolbar];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownHideToolbarAlert"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"Shown once when hiding toolbar.") preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okay];
        [self presentViewController:alert animated:YES completion:^{
            [defaults setBool:YES forKey:@"HasShownHideToolbarAlert"];
        }];
    }
}

@end
