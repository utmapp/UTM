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
#import "VMDisplayMetalViewController+Touch.h"
#import "VMDisplayMetalViewController+Pointer.h"
#import "VMDisplayMetalViewController+Gamepad.h"
#import "UTMRenderer.h"
#import "UTMVirtualMachine.h"
#import "UTMQemuManager.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Display.h"
#import "CSDisplayMetal.h"
#import "UTMSpiceIO.h"

@interface VMDisplayMetalViewController ()

@property (nonatomic, readwrite, weak) UTMSpiceIO *spiceIO;

@end

@implementation VMDisplayMetalViewController {
    UTMRenderer *_renderer;
}

@synthesize vmDisplay;
@synthesize vmInput;

- (BOOL)serverModeCursor {
    return self.vmInput.serverModeCursor;
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
    
    [_renderer changeUpscaler:self.vmConfiguration.displayUpscalerValue
                   downscaler:self.vmConfiguration.displayDownscalerValue];
    
    self.mtkView.delegate = _renderer;
    
    [self initTouch];
    [self initGamepad];
    // Pointing device support on iPadOS 13.4 GM or later
    if (@available(iOS 13.4, *)) {
        // Betas of iPadOS 13.4 did not include this API, that's why I check if the class exists
        if (NSClassFromString(@"UIPointerInteraction") != nil) {
            [self initPointerInteraction];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
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
    [super virtualMachine:vm transitionToState:state];
    switch (state) {
        case kVMStopped:
        case kVMPaused:
        case kVMSuspended: {
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.placeholderImageView.hidden = NO;
                self.placeholderImageView.image = self.vm.screenshot;
                self.mtkView.hidden = YES;
            } completion:nil];
            break;
        }
        case kVMStarted: {
            [UIView transitionWithView:self.view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.placeholderImageView.hidden = YES;
                self.mtkView.hidden = NO;
            } completion:nil];
            self->_renderer.sourceScreen = self.vmDisplay;
            self->_renderer.sourceCursor = self.vmInput;
            [self orientationDidChange:nil];
            break;
        }
        default: {
            break;
        }
    }
}

#pragma mark - Key handling

- (void)sendExtendedKey:(SendKeyType)type code:(int)code {
    if ((code & 0xFF00) == 0xE000) {
        code = 0x100 | (code & 0xFF);
    } else if (code >= 0x100) {
        NSLog(@"warning: ignored invalid keycode 0x%x", code);
    }
    [self.vmInput sendKey:type code:code];
}

#pragma mark - Toolbar actions

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

#pragma mark - Notifications

- (void)orientationDidChange:(NSNotification *)notification {
    NSLog(@"orientation changed");
    if (self.vmConfiguration.displayFitScreen) {
        // Bug? on iPad, it seems like [UIScreen mainScreen].bounds does not update when this notification
        // is received. so we race it by waiting 0.1s before getting the new resolution. This does not
        // happen on iPhone.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGRect bounds = [UIScreen mainScreen].bounds;
            if (self.vmConfiguration.displayRetina) {
                CGFloat scale = [UIScreen mainScreen].scale;
                CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
                bounds = CGRectApplyAffineTransform(bounds, transform);
            }
            [self.vmDisplay requestResolution:bounds];
        });
    }
}

@end
