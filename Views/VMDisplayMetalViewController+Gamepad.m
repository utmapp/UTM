//
// Copyright © 2020 osy. All rights reserved.
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

#import "UIViewController+Extensions.h"
#import "VMDisplayMetalViewController+Gamepad.h"
#import "CSDisplayMetal.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"


@implementation VMDisplayMetalViewController(Gamepad)


- (void)initGamepad {
    // notifications for controller (dis)connect
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    for (GCController *controller in [GCController controllers]) {
        [self setupController:controller];
    }
}

#pragma mark - Gamepad connection

- (void)controllerWasConnected:(NSNotification *)notification {
    // a controller was connected
    GCController *controller = (GCController *)notification.object;
    NSLog(@"Controller disconnected:\n%@", controller.vendorName);
    [self setupController:controller];
}

- (void)controllerWasDisconnected:(NSNotification *)notification {
    // a controller was disconnected
    GCController *controller = (GCController *)notification.object;
    NSLog(@"Controller disconnected:\n%@", controller.vendorName);
    _controller = nil;
    [_mouseMovementTimer invalidate];
    _mouseMovementTimer = nil;
    
}

- (void)setupController: (GCController *)controller {
    __weak typeof(self) weakSelf = self;
    _controller = controller;
    // register block for input change detection
    GCExtendedGamepad *profile = _controller.extendedGamepad;
    profile.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element)
    {
        VMDisplayMetalViewController *wkself = weakSelf;
        
        // left trigger
        if (gamepad.leftTrigger == element) {
            //            gamepad.leftTrigger.isPressed
            if (gamepad.leftTrigger.isPressed != wkself->_buttonPressed[UTMGCButtonTriggerLeft]) {
                [wkself keyboardAndMouseSender:@"leftTrigger" withKeyStatus:gamepad.leftTrigger.isPressed];
                wkself->_buttonPressed[UTMGCButtonTriggerLeft] = gamepad.leftTrigger.isPressed;
                return;
            }
        }
        
        // right trigger
        if (gamepad.rightTrigger == element) {
            if (gamepad.rightTrigger.isPressed != wkself->_buttonPressed[UTMGCButtonTriggerRight]) {
                [wkself keyboardAndMouseSender:@"rightTrigger" withKeyStatus:gamepad.rightTrigger.isPressed];
                wkself->_buttonPressed[UTMGCButtonTriggerRight] = gamepad.rightTrigger.isPressed;
                return;
            }
        }
        
        // left shoulder button
        if (gamepad.leftShoulder == element) {
            if (gamepad.leftShoulder.isPressed != wkself->_buttonPressed[UTMGCButtonShoulderLeft]) {
                [wkself keyboardAndMouseSender:@"leftShoulder" withKeyStatus:gamepad.leftShoulder.isPressed];
                wkself->_buttonPressed[UTMGCButtonShoulderLeft] = gamepad.leftShoulder.isPressed;
                return;
            }
        }
        
        // right shoulder button
        if (gamepad.rightShoulder == element) {
            if (gamepad.rightShoulder.isPressed != wkself->_buttonPressed[UTMGCButtonShoulderRight]) {
                [wkself keyboardAndMouseSender:@"rightShoulder" withKeyStatus:gamepad.rightShoulder.isPressed];
                wkself->_buttonPressed[UTMGCButtonShoulderRight] = gamepad.rightShoulder.isPressed;
                return;
            }
        }
        
        // A button
        if (gamepad.buttonA == element) {
            if (gamepad.buttonA.isPressed != wkself->_buttonPressed[UTMGCButtonA]) {
                [wkself keyboardAndMouseSender:@"buttonA" withKeyStatus:gamepad.buttonA.isPressed];
                wkself->_buttonPressed[UTMGCButtonA] = gamepad.buttonA.isPressed;
                return;
            }
        }
        
        // B button
        if (gamepad.buttonB == element) {
            if (gamepad.buttonB.isPressed != wkself->_buttonPressed[UTMGCButtonB]) {
                [wkself keyboardAndMouseSender:@"buttonB" withKeyStatus:gamepad.buttonB.isPressed];
                wkself->_buttonPressed[UTMGCButtonB] = gamepad.buttonB.isPressed;
                return;
            }
        }
        
        // X button
        if (gamepad.buttonX == element) {
            if (gamepad.buttonX.isPressed != wkself->_buttonPressed[UTMGCButtonX]) {
                [wkself keyboardAndMouseSender:@"buttonX" withKeyStatus:gamepad.buttonX.isPressed];
                wkself->_buttonPressed[UTMGCButtonX] = gamepad.buttonX.isPressed;
                return;
            }
        }
        // Y button
        if (gamepad.buttonY == element) {
            if (gamepad.buttonY.isPressed != wkself->_buttonPressed[UTMGCButtonY]) {
                [wkself keyboardAndMouseSender:@"buttonY" withKeyStatus:gamepad.buttonY.isPressed];
                wkself->_buttonPressed[UTMGCButtonY] = gamepad.buttonY.isPressed;
                return;
            }
        }
        
        // d-pad
        if (gamepad.dpad == element) {
            if (gamepad.dpad.up.isPressed != wkself->_buttonPressed[UTMGCButtonDpadUp]) {
                [wkself keyboardAndMouseSender:@"dpad_up" withKeyStatus:gamepad.dpad.up.isPressed];
                wkself->_buttonPressed[UTMGCButtonDpadUp] = gamepad.dpad.up.isPressed;
                return;
            }
            if (gamepad.dpad.left.isPressed != wkself->_buttonPressed[UTMGCButtonDpadLeft]) {
                [wkself keyboardAndMouseSender:@"dpad_left" withKeyStatus:gamepad.dpad.left.isPressed];
                wkself->_buttonPressed[UTMGCButtonDpadLeft] = gamepad.dpad.left.isPressed;
                return;
            }
            if (gamepad.dpad.down.isPressed != wkself->_buttonPressed[UTMGCButtonDpadDown]) {
                [wkself keyboardAndMouseSender:@"dpad_down" withKeyStatus:gamepad.dpad.down.isPressed];
                wkself->_buttonPressed[UTMGCButtonDpadDown] = gamepad.dpad.down.isPressed;
                return;
            }
            if (gamepad.dpad.right.isPressed != wkself->_buttonPressed[UTMGCButtonDpadRight]) {
                [wkself keyboardAndMouseSender:@"dpad_right" withKeyStatus:gamepad.dpad.right.isPressed];
                wkself->_buttonPressed[UTMGCButtonDpadRight] = gamepad.dpad.right.isPressed;
                return;
            }
        }
        
        // left stick
        if (gamepad.leftThumbstick == element) {
            //            NSLog(@"xValue: %f, yValue: %f", gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value);
            wkself->_scrollingDirection = CGPointMake(gamepad.leftThumbstick.xAxis.value, -gamepad.leftThumbstick.yAxis.value);
        }
        
        // right stick
        if (gamepad.rightThumbstick == element) {
            NSInteger speed = [wkself integerForSetting:@"rightThumbstickSpeed"];
            wkself->_cursorDirection = CGPointMake(gamepad.rightThumbstick.xAxis.value * speed, -gamepad.rightThumbstick.yAxis.value * speed);
        }
        
        if (@available(iOS 13.0, *)) {
            if (gamepad.buttonMenu == element) {
                [wkself keyboardAndMouseSender:@"buttonMenu" withKeyStatus:gamepad.buttonMenu.isPressed];
                wkself->_buttonPressed[UTMGCButtonMenu] = gamepad.buttonMenu.isPressed;
            }
        }
    };
    
    _controller.controllerPausedHandler = ^(GCController *controller){
    };
    
    if (!_mouseMovementTimer) {
        _mouseMovementTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(cursorMovementThread) userInfo:nil repeats:YES];
    }
}

