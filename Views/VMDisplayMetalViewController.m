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
#import "UTMRenderer.h"
#import "UTMVirtualMachine.h"
#import "VMKeyboardView.h"
#import "UTMQemuManager.h"
#import "VMConfigExistingViewController.h"
#import "VMKeyboardButton.h"
#import "UIViewController+Extensions.h"
#import "UTMConfiguration.h"
#import "VMCursor.h"

@interface VMDisplayMetalViewController ()

@property (nonatomic, strong) UTMVirtualMachine *vm;

@end

@implementation VMDisplayMetalViewController {
    UTMRenderer *_renderer;
    CGPoint _lastTwoPanOrigin;
    BOOL _mouseDown;
    
    // cursor handling
    UIDynamicAnimator *_animator;
    VMCursor *_cursor;
    
    // status bar
    BOOL _prefersStatusBarHidden;
    
    // gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
    UISwipeGestureRecognizer *_swipeScrollUp;
    UISwipeGestureRecognizer *_swipeScrollDown;
    UIPanGestureRecognizer *_pan;
    UIPanGestureRecognizer *_twoPan;
    UITapGestureRecognizer *_tap;
    UITapGestureRecognizer *_twoTap;
    UILongPressGestureRecognizer *_longPress;
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

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES; // always hide home indicator
}

- (BOOL)serverModeCursor {
    return self.vm.primaryInput.serverModeCursor;
}

- (BOOL)touchscreen {
    return self.vm.configuration.inputTouchscreenMode;
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
    
    // mouse cursor
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    _cursor = [[VMCursor alloc] initWithVMViewController:self];
    
    // Set up gesture recognizers because Storyboards is BROKEN and doing it there crashes!
    _swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeUp:)];
    _swipeUp.numberOfTouchesRequired = 3;
    _swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeUp.delegate = self;
    _swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeDown:)];
    _swipeDown.numberOfTouchesRequired = 3;
    _swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeDown.delegate = self;
    _swipeScrollUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    _swipeScrollUp.numberOfTouchesRequired = 2;
    _swipeScrollUp.direction = UISwipeGestureRecognizerDirectionUp;
    _swipeScrollUp.delegate = self;
    _swipeScrollDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(gestureSwipeScroll:)];
    _swipeScrollDown.numberOfTouchesRequired = 2;
    _swipeScrollDown.direction = UISwipeGestureRecognizerDirectionDown;
    _swipeScrollDown.delegate = self;
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
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(gestureLongPress:)];
    _longPress.delegate = self;
    _pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(gesturePinch:)];
    _pinch.delegate = self;
    [self.mtkView addGestureRecognizer:_swipeUp];
    [self.mtkView addGestureRecognizer:_swipeDown];
    [self.mtkView addGestureRecognizer:_swipeScrollUp];
    [self.mtkView addGestureRecognizer:_swipeScrollDown];
    [self.mtkView addGestureRecognizer:_pan];
    [self.mtkView addGestureRecognizer:_twoPan];
    [self.mtkView addGestureRecognizer:_tap];
    [self.mtkView addGestureRecognizer:_twoTap];
    [self.mtkView addGestureRecognizer:_longPress];
    [self.mtkView addGestureRecognizer:_pinch];
    
    // Feedback generator for clicks
    self.clickFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    self.resizeFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

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
        case kVMStarted: {
            _renderer.source = self.vmRendering;
            break;
        }
        default: {
            break; // TODO: Implement
        }
    }
}

- (void)changeVM:(UTMVirtualMachine *)vm {
    self.vm = vm;
}

