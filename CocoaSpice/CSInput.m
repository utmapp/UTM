//
// Copyright © 2019 Halts. All rights reserved.
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
#import <glib.h>
#import <spice-client.h>
#import <spice/protocol.h>

@implementation CSInput {
    SpiceMainChannel        *_main;
    SpiceCursorChannel      *_cursor;
    SpiceInputsChannel      *_inputs;
    
    int                     _mouse_grab_active;
    bool                    _mouse_have_pointer;
    int                     _mouse_last_x;
    int                     _mouse_last_y;
    int                     _mouse_guest_x;
    int                     _mouse_guest_y;
    BOOL                    _show_cursor;
    CGPoint                 _mouse_hotspot;
    CGFloat                 _scroll_delta_y;
    
    const guint16          *_keycode_map;
    size_t                  _keycode_maplen;
    uint32_t                _key_state[512 / 32];
    gboolean                *_activeseq; /* the currently pressed keys */
    gboolean                _seq_pressed;
}

#pragma mark - glib events

static void cs_update_mouse_mode(SpiceChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    enum SpiceMouseMode mouse_mode;
    
    g_object_get(channel, "mouse-mode", &mouse_mode, NULL);
    DISPLAY_DEBUG(self, "mouse mode %u", mouse_mode);
    
    self->_serverModeCursor = (mouse_mode == SPICE_MOUSE_MODE_SERVER);
    
    if (self.serverModeCursor) {
        self->_mouse_guest_x = -1;
        self->_mouse_guest_y = -1;
    }
}

static void cs_cursor_invalidate(CSInput *self)
{
    // TODO: implement this
}

static void cs_cursor_set(SpiceCursorChannel *channel,
                          G_GNUC_UNUSED GParamSpec *pspec,
                          gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    SpiceCursorShape *cursor_shape;
    
    g_object_get(G_OBJECT(channel), "cursor", &cursor_shape, NULL);
    if (G_UNLIKELY(cursor_shape == NULL || cursor_shape->data == NULL)) {
        if (cursor_shape != NULL) {
            g_boxed_free(SPICE_TYPE_CURSOR_SHAPE, cursor_shape);
        }
        return;
    }
    
    cs_cursor_invalidate(self);
    self->_mouse_hotspot.x = cursor_shape->hot_spot_x;
    self->_mouse_hotspot.y = cursor_shape->hot_spot_y;
    // TODO: save cursor_shape->data
    
    if (self->_show_cursor) {
        /* unhide */
        if (self.serverModeCursor) {
            /* keep a hidden cursor, will be shown in cursor_move() */
            self->_show_cursor = YES;
            return;
        }
    }
    
    cs_cursor_invalidate(self);
}

static void cs_cursor_move(SpiceCursorChannel *channel, gint x, gint y, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    cs_cursor_invalidate(self);
    
    self->_mouse_guest_x = x;
    self->_mouse_guest_y = y;
    
    cs_cursor_invalidate(self);
    
    /* apparently we have to restore cursor when "cursor_move" */
    if (self->_show_cursor) {
        // TODO: draw cursor
        self->_show_cursor = NO;
    }
}

static void cs_cursor_hide(SpiceCursorChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    if (!self->_show_cursor) /* then we are already hidden */
        return;
    
    cs_cursor_invalidate(self);
    self->_show_cursor = NO;
}

