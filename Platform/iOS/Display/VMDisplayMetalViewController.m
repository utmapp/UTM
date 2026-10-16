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

@property (nonatomic, nullable) id debounceResize;
@property (nonatomic, nullable) id cancelResize;
@property (nonatomic) BOOL ignoreNextResize;
@property (nonatomic) NSLayoutConstraint *displayBottomConstraint;
#if !TARGET_OS_VISION
@property (nonatomic, nullable) VMTouchpadView *touchpadView API_AVAILABLE(ios(26.0));
@property (nonatomic, nullable) NSLayoutConstraint *deckAccessoryBottomConstraint;
@property (nonatomic, nullable) NSLayoutConstraint *touchpadHeightConstraint;
#endif
@property (nonatomic) BOOL isDeckLayoutPending;

@end

@implementation VMDisplayMetalViewController

@synthesize renderer;

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
    self.mtkView.translatesAutoresizingMaskIntoConstraints = NO;
    self.displayBottomConstraint = [self.mtkView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [self.mtkView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mtkView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mtkView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.displayBottomConstraint,
    ]];
}

- (BOOL)serverModeCursor {
    return self.vmInput.serverModeCursor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if !TARGET_OS_VISION
    // set up software keyboard, which visionOS replaces with its own keyboard window
    self.inputAccessoryView = [[VMKeyboardAccessoryView alloc] initWithTarget:self];
    self.keyboardView.inputAccessoryView = self.inputAccessoryView;
#endif
    
    // Set the view to use the default device
    self.mtkView.frame = self.view.bounds;
    self.mtkView.drawableSize = self.view.bounds.size;
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
    
    [self.renderer changeUpscaler:self.delegate.qemuDisplayUpscaler
                       downscaler:self.delegate.qemuDisplayDownscaler];
    
    self.mtkView.delegate = self.renderer;
    
    [self initTouch];
    [self initGamepad];
    [self initPointerInteraction];
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
    [self initPencilInteraction];
#endif
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.prefersHomeIndicatorAutoHidden = YES;
#if !TARGET_OS_VISION
    [self startGCMouse];
#endif
    [self setSystemGestureButtonsClaimed:YES];
    [self.vmDisplay addRenderer:self.renderer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
#if !TARGET_OS_VISION
    [self stopGCMouse];
#endif
    [self setSystemGestureButtonsClaimed:NO];
    [self.vmDisplay removeRenderer:self.renderer];
    [self removeObserver:self forKeyPath:@"vmDisplay.displaySize"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.delegate.displayViewSize = [self convertSizeToNative:self.displayAreaSize];
    [self addObserver:self forKeyPath:@"vmDisplay.displaySize" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:nil];
    if ([self integerForSetting:@"QEMURendererFPSLimit"] > 0) {
        self.mtkView.preferredFramesPerSecond = [self integerForSetting:@"QEMURendererFPSLimit"];
    }
#if !TARGET_OS_VISION
    else if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        // only apply ProMotion by default on iPad which has a larger battery
        // on iPhone, we depend on the user manually setting the FPS limit to 120
        NSInteger maxFps = self.view.window.screen.maximumFramesPerSecond;
        if (maxFps > 0) {
           self.mtkView.preferredFramesPerSecond = maxFps;
        }
   }
#endif
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self displayAreaDidChangeToSize:[self displayAreaSizeForViewSize:size]];
    }];
}

#pragma mark - Input deck

/// Whether the accessory row sits between the guest display and the fold.
///
/// The keyboard is dismissed and shown again while the row moves, and the row stays for a
/// keyboard that is on its way back.
- (BOOL)isDeckAccessoryShown {
#if !TARGET_OS_VISION
    return self.inputDeckHeight > 0 && !self.isTouchpadShown && (self.isKeyboardShown || self.keyboardView.isFirstResponder);
#else
    return NO;
#endif
}

/// Height of the accessory row while it sits between the guest display and the fold.
- (CGFloat)deckAccessoryHeight {
#if !TARGET_OS_VISION
    if (!self.isDeckAccessoryShown) {
        return 0;
    }
    return [self.inputAccessoryView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
#else
    return 0;
#endif
}

/// Height at the bottom of the view kept clear of the guest display: the deck, the fold and the accessory row.
- (CGFloat)deckReservedHeight {
    if (self.inputDeckHeight <= 0) {
        return 0;
    }
    return self.inputDeckHeight + self.inputDeckFoldHeight + self.deckAccessoryHeight;
}

/// The part of the view that shows the guest display, above the input deck when there is one.
- (CGSize)displayAreaSizeForViewSize:(CGSize)size {
    size.height = MAX(0, size.height - self.deckReservedHeight);
    return size;
}

- (CGSize)displayAreaSize {
    return [self displayAreaSizeForViewSize:self.view.bounds.size];
}

- (void)displayAreaDidChangeToSize:(CGSize)size {
    self.delegate.displayViewSize = [self convertSizeToNative:size];
    if (!CGSizeEqualToSize(self.vmDisplay.displaySize, CGSizeZero)) {
        [self.delegate display:self.vmDisplay didResizeTo:self.vmDisplay.displaySize];
    }
    if (self.delegate.qemuDisplayIsDynamicResolution && self.isDynamicResolutionSupported) {
        if (!CGSizeEqualToSize(size, self.vmDisplay.displaySize)) {
            [self requestResolutionChangeToSize:size];
        }
    }
}

- (void)setInputDeckHeight:(CGFloat)inputDeckHeight {
    if (fabs(_inputDeckHeight - inputDeckHeight) < 0.5) {
        return;
    }
    [self loadViewIfNeeded];
    _inputDeckHeight = inputDeckHeight;
    [self setNeedsDeckLayout];
}

- (void)setInputDeckFoldHeight:(CGFloat)inputDeckFoldHeight {
    if (fabs(_inputDeckFoldHeight - inputDeckFoldHeight) < 0.5) {
        return;
    }
    [self loadViewIfNeeded];
    _inputDeckFoldHeight = inputDeckFoldHeight;
    [self setNeedsDeckLayout];
}

- (void)setIsKeyboardShown:(BOOL)isKeyboardShown {
    if (_isKeyboardShown == isKeyboardShown) {
        return;
    }
    _isKeyboardShown = isKeyboardShown;
    if (self.inputDeckHeight > 0) {
        [self setNeedsDeckLayout];
    }
}

/// The deck's parts arrive one by one from a view update, which must not change the view state
/// itself, so they are laid out together on the next turn of the run loop.
- (void)setNeedsDeckLayout {
    if (self.isDeckLayoutPending) {
        return;
    }
    self.isDeckLayoutPending = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isDeckLayoutPending = NO;
        [self deckLayoutDidChange];
    });
}