- (void)sendExtendedKey:(SendKeyType)type code:(int)code {
    uint32_t x = __builtin_bswap32(code);
    while ((x & 0xFF) == 0) {
        x = x >> 8;
    }
    while (x) {
        [self.vm.primaryInput sendKey:type code:(x & 0xFF)];
        x = x >> 8;
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
    CGPoint location = [sender locationInView:sender.view];
    CGPoint velocity = [sender velocityInView:sender.view];
    if (sender.state == UIGestureRecognizerStateBegan) {
        [_cursor startMovement:location];
        [_animator removeAllBehaviors];
    }
    if (sender.state != UIGestureRecognizerStateCancelled) {
        [_cursor updateMovement:location];
    }
    if (sender.state == UIGestureRecognizerStateEnded) {
        UIDynamicItemBehavior *behavior = [[UIDynamicItemBehavior alloc] initWithItems:@[ _cursor ]];
        [behavior addLinearVelocity:velocity forItem:_cursor];
        behavior.resistance = 50;
        [_animator addBehavior:behavior];
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

- (CGPoint)moveMouseAbsolute:(CGPoint)location {
    CGPoint translated = location;
    translated.x = CGPointToPixel(translated.x);
    translated.y = CGPointToPixel(translated.y);
    translated = [self clipCursorToDisplay:translated];
    if (!self.vm.primaryInput.serverModeCursor) {
        [self.vm.primaryInput sendMouseMotion:SEND_BUTTON_NONE point:translated];
    } else {
        NSLog(@"Warning: ignored mouse set (%f, %f) while mouse is in server mode", translated.x, translated.y);
    }
    return translated;
}

- (CGPoint)moveMouseRelative:(CGPoint)translation {
    translation.x = CGPointToPixel(translation.x) / _renderer.viewportScale;
    translation.y = CGPointToPixel(translation.y) / _renderer.viewportScale;
    if (self.vm.primaryInput.serverModeCursor) {
        [self.vm.primaryInput sendMouseMotion:SEND_BUTTON_NONE point:translation];
    } else {
        NSLog(@"Warning: ignored mouse motion (%f, %f) while mouse is in client mode", translation.x, translation.y);
    }
    return translation;
}

- (IBAction)gestureTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint translated = CGPointZero;
        if (self.touchscreen) {
            _cursor.center = [sender locationInView:sender.view];
        }
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_LEFT pressed:YES point:translated];
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_LEFT pressed:NO point:translated];
        [self.clickFeedbackGenerator selectionChanged];
    }
}

- (IBAction)gestureTwoTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint translated = CGPointZero;
        if (self.touchscreen) {
            _cursor.center = [sender locationInView:sender.view];
        }
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_RIGHT pressed:YES point:translated];
        [self.vm.primaryInput sendMouseButton:SEND_BUTTON_RIGHT pressed:NO point:translated];
        [self.clickFeedbackGenerator selectionChanged];
    }
}

- (IBAction)gestureLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.clickFeedbackGenerator selectionChanged];
        _mouseDown = YES;
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        _mouseDown = NO;
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

- (IBAction)gestureSwipeScroll:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (sender == _swipeScrollUp) {
            [self.vm.primaryInput sendMouseScroll:SEND_SCROLL_UP button:SEND_BUTTON_NONE dy:0];
        } else if (sender == _swipeScrollDown) {
            [self.vm.primaryInput sendMouseScroll:SEND_SCROLL_DOWN button:SEND_BUTTON_NONE dy:0];
        } else {
            NSAssert(0, @"Invalid call to gestureSwipeScroll");
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
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeScrollUp) {
        return YES;
    }
    if (gestureRecognizer == _twoPan && otherGestureRecognizer == _swipeScrollDown) {
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
    if (gestureRecognizer == _longPress && otherGestureRecognizer == _tap) {
        return YES;
    }
    if (gestureRecognizer == _longPress && otherGestureRecognizer == _twoTap) {
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
    } else if (gestureRecognizer == _pan && otherGestureRecognizer == _longPress) {
        return YES;
    } else {
        return NO;
    }
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
    _renderer.viewportOrigin = CGPointMake(0, 0);
}

- (void)resetDisplay {
    _renderer.viewportScale = 1.0;
    _renderer.viewportOrigin = CGPointMake(0, 0);
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
        [self showAlert:NSLocalizedString(@"Hint: To show the toolbar again, use a three-finger swipe down on the screen.", @"Shown once when hiding toolbar.") completion:^(UIAlertAction *action){
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
        controller.configuration = self.vm.configuration;
        controller.nameReadOnly = YES;
}
}

#pragma mark - Memory warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self showAlert:NSLocalizedString(@"Running low on memory! UTM might soon be killed by iOS. You can prevent this by decreasing the amount of memory and/or JIT cache assigned to this VM", @"Low memory warning") completion:nil];
}

@end