static void cs_cursor_reset(SpiceCursorChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    DISPLAY_DEBUG(self, "%s",  __FUNCTION__);
    // clear cached cursor
    cs_cursor_invalidate(self);
    self->_show_cursor = NO;
}

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self->_main = SPICE_MAIN_CHANNEL(channel);
        g_signal_connect(channel, "main-mouse-update",
                         G_CALLBACK(cs_update_mouse_mode), GLIB_OBJC_RETAIN(self));
        cs_update_mouse_mode(channel, data);
        return;
    }
    
    if (SPICE_IS_CURSOR_CHANNEL(channel)) {
        gpointer cursor_shape;
        if (chid != self->_channelID)
            return;
        self->_cursor = SPICE_CURSOR_CHANNEL(channel);
        g_signal_connect(channel, "notify::cursor",
                         G_CALLBACK(cs_cursor_set), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "cursor-move",
                         G_CALLBACK(cs_cursor_move), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "cursor-hide",
                         G_CALLBACK(cs_cursor_hide), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "cursor-reset",
                         G_CALLBACK(cs_cursor_reset), GLIB_OBJC_RETAIN(self));
        spice_channel_connect(channel);
        
        g_object_get(G_OBJECT(channel), "cursor", &cursor_shape, NULL);
        if (cursor_shape != NULL) {
            g_boxed_free(SPICE_TYPE_CURSOR_SHAPE, cursor_shape);
            cs_cursor_set(self->_cursor, NULL, (__bridge void *)self);
        }
        return;
    }
    
    if (SPICE_IS_INPUTS_CHANNEL(channel)) {
        self->_inputs = SPICE_INPUTS_CHANNEL(channel);
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
        self->_main = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_update_mouse_mode), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    if (SPICE_IS_CURSOR_CHANNEL(channel)) {
        if (chid != self->_channelID)
            return;
        self->_cursor = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_set), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_move), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_hide), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_reset), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    if (SPICE_IS_INPUTS_CHANNEL(channel)) {
        self->_inputs = NULL;
        return;
    }
    
    return;
}

#pragma mark - Key handling

- (void)sendPause:(SendKeyType)type {
    /* Send proper scancodes. This will send same scancodes
     * as hardware.
     * The 0x21d is a sort of Third-Ctrl while
     * 0x45 is the NumLock.
     */
    if (type == SEND_KEY_PRESS) {
        spice_inputs_channel_key_press(_inputs, 0x21d);
        spice_inputs_channel_key_press(_inputs, 0x45);
    } else {
        spice_inputs_channel_key_release(_inputs, 0x21d);
        spice_inputs_channel_key_release(_inputs, 0x45);
    }
}

- (void)sendKey:(SendKeyType)type code:(int)scancode {
    uint32_t i, b, m;
    
    g_return_if_fail(scancode != 0);
    
    if (!self->_inputs)
        return;
    
    if (self.disableInputs)
        return;
    
    i = scancode / 32;
    b = scancode % 32;
    m = (1u << b);
    g_return_if_fail(i < SPICE_N_ELEMENTS(self->_key_state));
    
    switch (type) {
        case SEND_KEY_PRESS:
            spice_inputs_channel_key_press(self->_inputs, scancode);
            
            self->_key_state[i] |= m;
            break;
            
        case SEND_KEY_RELEASE:
            if (!(self->_key_state[i] & m))
                break;
            
            
            spice_inputs_channel_key_release(self->_inputs, scancode);
            
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
                [self sendKey:SEND_KEY_RELEASE code:scancode];
            }
        }
    }
}

#pragma mark - Mouse handling

static int cs_button_mask_to_spice(SendButtonType button)
{
    int spice = 0;
    
    if (button & SEND_BUTTON_LEFT)
        spice = SPICE_MOUSE_BUTTON_MASK_LEFT;
    if (button & SEND_BUTTON_MIDDLE)
        spice = SPICE_MOUSE_BUTTON_MASK_MIDDLE;
    if (button & SEND_BUTTON_RIGHT)
        spice = SPICE_MOUSE_BUTTON_MASK_RIGHT;
    return spice;
}

static int cs_button_to_spice(SendButtonType button)
{
    int spice = 0;
    
    if (button & SEND_BUTTON_LEFT)
        spice = SPICE_MOUSE_BUTTON_LEFT;
    if (button & SEND_BUTTON_MIDDLE)
        spice = SPICE_MOUSE_BUTTON_MIDDLE;
    if (button & SEND_BUTTON_RIGHT)
        spice = SPICE_MOUSE_BUTTON_RIGHT;
    return spice;
}

- (void)sendMouseMotion:(SendButtonType)button x:(CGFloat)x y:(CGFloat)y {
    if (!self->_inputs)
        return;
    if (self.disableInputs)
        return;
    
    x = floor(x * self.scale);
    y = floor(y * self.scale);
    
    if (self.serverModeCursor) {
        gint dx = self->_mouse_last_x != -1 ? x - self->_mouse_last_x : 0;
        gint dy = self->_mouse_last_y != -1 ? y - self->_mouse_last_y : 0;
        
        spice_inputs_channel_motion(self->_inputs, dx, dy,
                                    cs_button_mask_to_spice(button));
        
        self->_mouse_last_x = x;
        self->_mouse_last_y = y;
    } else {
        spice_inputs_channel_position(self->_inputs, x, y, (int)self.monitorID,
                                      cs_button_mask_to_spice(button));
    }
}

