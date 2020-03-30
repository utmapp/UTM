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
#import <glib.h>
#import <spice-client.h>
#import <spice/protocol.h>
#import "UTMShaderTypes.h"

@interface CSInput ()

@property (nonatomic, readwrite, nullable) SpiceSession *session;
@property (nonatomic, readwrite, assign) NSInteger channelID;
@property (nonatomic, readwrite, assign) NSInteger monitorID;
@property (nonatomic, readwrite, assign) BOOL serverModeCursor;
@property (nonatomic, readwrite, assign) BOOL hasCursor;
@property (nonatomic, readwrite) CGSize cursorSize;

@end

@implementation CSInput {
    SpiceMainChannel        *_main;
    SpiceCursorChannel      *_cursor;
    SpiceInputsChannel      *_inputs;
    
    CGPoint                 _mouse_guest;
    CGFloat                 _scroll_delta_y;
    
    uint32_t                _key_state[512 / 32];
    
    // Drawing cursor
    id<MTLDevice>           _device;
    id<MTLTexture>          _texture;
    id<MTLBuffer>           _vertices;
    NSUInteger              _numVertices;
    dispatch_semaphore_t    _drawLock;
    BOOL                    _cursorHidden;
}

#pragma mark - glib events

static void cs_update_mouse_mode(SpiceChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    enum SpiceMouseMode mouse_mode;
    
    g_object_get(channel, "mouse-mode", &mouse_mode, NULL);
    DISPLAY_DEBUG(self, "mouse mode %u", mouse_mode);
    
    self.serverModeCursor = (mouse_mode == SPICE_MOUSE_MODE_SERVER);
    
    if (self.serverModeCursor) {
        self->_mouse_guest.x = -1;
        self->_mouse_guest.y = -1;
    }
}

static void cs_cursor_invalidate(CSInput *self)
{
    // We implement two different textures so invalidate is not needed
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
    
    CGPoint hotspot = CGPointMake(cursor_shape->hot_spot_x, cursor_shape->hot_spot_y);
    CGSize newSize = CGSizeMake(cursor_shape->width, cursor_shape->height);
    if (!CGSizeEqualToSize(newSize, self.cursorSize)) {
        [self rebuildTexture:newSize center:hotspot];
    }
    [self drawCursor:cursor_shape->data];
    self->_cursorHidden = NO;
    cs_cursor_invalidate(self);
}

static void cs_cursor_move(SpiceCursorChannel *channel, gint x, gint y, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    cs_cursor_invalidate(self); // old pointer buffer
    
    self->_mouse_guest.x = x;
    self->_mouse_guest.y = y;
    
    cs_cursor_invalidate(self); // new pointer buffer
    
    /* apparently we have to restore cursor when "cursor_move" */
    if (self.hasCursor) {
        self->_cursorHidden = NO;
    }
}

static void cs_cursor_hide(SpiceCursorChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    self->_cursorHidden = YES;
    cs_cursor_invalidate(self);
}

static void cs_cursor_reset(SpiceCursorChannel *channel, gpointer data)
{
    CSInput *self = (__bridge CSInput *)data;
    
    DISPLAY_DEBUG(self, "%s",  __FUNCTION__);
    [self destroyTexture];
    cs_cursor_invalidate(self);
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
        if (chid != self.channelID)
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
    
    [self destroyTexture];
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self->_main = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_update_mouse_mode), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    if (SPICE_IS_CURSOR_CHANNEL(channel)) {
        if (chid != self.channelID)
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
        spice |= SPICE_MOUSE_BUTTON_MASK_LEFT;
    if (button & SEND_BUTTON_MIDDLE)
        spice |= SPICE_MOUSE_BUTTON_MASK_MIDDLE;
    if (button & SEND_BUTTON_RIGHT)
        spice |= SPICE_MOUSE_BUTTON_MASK_RIGHT;
    return spice;
}

static int cs_button_to_spice(SendButtonType button)
{
    int spice = 0;
    
    if (button & SEND_BUTTON_LEFT)
        spice |= SPICE_MOUSE_BUTTON_LEFT;
    if (button & SEND_BUTTON_MIDDLE)
        spice |= SPICE_MOUSE_BUTTON_MIDDLE;
    if (button & SEND_BUTTON_RIGHT)
        spice |= SPICE_MOUSE_BUTTON_RIGHT;
    return spice;
}