- (void)deckLayoutDidChange {
#if !TARGET_OS_VISION
    self.inputAccessoryView.isTouchpadKeyShown = self.inputDeckHeight > 0;
    [self updateDeckAccessory];
    self.touchpadHeightConstraint.constant = self.inputDeckHeight;
#endif
    CGFloat accessoryHeight = self.deckAccessoryHeight;
    self.displayBottomConstraint.constant = -self.deckReservedHeight;
    [self.view layoutIfNeeded];
    [self displayAreaDidChangeToSize:self.displayAreaSize];
    if (self.delegate.deckAccessoryHeight != accessoryHeight) {
        self.delegate.deckAccessoryHeight = accessoryHeight;
    }
}

#if !TARGET_OS_VISION
/// With the deck the accessory row leaves the keyboard and sits between the guest display and the fold.
///
/// The system would put it there itself, but then it belongs to the keyboard, and the guest
/// display and the toolbar could not lay out around it.
- (void)updateDeckAccessory {
    VMKeyboardAccessoryView *accessory = self.inputAccessoryView;
    BOOL isInDeck = self.inputDeckHeight > 0;
    BOOL isMoving = isInDeck ? accessory.superview != self.view : accessory.superview == self.view;
    // reloading the input views while the keyboard is moving between the panels crashes inside
    // UIKit, so the keyboard is dismissed and shown again around the change instead
    BOOL wasFirstResponder = isMoving && self.keyboardView.isFirstResponder;
    if (wasFirstResponder) {
        [self.keyboardView resignFirstResponder];
    }
    if (isInDeck && accessory.superview != self.view) {
        self.keyboardView.inputAccessoryView = nil;
        [self.view addSubview:accessory];
        self.deckAccessoryBottomConstraint = [accessory.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-(self.inputDeckHeight + self.inputDeckFoldHeight)];
        [NSLayoutConstraint activateConstraints:@[
            [accessory.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [accessory.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            self.deckAccessoryBottomConstraint,
        ]];
    } else if (!isInDeck && accessory.superview == self.view) {
        [accessory removeFromSuperview];
        self.deckAccessoryBottomConstraint = nil;
        self.keyboardView.inputAccessoryView = accessory;
    } else if (isInDeck) {
        self.deckAccessoryBottomConstraint.constant = -(self.inputDeckHeight + self.inputDeckFoldHeight);
    }
    if (wasFirstResponder) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.keyboardView becomeFirstResponder];
        });
    }
    accessory.hidden = isInDeck && !self.isDeckAccessoryShown;
}
#endif

- (void)setIsTouchpadShown:(BOOL)isTouchpadShown {
#if !TARGET_OS_VISION
    if (_isTouchpadShown == isTouchpadShown) {
        return;
    }
    [self loadViewIfNeeded];
    _isTouchpadShown = isTouchpadShown;
    if (@available(iOS 27.1, *)) {
        if (isTouchpadShown && !self.touchpadView) {
            VMTouchpadView *touchpad = [[VMTouchpadView alloc] initWithTarget:self];
            touchpad.translatesAutoresizingMaskIntoConstraints = NO;
            [self.view addSubview:touchpad];
            self.touchpadHeightConstraint = [touchpad.heightAnchor constraintEqualToConstant:self.inputDeckHeight];
            [NSLayoutConstraint activateConstraints:@[
                self.touchpadHeightConstraint,
                [touchpad.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                [touchpad.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
                [touchpad.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            ]];
            self.touchpadView = touchpad;
        }
        self.touchpadView.hidden = !isTouchpadShown;
    }
    if (isTouchpadShown) {
        [self prepareForTouchpad];
    }
    if (self.inputDeckHeight > 0) {
        [self setNeedsDeckLayout];
    }
#endif
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
        [self requestResolutionChangeToSize:self.displayAreaSize];
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
        size.width = CGPointToPixel(self.view, size.width);
        size.height = CGPointToPixel(self.view, size.height);
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
    self.renderer.viewportOrigin = origin;
    if (!self.delegate.qemuDisplayIsNativeResolution) {
        scaling = CGPointToPixel(self.view, scaling);
    }
    if (scaling) { // cannot be zero
        self.renderer.viewportScale = scaling;
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
                [self requestResolutionChangeToSize:self.displayAreaSize];
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
        minSize.width = CGPixelToPoint(self.view, minSize.width);
        minSize.height = CGPixelToPoint(self.view, minSize.height);
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
