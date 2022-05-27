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
#import "UTMQemuConfiguration.h"
#import "UTMQemuConfiguration+Display.h"
#import "UTMLogging.h"
#import "CSDisplay.h"
#import "UTM-Swift.h"
@import CocoaSpiceRenderer;

@implementation VMDisplayMetalViewController {
    CSRenderer *_renderer;
}

- (void)setupSubviews {
    self.vm.delegate = self;
    self.keyboardView = [[VMKeyboardView alloc] initWithFrame:CGRectZero];
    self.placeholderImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.mtkView = [[MTKView alloc] initWithFrame:CGRectZero];
    self.keyboardView.delegate = self;
    [self.view insertSubview:self.keyboardView atIndex:0];
    [self.view insertSubview:self.placeholderImageView atIndex:1];
    [self.placeholderImageView bindFrameToSuperviewBounds];
    [self.view insertSubview:self.mtkView atIndex:2];
    [self.mtkView bindFrameToSuperviewBounds];
    [self createToolbarIn:self.mtkView];
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
    
    [_renderer changeUpscaler:self.vmQemuConfig.displayUpscalerValue
                   downscaler:self.vmQemuConfig.displayDownscalerValue];
    
    self.mtkView.delegate = _renderer;
    
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
    if (!self.toolbar.hasLegacyToolbar) {
        self.prefersStatusBarHidden = YES;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (self.vmQemuConfig.displayFitScreen) {
        [self displayResize:size];
    }
}

- (void)enterSuspendedWithIsBusy:(BOOL)busy {
    [super enterSuspendedWithIsBusy:busy];
    if (!busy) {
        [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self.placeholderImageView.hidden = NO;
            self.placeholderImageView.image = self.vm.screenshot.image;
            self.mtkView.hidden = YES;
        } completion:nil];
        if (self.vmQemuConfig.shareClipboardEnabled) {
            [[UTMPasteboard generalPasteboard] releasePollingModeForObject:self];
        }
#if !defined(WITH_QEMU_TCI)
        if (self.vm.state == kVMStopped) {
            [self.usbDevicesViewController clearDevices];
        }
#endif
    }
}

- (void)enterLive {
    [super enterLive];
    [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.placeholderImageView.hidden = YES;
        self.mtkView.hidden = NO;
    } completion:nil];
    if (self.vmQemuConfig.displayFitScreen) {
        [self displayResize:self.view.bounds.size];
    }
    if (self.vmQemuConfig.shareClipboardEnabled) {
        [[UTMPasteboard generalPasteboard] requestPollingModeForObject:self];
    }
}

#pragma mark - Key handling

- (void)setKeyboardVisible:(BOOL)keyboardVisible {
    if (keyboardVisible) {
        [self.keyboardView becomeFirstResponder];
    } else {
        [self.keyboardView resignFirstResponder];
    }
    [super setKeyboardVisible:keyboardVisible];
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
    self.vm.viewState.displayScale = self.vmDisplay.viewportScale;
    self.vm.viewState.displayOriginX = 0;
    self.vm.viewState.displayOriginY = 0;
}

- (void)resetDisplay {
    self.vmDisplay.viewportScale = 1.0;
    self.vmDisplay.viewportOrigin = CGPointMake(0, 0);
    // persist this change in viewState
    self.vm.viewState.displayScale = 1.0;
    self.vm.viewState.displayOriginX = 0;
    self.vm.viewState.displayOriginY = 0;
}

#pragma mark - Resizing

- (void)displayResize:(CGSize)size {
    UTMLog(@"resizing to (%f, %f)", size.width, size.height);
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    if (self.vmQemuConfig.displayRetina) {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
        bounds = CGRectApplyAffineTransform(bounds, transform);
    }
    [self.vmDisplay requestResolution:bounds];
}

#pragma mark - SPICE IO Delegates

- (void)spiceDidCreateInput:(CSInput *)input {
    if (self.vmInput == nil) {
        self.vmInput = input;
    }
}

- (void)spiceDidDestroyInput:(CSInput *)input {
    if (self.vmInput == input) {
        self.vmInput = nil;
    }
}

- (void)spiceDidCreateDisplay:(CSDisplay *)display {
    if (self.vmDisplay == nil && display.isPrimaryDisplay) {
        self.vmDisplay = display;
        _renderer.source = display;
        // restore last size
        CGPoint displayOrigin = CGPointMake(self.vm.viewState.displayOriginX, self.vm.viewState.displayOriginY);
        display.viewportOrigin = displayOrigin;
        double displayScale = self.vm.viewState.displayScale;
        if (displayScale) { // cannot be zero
            display.viewportScale = displayScale;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (displayScale != 1.0 || !CGPointEqualToPoint(displayOrigin, CGPointZero)) {
                // make the zoom button zoom out
                self.toolbar.isViewportChanged = YES;
            }
        });
    }
}

- (void)spiceDidDestroyDisplay:(CSDisplay *)display {
    if (self.vmDisplay == display) {
        self.vmDisplay = nil;
        _renderer.source = nil;
    }
}

- (void)spiceDidChangeDisplay:(CSDisplay *)display {
    if (display == self.vmDisplay) {
        
    }
}

@end
