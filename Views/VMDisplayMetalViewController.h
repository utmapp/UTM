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

#import <UIKit/UIKit.h>
#import "UTMVirtualMachineDelegate.h"
#import "UTMSpiceIODelegate.h"
#import "CSInput.h"

@class UTMSpiceIO;
@class UTMVirtualMachine;
@class VMCursor;
@class VMKeyboardView;
@class VMKeyboardButton;

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController : UIViewController<UTMVirtualMachineDelegate, UTMSpiceIODelegate, UIGestureRecognizerDelegate> {
    NSMutableArray<UIKeyCommand *> *_keyCommands;
    
    // cursor handling
    CGPoint _lastTwoPanOrigin;
    BOOL _mouseDown;
    UIDynamicAnimator *_animator;
    VMCursor *_cursor;
    
    // Gestures
    UISwipeGestureRecognizer *_swipeUp;
    UISwipeGestureRecognizer *_swipeDown;
    UISwipeGestureRecognizer *_swipeScrollUp;
    UISwipeGestureRecognizer *_swipeScrollDown;
    UIPanGestureRecognizer *_pan;
    UIPanGestureRecognizer *_twoPan;
    UIPanGestureRecognizer *_threePan;
    UITapGestureRecognizer *_tap;
    UITapGestureRecognizer *_twoTap;
    UILongPressGestureRecognizer *_longPress;
    UIPinchGestureRecognizer *_pinch;
    
    // Feedback generators
    UISelectionFeedbackGenerator *_clickFeedbackGenerator;
    UIImpactFeedbackGenerator *_resizeFeedbackGenerator;
}

@property (nonatomic, strong) UTMVirtualMachine *vm;
@property (nonatomic, readonly, weak) UTMSpiceIO *spiceIO;
@property (nonatomic, readwrite) BOOL prefersStatusBarHidden;
@property (weak, nonatomic) IBOutlet MTKView *mtkView;
@property (weak, nonatomic) IBOutlet VMKeyboardView *keyboardView;
@property (strong, nonatomic) IBOutlet UIInputView *inputAccessoryView;
@property (strong, nonatomic) IBOutlet UIView *toolbarAccessoryView;
@property (nonatomic, assign) BOOL lastDisplayChangeResize;
@property (weak, nonatomic) IBOutlet UIButton *powerExitButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseResumeButton;
@property (weak, nonatomic) IBOutlet UIButton *restartButton;
@property (weak, nonatomic) IBOutlet UIButton *zoomButton;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *placeholderView;
@property (weak, nonatomic) IBOutlet UIImageView *placeholderImageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *placeholderIndicator;
@property (weak, nonatomic) IBOutlet UIButton *resumeBigButton;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyButtons;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyModifierButtons;
@property (nonatomic, readonly) BOOL serverModeCursor;
@property (nonatomic, readonly) BOOL autosaveBackground;
@property (nonatomic, readonly) BOOL autosaveLowMemory;

- (void)sendExtendedKey:(SendKeyType)type code:(int)code;
- (void)onDelay:(float)delay action:(void (^)(void))block;
- (BOOL)boolForSetting:(NSString *)key;
- (NSInteger)integerForSetting:(NSString *)key;

- (IBAction)changeDisplayZoom:(UIButton *)sender;
- (IBAction)pauseResumePressed:(UIButton *)sender;
- (IBAction)powerPressed:(UIButton *)sender;
- (IBAction)restartPressed:(UIButton *)sender;
- (IBAction)showKeyboardButton:(UIButton *)sender;
- (IBAction)hideToolbarButton:(UIButton *)sender;

@end

NS_ASSUME_NONNULL_END
