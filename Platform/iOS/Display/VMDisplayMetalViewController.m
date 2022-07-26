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
#import "UTMQemuManager.h"
#import "UTMLogging.h"
#import "CSDisplay.h"
#import "UTM-Swift.h"
@import CocoaSpiceRenderer;

@implementation VMDisplayMetalViewController {
    CSRenderer *_renderer;
}

- (instancetype)initWithDisplay:(CSDisplay *)display input:(CSInput *)input {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.vmDisplay = display;
        self.vmInput = input;
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
    UINib *nib = [UINib nibWithNibName:@"VMDisplayView" bundle:nil];
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
    self.mtkView.device = MTLCreateSystemDefaultDevice();
    if (!self.mtkView.device) {
        UTMLog(@"Metal is not supported on this device");
        return;
    }
    
    _renderer = [[CSRenderer alloc] initWithMetalKitView:self.mtkView];
    if (!_renderer) {
        UTMLog(@"Renderer failed initialization");
        return;
    }
    
    // Initialize our renderer with the view size
    [_renderer mtkView:self.mtkView drawableSizeWillChange:self.mtkView.drawableSize];
    
    [_renderer changeUpscaler:self.delegate.qemuDisplayUpscaler
                   downscaler:self.delegate.qemuDisplayDownscaler];
    
    self.mtkView.delegate = _renderer;
    self.vmDisplay = self.vmDisplay; // reset renderer
    
    [self initTouch];
    [self initGamepad];
    [self initGCMouse];
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
    self.prefersStatusBarHidden = YES;
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
    if (!busy) {
        if (self.delegate.qemuHasClipboardSharing) {
            [[UTMPasteboard generalPasteboard] releasePollingModeForObject:self];
        }
    }
}

- (void)enterLive {
    [super enterLive];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.delegate.displayViewSize = self.mtkView.drawableSize;
    });
    if (self.delegate.qemuDisplayIsDynamicResolution) {
        [self displayResize:self.view.bounds.size];
    }
    if (self.delegate.qemuHasClipboardSharing) {
        [[UTMPasteboard generalPasteboard] requestPollingModeForObject:self];
    }
}

#pragma mark - Key handling

- (void)showKeyboard {
    [self.keyboardView becomeFirstResponder];
}

- (void)hideKeyboard {
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

#pragma mark - Toolbar actions

- (void)resizeDisplayToFit {
    CGSize viewSize = self.mtkView.drawableSize;
    CGSize displaySize = self.vmDisplay.displaySize;
    CGSize scaled = CGSizeMake(viewSize.width / displaySize.width, viewSize.height / displaySize.height);
    self.vmDisplay.viewportScale = MIN(scaled.width, scaled.height);
    self.vmDisplay.viewportOrigin = CGPointMake(0, 0);
    // persist this change in viewState
    self.delegate.displayScale = self.vmDisplay.viewportScale;
    self.delegate.displayOriginX = 0;
    self.delegate.displayOriginY = 0;
}

- (void)resetDisplay {
    self.vmDisplay.viewportScale = 1.0;
    self.vmDisplay.viewportOrigin = CGPointMake(0, 0);
    // persist this change in viewState
    self.delegate.displayScale = 1.0;
    self.delegate.displayOriginX = 0;
    self.delegate.displayOriginY = 0;
}

#pragma mark - Resizing

- (void)displayResize:(CGSize)size {
    UTMLog(@"resizing to (%f, %f)", size.width, size.height);
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    if (self.delegate.qemuDisplayIsNativeResolution) {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
        bounds = CGRectApplyAffineTransform(bounds, transform);
    }
    [self.vmDisplay requestResolution:bounds];
}

- (void)setVmDisplay:(CSDisplay *)display {
    _vmDisplay = display;
    _renderer.source = display;
    // restore last size
    CGPoint displayOrigin = CGPointMake(self.delegate.displayOriginX, self.delegate.displayOriginY);
    display.viewportOrigin = displayOrigin;
    double displayScale = self.delegate.displayScale;
    if (displayScale) { // cannot be zero
        display.viewportScale = displayScale;
    }
}

@end