- (void)sendMouseScroll:(SendScrollType)type button:(SendButtonType)button dy:(CGFloat)dy {
    gint button_state = cs_button_mask_to_spice(button);
    
    DISPLAY_DEBUG(self, "%s", __FUNCTION__);
    
    if (!self->_inputs)
        return;
    if (self.disableInputs)
        return;
    
    switch (type) {
        case SEND_SCROLL_UP:
            spice_inputs_channel_button_press(self->_inputs, SPICE_MOUSE_BUTTON_UP, button_state);
            spice_inputs_channel_button_release(self->_inputs, SPICE_MOUSE_BUTTON_UP, button_state);
            break;
        case SEND_SCROLL_DOWN:
            spice_inputs_channel_button_press(self->_inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
            spice_inputs_channel_button_release(self->_inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
            break;
        case SEND_SCROLL_SMOOTH:
            self->_scroll_delta_y += dy;
            while (ABS(self->_scroll_delta_y) >= 1) {
                if (self->_scroll_delta_y < 0) {
                    spice_inputs_channel_button_press(self->_inputs, SPICE_MOUSE_BUTTON_UP, button_state);
                    spice_inputs_channel_button_release(self->_inputs, SPICE_MOUSE_BUTTON_UP, button_state);
                    self->_scroll_delta_y += 1;
                } else {
                    spice_inputs_channel_button_press(self->_inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
                    spice_inputs_channel_button_release(self->_inputs, SPICE_MOUSE_BUTTON_DOWN, button_state);
                    self->_scroll_delta_y -= 1;
                }
            }
            break;
        default:
            DISPLAY_DEBUG(self, "unsupported scroll direction");
    }
}

- (void)sendMouseButton:(SendButtonType)button pressed:(BOOL)pressed x:(CGFloat)x y:(CGFloat)y {
    DISPLAY_DEBUG(self, "%s %s: button %u", __FUNCTION__,
                  pressed ? "press" : "release",
                  (unsigned int)button);
    
    if (self.disableInputs)
        return;
    
    x = floor(x * self.scale);
    y = floor(y * self.scale);
    if ((x < 0 || y < 0) &&
        !self.serverModeCursor) {
        /* rule out clicks in outside region */
        return;
    }
    
    if (!self->_inputs)
        return;
    
    if (pressed) {
        spice_inputs_channel_button_press(self->_inputs,
                                          cs_button_to_spice(button),
                                          cs_button_mask_to_spice(button));
    } else {
        spice_inputs_channel_button_release(self->_inputs,
                                            cs_button_to_spice(button),
                                            cs_button_mask_to_spice(button));
    }
}

- (void)mouseMode:(BOOL)server {
    if (server) {
        spice_main_channel_request_mouse_mode(NULL, SPICE_MOUSE_MODE_SERVER);
    } else {
        spice_main_channel_request_mouse_mode(NULL, SPICE_MOUSE_MODE_CLIENT);
    }
}

#pragma mark - Initializers

- (id)init {
    self = [super init];
    if (self) {
        self.scale = 1.0f;
    }
    return self;
}

- (id)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID monitorID:(NSInteger)monitorID {
    self = [self init];
    if (self) {
        GList *list;
        GList *it;
        
        _channelID = channelID;
        _monitorID = monitorID;
        _session = session;
        g_object_ref(session);
        
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(session, "channel-new",
                         G_CALLBACK(cs_channel_new), GLIB_OBJC_RETAIN(self));
        g_signal_connect(session, "channel-destroy",
                         G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RETAIN(self));
        list = spice_session_get_channels(session);
        for (it = g_list_first(list); it != NULL; it = g_list_next(it)) {
            if (!SPICE_IS_DISPLAY_CHANNEL(it->data)) {
                cs_channel_new(session, it->data, (__bridge void *)self);
            }
        }
        g_list_free(list);
    }
    return self;
}

- (void)dealloc {
    if (_cursor) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(_cursor), (__bridge void *)self);
    }
    if (_main) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(_main), (__bridge void *)self);
    }
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(_session);
    _session = NULL;
}

@end
