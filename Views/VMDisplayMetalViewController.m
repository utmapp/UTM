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
}

@synthesize vmScreenshot;
@synthesize vmMessage;
@synthesize vmRendering;

- (BOOL)prefersStatusBarHidden {
    return YES;
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
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeUp:)];
    swipeUp.numberOfTouchesRequired = 3;
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeDown:)];
    swipeDown.numberOfTouchesRequired = 3;
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePan:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    UIPanGestureRecognizer *twoPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoPan:)];
    twoPan.minimumNumberOfTouches = 2;
    twoPan.maximumNumberOfTouches = 2;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTwoTap:)];
    twoTap.numberOfTouchesRequired = 2;
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    [self.view addGestureRecognizer:swipeUp];
    [self.view addGestureRecognizer:swipeDown];
    [self.view addGestureRecognizer:pan];
    [self.view addGestureRecognizer:twoPan];
    [self.view addGestureRecognizer:tap];
    [self.view addGestureRecognizer:twoTap];
    [self.view addGestureRecognizer:pinch];
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

#pragma mark - Helpers

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

- (CGPoint)clipPan:(CGPoint)target {
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

- (CGPoint)translateToDisplay:(CGPoint)pos {
    return pos;
}

#pragma mark - Gestures

- (IBAction)gesturePan:(UIPanGestureRecognizer *)sender {
    if (self.vm.primaryInput.serverModeCursor) {
        
    }
}

- (IBAction)gestureTwoPan:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        _lastTwoPanOrigin = _renderer.viewportOrigin;
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        CGPoint translation = [sender translationInView:sender.view];
        CGPoint viewport = _renderer.viewportOrigin;
        viewport.x = 2*translation.x + _lastTwoPanOrigin.x;
        viewport.y = 2*translation.y + _lastTwoPanOrigin.y;
        _renderer.viewportOrigin = [self clipPan:viewport];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        // TODO: decelerate
    }
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    
}

- (IBAction)gesturePinch:(UIPinchGestureRecognizer *)sender {
    _renderer.viewportScale *= sender.scale;
    sender.scale = 1.0;
}

- (IBAction)gestureSwipeUp:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.keyboardView becomeFirstResponder];
    }
}

- (IBAction)gestureSwipeDown:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.keyboardView resignFirstResponder];
    }
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = self.view.frame;
        f.origin.y = -keyboardSize.height;
        self.view.frame = f;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = self.view.frame;
        f.origin.y = 0.0f;
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

@end
