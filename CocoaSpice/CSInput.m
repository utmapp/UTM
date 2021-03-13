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

#import "CSInput.h"
#import "CocoaSpice.h"
#import "UTMLogging.h"
#import <glib.h>
#import <spice-client.h>
#import <spice/protocol.h>
#import "UTMShaderTypes.h"

@interface CSInput ()

@property (nonatomic, nullable) SpiceSession *session;
@property (nonatomic, nullable) SpiceMainChannel *main;
@property (nonatomic, nullable) SpiceInputsChannel *inputs;

@end

@implementation CSInput {
    CGFloat                 _scroll_delta_y;
    
    uint32_t                _key_state[512 / 32];
}

#pragma mark - Channel events

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self.main = SPICE_MAIN_CHANNEL(channel);
        return;
    }
    
    if (SPICE_IS_INPUTS_CHANNEL(channel)) {
        self.inputs = SPICE_INPUTS_CHANNEL(channel);
        spice_channel_connect(channel);
        return;
    }
}

static void cs_channel_destroy(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    DISPLAY_DEBUG(self, "channel_destroy %d", chid);
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self.main = NULL;
        return;
    }
    
    if (SPICE_IS_INPUTS_CHANNEL(channel)) {
        self.inputs = NULL;
        return;
    }
    
    return;
}

#pragma mark - Properties

- (BOOL)serverModeCursor {
    enum SpiceMouseMode mouse_mode;
    g_object_get(self.main, "mouse-mode", &mouse_mode, NULL);
    return (mouse_mode == SPICE_MOUSE_MODE_SERVER);
}

#pragma mark - Key handling

- (void)sendPause:(CSInputKey)type {
    /* Send proper scancodes. This will send same scancodes
     * as hardware.
     * The 0x21d is a sort of Third-Ctrl while
     * 0x45 is the NumLock.
     */
    if (type == kCSInputKeyPress) {
        spice_inputs_channel_key_press(self.inputs, 0x21d);
        spice_inputs_channel_key_press(self.inputs, 0x45);
    } else {
        spice_inputs_channel_key_release(self.inputs, 0x21d);
        spice_inputs_channel_key_release(self.inputs, 0x45);
    }
}

- (void)sendKey:(CSInputKey)type code:(int)scancode {
    uint32_t i, b, m;
    
    g_return_if_fail(scancode != 0);
    
    if (!self.inputs)
        return;
    
    if (self.disableInputs)
        return;
    
    i = scancode / 32;
    b = scancode % 32;
    m = (1u << b);
    g_return_if_fail(i < SPICE_N_ELEMENTS(self->_key_state));
    
    switch (type) {
        case kCSInputKeyPress:
            spice_inputs_channel_key_press(self.inputs, scancode);
            
            self->_key_state[i] |= m;
            break;
            
        case kCSInputKeyRelease:
            if (!(self->_key_state[i] & m))
                break;
            
            
            spice_inputs_channel_key_release(self.inputs, scancode);
            
            self->_key_state[i] &= ~m;
            break;
            
        default:
            g_warn_if_reached();
    }
}

- (void)releaseKeys {
    uint32_t i, b;
    
    DISPLAY_DEBUG(self, "%s", __FUNCTION__);
    for (i = 0; i < SPICE_N_ELEMENTS(self->_key_state); i++) {
        if (!self->_key_state[i]) {
            continue;
        }
        for (b = 0; b < 32; b++) {
            unsigned int scancode = i * 32 + b;
            if (scancode != 0) {
                [self sendKey:kCSInputKeyRelease code:scancode];
            }
        }
    }
}

#pragma mark - Mouse handling

static int cs_button_mask_to_spice(CSInputButton button)
{
    int spice = 0;
    
    if (button & kCSInputButtonLeft)
        spice |= SPICE_MOUSE_BUTTON_MASK_LEFT;
    if (button & kCSInputButtonMiddle)
        spice |= SPICE_MOUSE_BUTTON_MASK_MIDDLE;
    if (button & kCSInputButtonRight)
        spice |= SPICE_MOUSE_BUTTON_MASK_RIGHT;
    return spice;
}

static int cs_button_to_spice(CSInputButton button)
{
    int spice = 0;
    
    if (button & kCSInputButtonLeft)
        spice |= SPICE_MOUSE_BUTTON_LEFT;
    if (button & kCSInputButtonMiddle)
        spice |= SPICE_MOUSE_BUTTON_MIDDLE;
    if (button & kCSInputButtonRight)
        spice |= SPICE_MOUSE_BUTTON_RIGHT;
    return spice;
}