- (void)sendMouseMotion:(SendButtonType)button point:(CGPoint)point {
    if (!self->_inputs)
        return;
    if (self.disableInputs)
        return;
    
    if (self.serverModeCursor) {
        spice_inputs_channel_motion(self->_inputs, point.x, point.y,
                                    cs_button_mask_to_spice(button));
    } else {
        spice_inputs_channel_position(self->_inputs, point.x, point.y, (int)self.monitorID,
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

- (void)sendMouseButton:(SendButtonType)button pressed:(BOOL)pressed point:(CGPoint)point {
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

- (void)requestMouseMode:(BOOL)server {
    if (server) {
        spice_main_channel_request_mouse_mode(_main, SPICE_MOUSE_MODE_SERVER);
    } else {
        spice_main_channel_request_mouse_mode(_main, SPICE_MOUSE_MODE_CLIENT);
    }
}

- (void)forceCursorPosition:(CGPoint)pos {
    _mouse_guest = pos;
}

#pragma mark - Initializers

- (id)init {
    self = [super init];
    if (self) {
        _drawLock = dispatch_semaphore_create(1);
        self.viewportScale = 1.0f;
        self.viewportOrigin = CGPointMake(0, 0);
    }
    return self;
}

- (id)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID monitorID:(NSInteger)monitorID {
    self = [self init];
    if (self) {
        GList *list;
        GList *it;
        
        self.channelID = channelID;
        self.monitorID = monitorID;
        self.session = session;
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
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.session);
    self.session = NULL;
}

#pragma mark - Drawing Cursor

@synthesize device = _device;
@synthesize drawLock = _drawLock;
@synthesize texture = _texture;
@synthesize numVertices = _numVertices;
@synthesize vertices = _vertices;
@synthesize viewportOrigin;
@synthesize viewportScale;

- (void)rebuildTexture:(CGSize)size center:(CGPoint)hotspot {
    // hotspot is the offset in buffer for the center of the pointer
    if (!_device) {
        NSLog(@"MTL device not ready for cursor draw");
        return;
    }
    dispatch_semaphore_wait(_drawLock, DISPATCH_TIME_FOREVER);
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    // don't worry that that components are reversed, we fix it in shaders
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    textureDescriptor.width = size.width;
    textureDescriptor.height = size.height;
    _texture = [_device newTextureWithDescriptor:textureDescriptor];

    // We flip the y-coordinates because pixman renders flipped
    UTMVertex quadVertices[] =
    {
     // Pixel positions, Texture coordinates
     { { -hotspot.x + size.width, hotspot.y               },  { 1.f, 0.f } },
     { { -hotspot.x             , hotspot.y               },  { 0.f, 0.f } },
     { { -hotspot.x             , hotspot.y - size.height },  { 0.f, 1.f } },
     
     { { -hotspot.x + size.width, hotspot.y               },  { 1.f, 0.f } },
     { { -hotspot.x             , hotspot.y - size.height },  { 0.f, 1.f } },
     { { -hotspot.x + size.width, hotspot.y - size.height },  { 1.f, 1.f } },
    };

    // Create our vertex buffer, and initialize it with our quadVertices array
    _vertices = [_device newBufferWithBytes:quadVertices
                                    length:sizeof(quadVertices)
                                   options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    _numVertices = sizeof(quadVertices) / sizeof(UTMVertex);
    self.cursorSize = size;
    self.hasCursor = YES;
    dispatch_semaphore_signal(_drawLock);
}

- (void)destroyTexture {
    dispatch_semaphore_wait(_drawLock, DISPATCH_TIME_FOREVER);
    _numVertices = 0;
    _vertices = nil;
    _texture = nil;
    self.cursorSize = CGSizeZero;
    self.hasCursor = NO;
    dispatch_semaphore_signal(_drawLock);
}

- (void)drawCursor:(const void *)buffer {
    const NSInteger pixelSize = 4;
    MTLRegion region = {
        { 0, 0 }, // MTLOrigin
        { self.cursorSize.width, self.cursorSize.height, 1} // MTLSize
    };
    dispatch_semaphore_wait(_drawLock, DISPATCH_TIME_FOREVER);
    [_texture replaceRegion:region
                mipmapLevel:0
                  withBytes:buffer
                bytesPerRow:self.cursorSize.width*pixelSize];
    dispatch_semaphore_signal(_drawLock);
}

- (BOOL)visible {
    return !self.inhibitCursor && self.hasCursor && !_cursorHidden;
}

- (CGPoint)viewportOrigin {
    CGPoint point = _mouse_guest;
    point.x -= self.displaySize.width/2;
    point.y -= self.displaySize.height/2;
    point.x *= self.viewportScale;
    point.y *= self.viewportScale;
    return point;
}

@end
