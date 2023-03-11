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
#import "VMDisplayMetalViewController+Pencil.h"
#import "VMDisplayMetalViewController+Gamepad.h"
#import "VMKeyboardView.h"
#import "UTMVirtualMachine.h"
#import "UTMLogging.h"
#import "CSDisplay.h"
#import "UTM-Swift.h"
@import CocoaSpiceRenderer;

@interface VMDisplayMetalViewController ()

@property (nonatomic, nullable) CSMetalRenderer *renderer;

@end

@implementation VMDisplayMetalViewController

- (instancetype)initWithDisplay:(CSDisplay *)display input:(CSInput *)input {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.vmDisplay = display;
        self.vmInput = input;
        [self addObserver:self forKeyPath:@"vmDisplay.displaySize" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    self.keyboardView = [[VMKeyboardView alloc] initWithFrame:CGRectZero];
    self.mtkView = [[MTKView alloc] initWithFrame:CGRectZero];
    self.keyboardView.delegate = self;
    [self.view insertSubview:self.keyboardView atIndex:0];
    [self.view insertSubview:self.mtkView atIndex:1];
    [self.mtkView bindFrameToSuperviewBounds];
    [self loadInputAccessory];
}

- (void)loadInputAccessory {
    UINib *nib = [UINib nibWithNibName:@"VMDisplayMetalViewInputAccessory" bundle:nil];
    [nib instantiateWithOwner:self options:nil];
}

- (BOOL)serverModeCursor {
    return self.vmInput.serverModeCursor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // set up software keyboard
    self.keyboardView.inputAccessoryView = self.inputAccessoryView;
    
    // Set the view to use the default device
    self.mtkView.frame = self.view.bounds;
    self.mtkView.device = MTLCreateSystemDefaultDevice();
    if (!self.mtkView.device) {
        UTMLog(@"Metal is not supported on this device");
        return;
    }
    
    self.renderer = [[CSMetalRenderer alloc] initWithMetalKitView:self.mtkView];
    if (!self.renderer) {
        UTMLog(@"Renderer failed initialization");
        return;
    }
    
    // Initialize our renderer with the view size
    CGSize drawableSize = self.view.bounds.size;
    self.mtkView.drawableSize = drawableSize;
    if ([self integerForSetting:@"QEMURendererFPSLimit"] > 0) {
        self.mtkView.preferredFramesPerSecond = [self integerForSetting:@"QEMURendererFPSLimit"];
    }
    
    [self.renderer changeUpscaler:self.delegate.qemuDisplayUpscaler
                       downscaler:self.delegate.qemuDisplayDownscaler];
    
    self.mtkView.delegate = self.renderer;
    
    [self initTouch];
    [self initGamepad];
    // Pointing device support on iPadOS 13.4 GM or later
    if (@available(iOS 13.4, *)) {
        // Betas of iPadOS 13.4 did not include this API, that's why I check if the class exists
        if (NSClassFromString(@"UIPointerInteraction") != nil) {
            [self initPointerInteraction];
        }
    }
    // Apple Pencil 2 double tap support on iOS 12.1+
    if (@available(iOS 12.1, *)) {
        [self initPencilInteraction];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.prefersHomeIndicatorAutoHidden = YES;
    [self startGCMouse];
    [self.vmDisplay addRenderer:self.renderer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopGCMouse];
    [self.vmDisplay removeRenderer:self.renderer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.delegate.displayViewSize = self.mtkView.drawableSize;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.delegate.displayViewSize = self.mtkView.drawableSize;
    }];
    if (self.delegate.qemuDisplayIsDynamicResolution) {
        [self displayResize:size];
    }
}

- (void)enterSuspendedWithIsBusy:(BOOL)busy {
    [super enterSuspendedWithIsBusy:busy];
    self.prefersPointerLocked = NO;
    if (!busy) {
        if (self.delegate.qemuHasClipboardSharing) {
            [[UTMPasteboard generalPasteboard] releasePollingModeForObject:self];
        }
    }
}

- (void)enterLive {
    [super enterLive];
    self.prefersPointerLocked = YES;
    if (self.delegate.qemuDisplayIsDynamicResolution) {
        [self displayResize:self.view.bounds.size];
    }
    if (self.delegate.qemuHasClipboardSharing) {
        [[UTMPasteboard generalPasteboard] requestPollingModeForObject:self];
    }
}

#pragma mark - Key handling

- (void)showKeyboard {
    [super showKeyboard];
    [self.keyboardView becomeFirstResponder];
}

- (void)hideKeyboard {
    [super hideKeyboard];
    [self.keyboardView resignFirstResponder];
}

- (void)sendExtendedKey:(CSInputKey)type code:(int)code {
    if ((code & 0xFF00) == 0xE000) {
        code = 0x100 | (code & 0xFF);
    } else if (code >= 0x100) {
        UTMLog(@"warning: ignored invalid keycode 0x%x", code);
    }
    [self.vmInput sendKey:type code:code];
}

#pragma mark - Resizing

- (void)displayResize:(CGSize)size {
    UTMLog(@"resizing to (%f, %f)", size.width, size.height);
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    if (self.delegate.qemuDisplayIsNativeResolution) {
        UIScreen *screen = self.view.window.screen;
        if (screen == nil) {
            screen = UIScreen.mainScreen;
        }
        CGFloat scale = screen.scale;
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
        bounds = CGRectApplyAffineTransform(bounds, transform);
    }
    [self.vmDisplay requestResolution:bounds];
}

- (void)setVmDisplay:(CSDisplay *)display {
    if (self.renderer) {
        [_vmDisplay removeRenderer:self.renderer];
        _vmDisplay = display;
        [display addRenderer:self.renderer];
    }
}

- (void)setDisplayScaling:(CGFloat)scaling origin:(CGPoint)origin {
    self.vmDisplay.viewportOrigin = origin;
    if (scaling) { // cannot be zero
        self.vmDisplay.viewportScale = scaling;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"vmDisplay.displaySize"]) {
        [self.delegate display:self.vmDisplay didResizeTo:self.vmDisplay.displaySize];
    }
}

@end