- (void)sendMouseMotion:(CSInputButton)button point:(CGPoint)point forMonitorID:(NSInteger)monitorID {
    if (!self.inputs)
        return;
    if (self.disableInputs)
        return;
    
    if (self.serverModeCursor) {
        spice_inputs_channel_motion(self.inputs, point.x, point.y,
                                    cs_button_mask_to_spice(button));
    } else {
        spice_inputs_channel_position(self.inputs, point.x, point.y, (int)monitorID,
                                      cs_button_mask_to_spice(button));
    }
}

// FIXME: remove this when multiple displays are implemented properly
- (void)sendMouseMotion:(CSInputButton)button point:(CGPoint)point {
    [self sendMouseMotion:button point:point forMonitorID:0];
}

- (void)sendMouseScroll:(CSInputScroll)type button:(CSInputButton)button dy:(CGFloat)dy {
    gint button_state = cs_button_mask_to_spice(button);
    
    DISPLAY_DEBUG(self, "%s", __FUNCTION__);
    
    if (!self.inputs)
        return;
    if (self.disableInputs)
        return;
    
    switch (type) {
        case kCSInputScrollUp:
            spice_inputs_channel_button_press(self.inputs, SPICE_MOUSE_BUTTON_UP, button_state);
            spice_inputs_channel_button_release(self.inputs, SPICE_MOUSE_BUTTON_UP, button_state);
            break;
        case kCSInputScrollDown:
            spice_inputs_channel_button_press(self.inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
            spice_inputs_channel_button_release(self.inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
            break;
        case kCSInputScrollSmooth:
            self->_scroll_delta_y += dy;
            while (ABS(self->_scroll_delta_y) >= 1) {
                if (self->_scroll_delta_y < 0) {
                    spice_inputs_channel_button_press(self.inputs, SPICE_MOUSE_BUTTON_UP, button_state);
                    spice_inputs_channel_button_release(self.inputs, SPICE_MOUSE_BUTTON_UP, button_state);
                    self->_scroll_delta_y += 1;
                } else {
                    spice_inputs_channel_button_press(self.inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
                    spice_inputs_channel_button_release(self.inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
                    self->_scroll_delta_y -= 1;
                }
            }
            break;
        default:
            DISPLAY_DEBUG(self, "unsupported scroll direction");
    }
}

- (void)sendMouseButton:(CSInputButton)button pressed:(BOOL)pressed point:(CGPoint)point {
    DISPLAY_DEBUG(self, "%s %s: button %u", __FUNCTION__,
                  pressed ? "press" : "release",
                  (unsigned int)button);
    
    if (self.disableInputs)
        return;
    
    if ((point.x < 0 || point.y < 0) &&
        !self.serverModeCursor) {
        /* rule out clicks in outside region */
        return;
    }
    
    if (!self.inputs)
        return;
    
    if (pressed) {
        spice_inputs_channel_button_press(self.inputs,
                                          cs_button_to_spice(button),
                                          cs_button_mask_to_spice(button));
    } else {
        spice_inputs_channel_button_release(self.inputs,
                                            cs_button_to_spice(button),
                                            cs_button_mask_to_spice(button));
    }
}

- (void)requestMouseMode:(BOOL)server {
    if (server) {
        spice_main_channel_request_mouse_mode(self.main, SPICE_MOUSE_MODE_SERVER);
    } else {
        spice_main_channel_request_mouse_mode(self.main, SPICE_MOUSE_MODE_CLIENT);
    }
}

#pragma mark - Initializers

- (instancetype)initWithSession:(SpiceSession *)session {
    self = [super init];
    if (self) {
        GList *list;
        GList *it;
        
        self.session = session;
        g_object_ref(session);
        
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(session, "channel-new",
                         G_CALLBACK(cs_channel_new), GLIB_OBJC_RETAIN(self));
        g_signal_connect(session, "channel-destroy",
                         G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RETAIN(self));
        list = spice_session_get_channels(session);
        for (it = g_list_first(list); it != NULL; it = g_list_next(it)) {
            if (SPICE_IS_MAIN_CHANNEL(it->data)) {
                cs_channel_new(session, it->data, (__bridge void *)self);
                break;
            }
        }
        for (it = g_list_first(list); it != NULL; it = g_list_next(it)) {
            if (!SPICE_IS_MAIN_CHANNEL(it->data))
                cs_channel_new(session, it->data, (__bridge void *)self);
        }
        g_list_free(list);
    }
    return self;
}

- (void)dealloc {
    if (self.main) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(self.main), (__bridge void *)self);
    }
    UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.session);
    self.session = NULL;
}

@end
