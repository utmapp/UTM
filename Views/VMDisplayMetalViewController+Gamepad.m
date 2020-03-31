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

#import "VMDisplayMetalViewController+Gamepad.h"
#import "CSDisplayMetal.h"

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
    _SCANCODE_DICT = @{
        @"Ctrl":@29,
        @"Command/Windows":@57435,
        @"Option/Alt":@56,
        @"Shift":@42,
        @"Tab":@15,
        @"Space":@57,
        @"Enter":@28,
        @"Backspace":@14,
        @"Esc":@1,
        @"Caps":@-1,
        @"`":@-1,
        @"1":@2,
        @"2":@3,
        @"3":@4,
        @"4":@5,
        @"5":@6,
        @"6":@7,
        @"7":@8,
        @"8":@9,
        @"9":@10,
        @"0":@11,
        @"-":@12,
        @"=":@13,
        @"[":@26,
        @"]":@27,
        @";":@39,
        @"'":@40,
        @"\\":@43,
        @",":@51,
        @".":@52,
        @"/":@53,
        @"Ins":@-1,
        @"Home":@-1,
        @"PgUp":@-1,
        @"PgDn":@-1,
        @"Del":@-1,
        @"End":@-1,
        @"Up":@57416,
        @"Left":@57419,
        @"Down":@57424,
        @"Right":@57421,
        @"A":@30,
        @"B":@48,
        @"C":@46,
        @"D":@32,
        @"E":@18,
        @"F":@33,
        @"G":@34,
        @"H":@35,
        @"I":@23,
        @"J":@36,
        @"K":@37,
        @"L":@38,
        @"M":@50,
        @"N":@49,
        @"O":@24,
        @"P":@25,
        @"Q":@16,
        @"R":@19,
        @"S":@31,
        @"T":@20,
        @"U":@22,
        @"V":@47,
        @"W":@17,
        @"X":@45,
        @"Y":@21,
        @"Z":@44,
        @"F1":@59,
        @"F2":@60,
        @"F3":@61,
        @"F4":@62,
        @"F5":@63,
        @"F6":@64,
        @"F7":@65,
        @"F8":@66,
        @"F9":@67,
        @"F10":@68,
        @"F11":@87,
        @"F12":@88
    };
//    NSNumber *num = [_SCANCODE_DICT objectForKey:@"1"];
//    NSLog(@"test2: dict 1 is: %d", [num intValue]);
    
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
        NSString *message = @"";
        
        // left trigger
        if (gamepad.leftTrigger == element && gamepad.leftTrigger.isPressed) {
            message = @"Left Trigger";
        }
        
        // right trigger
        if (gamepad.rightTrigger == element && gamepad.rightTrigger.isPressed) {
            message = @"Right Trigger";
        }
        
        // left shoulder button
        if (gamepad.leftShoulder == element) {
            if (gamepad.leftShoulder.isPressed != self->_leftShoulderPressed) {
                [weakSelf keyboardAndMouseSender:@"leftShoulder" withKeyStatus:gamepad.leftShoulder.isPressed];
                self->_leftShoulderPressed = gamepad.leftShoulder.isPressed;
            }
        }
        
        // right shoulder button
        if (gamepad.rightShoulder == element) {
            if (gamepad.rightShoulder.isPressed != self->_rightShoulderPressed) {
                [weakSelf keyboardAndMouseSender:@"rightShoulder" withKeyStatus:gamepad.rightShoulder.isPressed];
                self->_rightShoulderPressed = gamepad.rightShoulder.isPressed;
            }
        }
        
        // A button
        if (gamepad.buttonA == element) {
            if (gamepad.buttonA.isPressed != self->_buttonAPressed) {
                [weakSelf keyboardAndMouseSender:@"buttonA" withKeyStatus:gamepad.buttonA.isPressed];
                self->_buttonAPressed = gamepad.buttonA.isPressed;
            }
        }
        
        // B button
        if (gamepad.buttonB == element) {
            if (gamepad.buttonB.isPressed != self->_buttonBPressed) {
                [weakSelf keyboardAndMouseSender:@"buttonB" withKeyStatus:gamepad.buttonB.isPressed];
                self->_buttonBPressed = gamepad.buttonB.isPressed;
            }
        }
        
        // X button
        if (gamepad.buttonX == element) {
            if (gamepad.buttonX.isPressed != self->_buttonXPressed) {
                [weakSelf keyboardAndMouseSender:@"buttonX" withKeyStatus:gamepad.buttonX.isPressed];
                self->_buttonXPressed = gamepad.buttonX.isPressed;
            }
        }
        // Y button
        if (gamepad.buttonY == element) {
            if (gamepad.buttonY.isPressed != self->_buttonYPressed) {
                [weakSelf keyboardAndMouseSender:@"buttonY" withKeyStatus:gamepad.buttonY.isPressed];
                self->_buttonYPressed = gamepad.buttonY.isPressed;
            }
        }
        
        // d-pad
        if (gamepad.dpad == element) {
            if (gamepad.dpad.up.isPressed != self->_dpadUpPressed) {
                [weakSelf keyboardAndMouseSender:@"dpad_up" withKeyStatus:gamepad.dpad.up.isPressed];
                self->_dpadUpPressed = gamepad.dpad.up.isPressed;
            }
            if (gamepad.dpad.left.isPressed != self->_dpadLeftPressed) {
                [weakSelf keyboardAndMouseSender:@"dpad_left" withKeyStatus:gamepad.dpad.left.isPressed];
                self->_dpadLeftPressed = gamepad.dpad.left.isPressed;
            }
            if (gamepad.dpad.down.isPressed != self->_dpadDownPressed) {
                [weakSelf keyboardAndMouseSender:@"dpad_down" withKeyStatus:gamepad.dpad.down.isPressed];
                self->_dpadDownPressed = gamepad.dpad.down.isPressed;
            }
            if (gamepad.dpad.right.isPressed != self->_dpadRightPressed) {
                [weakSelf keyboardAndMouseSender:@"dpad_right" withKeyStatus:gamepad.dpad.right.isPressed];
                self->_dpadRightPressed = gamepad.dpad.right.isPressed;
            }
        }
        
        // left stick
        if (gamepad.leftThumbstick == element) {
            
        }
        
        // right stick
        if (gamepad.rightThumbstick == element) {
            NSInteger speed = [weakSelf integerForSetting:@"rightThumbstickSpeed"];
            self->_cursorDirection = CGPointMake(gamepad.rightThumbstick.xAxis.value * speed, -gamepad.rightThumbstick.yAxis.value * speed);
        }
    };
    
    _controller.controllerPausedHandler = ^(GCController *controller){
        NSLog(@"GP message: Paused");
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
      
    NSNumber *code = _SCANCODE_DICT[value];
    int scancode = [code intValue];
    if (scancode < 0) {
        return;
    }
    [self sendExtendedKey:isPressed code:scancode];
}

#pragma mark - Gamepad opperations

- (void) cursorMovementThread {
    if (self->_cursorDirection.x == 0 && self->_cursorDirection.y == 0) {
        return;
    }
    [self.vmInput sendMouseMotion:self->_leftMouseButtonDown point:self->_cursorDirection];
}

#pragma mark - Map for keycode



@end