- (void) keyboardAndMouseSender: (NSString *) identifier withKeyStatus: (BOOL) isPressed{
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:identifier];
    if ([value isEqualToString:@"Disabled"]) {
        return;
    }
    if ([value isEqualToString:@"Mouse Left Button"]) {
        self -> _buttonPressed[UTMGCButtonMouseLeft] = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:self -> _buttonPressed[UTMGCButtonMouseLeft] point:CGPointZero];
        return;
    }
    if ([value isEqualToString:@"Mouse Right Button"]) {
        self -> _buttonPressed[UTMGCButtonMouseRight] = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_RIGHT pressed:self -> _buttonPressed[UTMGCButtonMouseRight] point:CGPointZero];
        return;
    }
    if ([value isEqualToString:@"Mouse Middle Button"]) {
        self -> _buttonPressed[UTMGCButtonMouseMiddle] = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_MIDDLE pressed:self -> _buttonPressed[UTMGCButtonMouseMiddle] point:CGPointZero];
        return;
    }
    
    NSNumber *code = [UTMConfiguration stringToScancodeMap][value];
    int scancode = [code intValue];
    if (scancode < 0) {
        return;
    }
    [self sendExtendedKey:isPressed ? SEND_KEY_PRESS : SEND_KEY_RELEASE code:scancode];
}

#pragma mark - Gamepad opperations

- (void) cursorMovementThread {
    
    SendButtonType button = SEND_BUTTON_NONE;
    if (self->_buttonPressed[UTMGCButtonMouseLeft]) {
        button = SEND_BUTTON_LEFT;
    } else if (self -> _buttonPressed[UTMGCButtonMouseRight]) {
        button = SEND_BUTTON_RIGHT;
    } else if (self -> _buttonPressed[UTMGCButtonMouseMiddle]) {
        button = SEND_BUTTON_MIDDLE;
    }
    if (self->_cursorDirection.x != 0 || self->_cursorDirection.y != 0) {
        [self.vmInput sendMouseMotion:button point:self->_cursorDirection];
    }
    if (self->_scrollingDirection.y != 0) {
        [self.vmInput sendMouseScroll:SEND_SCROLL_SMOOTH button:button dy:self->_scrollingDirection.y];
    }
    
}

#pragma mark - Map for keycode



@end
