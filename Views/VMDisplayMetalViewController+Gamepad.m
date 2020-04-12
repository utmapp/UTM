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
    //init Gamepad
    [[UIApplication sharedApplication]setIdleTimerDisabled:YES];
    // notifications for controller (dis)connect
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    for (GCController *controller in [GCController controllers]) {
        [self setupController:controller];
    }
}

- (NSInteger) integerForKeySetting: (NSString *)key {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
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
            if (gamepad.leftTrigger.isPressed != wkself->_leftTriggerPressed) {
                [wkself keyboardAndMouseSender:@"leftTrigger" withKeyStatus:gamepad.leftTrigger.isPressed];
                wkself->_leftTriggerPressed = gamepad.leftTrigger.isPressed;
                return;
            }
        }
        
        // right trigger
        if (gamepad.rightTrigger == element) {
            if (gamepad.rightTrigger.isPressed != wkself->_rightTriggerPressed) {
                [wkself keyboardAndMouseSender:@"rightTrigger" withKeyStatus:gamepad.rightTrigger.isPressed];
                wkself->_rightTriggerPressed = gamepad.rightTrigger.isPressed;
                return;
            }
        }
        
        // left shoulder button
        if (gamepad.leftShoulder == element) {
            if (gamepad.leftShoulder.isPressed != wkself->_leftShoulderPressed) {
                [wkself keyboardAndMouseSender:@"leftShoulder" withKeyStatus:gamepad.leftShoulder.isPressed];
                wkself->_leftShoulderPressed = gamepad.leftShoulder.isPressed;
                return;
            }
        }
        
        // right shoulder button
        if (gamepad.rightShoulder == element) {
            if (gamepad.rightShoulder.isPressed != wkself->_rightShoulderPressed) {
                [wkself keyboardAndMouseSender:@"rightShoulder" withKeyStatus:gamepad.rightShoulder.isPressed];
                wkself->_rightShoulderPressed = gamepad.rightShoulder.isPressed;
                return;
            }
        }
        
        // A button
        if (gamepad.buttonA == element) {
            if (gamepad.buttonA.isPressed != wkself->_buttonAPressed) {
                [wkself keyboardAndMouseSender:@"buttonA" withKeyStatus:gamepad.buttonA.isPressed];
                wkself->_buttonAPressed = gamepad.buttonA.isPressed;
                return;
            }
        }
        
        // B button
        if (gamepad.buttonB == element) {
            if (gamepad.buttonB.isPressed != wkself->_buttonBPressed) {
                [wkself keyboardAndMouseSender:@"buttonB" withKeyStatus:gamepad.buttonB.isPressed];
                wkself->_buttonBPressed = gamepad.buttonB.isPressed;
                return;
            }
        }
        
        // X button
        if (gamepad.buttonX == element) {
            if (gamepad.buttonX.isPressed != wkself->_buttonXPressed) {
                [wkself keyboardAndMouseSender:@"buttonX" withKeyStatus:gamepad.buttonX.isPressed];
                wkself->_buttonXPressed = gamepad.buttonX.isPressed;
                return;
            }
        }
        // Y button
        if (gamepad.buttonY == element) {
            if (gamepad.buttonY.isPressed != wkself->_buttonYPressed) {
                [wkself keyboardAndMouseSender:@"buttonY" withKeyStatus:gamepad.buttonY.isPressed];
                wkself->_buttonYPressed = gamepad.buttonY.isPressed;
                return;
            }
        }
        
        // d-pad
        if (gamepad.dpad == element) {
            if (gamepad.dpad.up.isPressed != wkself->_dpadUpPressed) {
                [wkself keyboardAndMouseSender:@"dpad_up" withKeyStatus:gamepad.dpad.up.isPressed];
                wkself->_dpadUpPressed = gamepad.dpad.up.isPressed;
                return;
            }
            if (gamepad.dpad.left.isPressed != wkself->_dpadLeftPressed) {
                [wkself keyboardAndMouseSender:@"dpad_left" withKeyStatus:gamepad.dpad.left.isPressed];
                wkself->_dpadLeftPressed = gamepad.dpad.left.isPressed;
                return;
            }
            if (gamepad.dpad.down.isPressed != wkself->_dpadDownPressed) {
                [wkself keyboardAndMouseSender:@"dpad_down" withKeyStatus:gamepad.dpad.down.isPressed];
                wkself->_dpadDownPressed = gamepad.dpad.down.isPressed;
                return;
            }
            if (gamepad.dpad.right.isPressed != wkself->_dpadRightPressed) {
                [wkself keyboardAndMouseSender:@"dpad_right" withKeyStatus:gamepad.dpad.right.isPressed];
                wkself->_dpadRightPressed = gamepad.dpad.right.isPressed;
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
                wkself->_buttonMenuPressed = gamepad.buttonMenu.isPressed;
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
        self -> _leftMouseButtonDown = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:self -> _leftMouseButtonDown point:CGPointZero];
        return;
    }
    if ([value isEqualToString:@"Mouse Right Button"]) {
        self -> _rightMouseButtonDown = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_RIGHT pressed:self -> _rightMouseButtonDown point:CGPointZero];
        return;
    }
    if ([value isEqualToString:@"Mouse Middle Button"]) {
        self -> _middleMouseButtonDown = isPressed;
        [self.vmInput sendMouseButton:SEND_BUTTON_MIDDLE pressed:self -> _middleMouseButtonDown point:CGPointZero];
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
    if (self->_leftMouseButtonDown) {
        button = SEND_BUTTON_LEFT;
    } else if (self -> _rightMouseButtonDown) {
        button = SEND_BUTTON_RIGHT;
    } else if (self -> _middleMouseButtonDown) {
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
