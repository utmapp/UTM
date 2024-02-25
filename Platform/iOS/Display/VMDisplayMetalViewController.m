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
#import "VMDisplayMetalViewController+Private.h"
#import "VMDisplayMetalViewController+Keyboard.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "VMDisplayMetalViewController+Pointer.h"
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
#import "VMDisplayMetalViewController+Pencil.h"
#endif
#import "VMDisplayMetalViewController+Gamepad.h"
#import "VMKeyboardView.h"
#import "UTMLogging.h"
#import "CSDisplay.h"
#import "UTM-Swift.h"
@import CocoaSpiceRenderer;

static const NSInteger kResizeDebounceSecs = 1;
static const NSInteger kResizeTimeoutSecs = 5;

@interface VMDisplayMetalViewController ()

@property (nonatomic, nullable) CSMetalRenderer *renderer;
@property (nonatomic, nullable) id debounceResize;
@property (nonatomic, nullable) id cancelResize;
@property (nonatomic) BOOL ignoreNextResize;

@end

@implementation VMDisplayMetalViewController

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
    self.mtkView = [[CSMTKView alloc] initWithFrame:CGRectZero];
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
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    // Apple Pencil 2 double tap support on iOS 12.1+
    if (@available(iOS 12.1, *)) {
        [self initPencilInteraction];
    }
#endif
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.prefersHomeIndicatorAutoHidden = YES;
#if !TARGET_OS_VISION
    [self startGCMouse];
#endif
    [self.vmDisplay addRenderer:self.renderer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
#if !TARGET_OS_VISION
    [self stopGCMouse];
#endif
    [self.vmDisplay removeRenderer:self.renderer];
    [self removeObserver:self forKeyPath:@"vmDisplay.displaySize"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.delegate.displayViewSize = [self convertSizeToNative:self.view.bounds.size];
    [self addObserver:self forKeyPath:@"vmDisplay.displaySize" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.delegate.displayViewSize = [self convertSizeToNative:size];
        [self.delegate display:self.vmDisplay didResizeTo:self.vmDisplay.displaySize];
        if (self.delegate.qemuDisplayIsDynamicResolution && self.isDynamicResolutionSupported) {
            if (!CGSizeEqualToSize(size, self.vmDisplay.displaySize)) {
                [self requestResolutionChangeToSize:size];
            }
        }
    }];
}

- (void)enterSuspendedWithIsBusy:(BOOL)busy {
    [super enterSuspendedWithIsBusy:busy];
    self.prefersPointerLocked = NO;
    self.view.window.isIndirectPointerTouchIgnored = NO;
    if (!busy) {
        if (self.delegate.qemuHasClipboardSharing) {
            [[UTMPasteboard generalPasteboard] releasePollingModeForObject:self];
        }
    }
}

- (void)enterLive {
    [super enterLive];
    self.prefersPointerLocked = YES;
    self.view.window.isIndirectPointerTouchIgnored = YES;
    if (self.delegate.qemuDisplayIsDynamicResolution && self.isDynamicResolutionSupported) {
        [self requestResolutionChangeToSize:self.view.bounds.size];
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

- (CGSize)convertSizeToNative:(CGSize)size {
    if (self.delegate.qemuDisplayIsNativeResolution) {
        size.width = CGPointToPixel(size.width);
        size.height = CGPointToPixel(size.height);
    }
    return size;
}

- (void)requestResolutionChangeToSize:(CGSize)size {
    self.debounceResize = [self debounce:kResizeDebounceSecs context:self.debounceResize action:^{
        UTMLog(@"DISPLAY: requesting resolution (%f, %f)", size.width, size.height);
        CGSize newSize = [self convertSizeToNative:size];
        CGRect bounds = CGRectMake(0, 0, newSize.width, newSize.height);
        self.debounceResize = nil;
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
        self.cancelResize = [self debounce:kResizeTimeoutSecs context:self.cancelResize action:^{
            self.cancelResize = nil;
            UTMLog(@"DISPLAY: requesting resolution cancelled");
            [self resizeWindowToDisplaySize];
        }];
#endif
        [self.vmDisplay requestResolution:bounds];
    }];
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
    if (!self.delegate.qemuDisplayIsNativeResolution) {
        scaling = CGPointToPixel(scaling);
    }
    if (scaling) { // cannot be zero
        self.vmDisplay.viewportScale = scaling;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"vmDisplay.displaySize"]) {
        UTMLog(@"DISPLAY: vmDisplay.displaySize changed");
        if (self.cancelResize) {
            [self debounce:0 context:self.cancelResize action:^{}];
            self.cancelResize = nil;
        }
        self.debounceResize = [self debounce:kResizeDebounceSecs context:self.debounceResize action:^{
            [self resizeWindowToDisplaySize];
        }];
    }
}

- (void)setIsDynamicResolutionSupported:(BOOL)isDynamicResolutionSupported {
    if (_isDynamicResolutionSupported != isDynamicResolutionSupported) {
        _isDynamicResolutionSupported = isDynamicResolutionSupported;
        UTMLog(@"DISPLAY: isDynamicResolutionSupported = %d", isDynamicResolutionSupported);
        if (self.delegate.qemuDisplayIsDynamicResolution) {
            if (isDynamicResolutionSupported) {
                [self requestResolutionChangeToSize:self.view.bounds.size];
            } else {
                [self resizeWindowToDisplaySize];
            }
        }
    }
}

- (void)resizeWindowToDisplaySize {
    CGSize displaySize = self.vmDisplay.displaySize;
    UTMLog(@"DISPLAY: request window resize to (%f, %f)", displaySize.width, displaySize.height);
#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
    CGSize minSize = displaySize;
    if (self.delegate.qemuDisplayIsNativeResolution) {
        minSize.width = CGPixelToPoint(minSize.width);
        minSize.height = CGPixelToPoint(minSize.height);
    }
    CGSize maxSize = CGSizeMake(UIProposedSceneSizeNoPreference, UIProposedSceneSizeNoPreference);
    UIWindowSceneGeometryPreferencesVision *geoPref = [[UIWindowSceneGeometryPreferencesVision alloc] initWithSize:minSize];
    if (self.delegate.qemuDisplayIsDynamicResolution && self.isDynamicResolutionSupported) {
        geoPref.minimumSize = CGSizeMake(800, 600);
        geoPref.maximumSize = maxSize;
        geoPref.resizingRestrictions = UIWindowSceneResizingRestrictionsFreeform;
    } else {
        geoPref.minimumSize = minSize;
        geoPref.maximumSize = maxSize;
        geoPref.resizingRestrictions = UIWindowSceneResizingRestrictionsUniform;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        CGSize currentViewSize = self.view.bounds.size;
        UTMLog(@"DISPLAY: old view size = (%f, %f)", currentViewSize.width, currentViewSize.height);
        if (CGSizeEqualToSize(minSize, currentViewSize)) {
            // since `-viewWillTransitionToSize:withTransitionCoordinator:` is not called
            self.delegate.displayViewSize = [self convertSizeToNative:currentViewSize];
            [self.delegate display:self.vmDisplay didResizeTo:displaySize];
        }
        [self.view.window.windowScene requestGeometryUpdateWithPreferences:geoPref errorHandler:nil];
    });
#else
    if (CGSizeEqualToSize(displaySize, CGSizeZero)) {
        return;
    }
    [self.delegate display:self.vmDisplay didResizeTo:displaySize];
#endif
}

@end
