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

#import "TargetConditionals.h"
#import "UTMScreenshot.h"
#import "UTMShaderTypes.h"
#import "CocoaSpice.h"
#import "UTMLogging.h"
#import <glib.h>
#import <spice-client.h>
#import <spice/protocol.h>

#ifdef DISPLAY_DEBUG
#undef DISPLAY_DEBUG
#endif
#define DISPLAY_DEBUG(display, fmt, ...) \
    SPICE_DEBUG("%d:%d " fmt, \
                (int)display.channelID, \
                (int)display.monitorID, \
                ## __VA_ARGS__)

@interface CSDisplayMetal ()

@property (nonatomic, readwrite, nullable) SpiceSession *session;
@property (nonatomic, readwrite, assign) NSInteger channelID;
@property (nonatomic, readwrite, assign) NSInteger monitorID;
@property (nonatomic, nullable) SpiceDisplayChannel *display;
@property (nonatomic, nullable) SpiceMainChannel *main;
@property (nonatomic, nullable) SpiceCursorChannel *cursor;
@property (nonatomic, readwrite) CGPoint cursorHotspot;
@property (nonatomic, readwrite) BOOL cursorHidden;
@property (nonatomic, readwrite) BOOL hasCursor;

// UTMRenderSource properties
@property (nonatomic, readwrite) dispatch_semaphore_t drawLock;
@property (nonatomic, nullable, readwrite) id<MTLTexture> displayTexture;
@property (nonatomic, nullable, readwrite) id<MTLTexture> cursorTexture;
@property (nonatomic, readwrite) NSUInteger displayNumVertices;
@property (nonatomic, readwrite) NSUInteger cursorNumVertices;
@property (nonatomic, nullable, readwrite) id<MTLBuffer> displayVertices;
@property (nonatomic, nullable, readwrite) id<MTLBuffer> cursorVertices;

@end

@implementation CSDisplayMetal {
    //gint                    _mark;
    gint                    _canvasFormat;
    gint                    _canvasStride;
    const void              *_canvasData;
    CGRect                  _canvasArea;
    CGRect                  _visibleArea;
    GWeakRef                _overlay_weak_ref;
    CGPoint                 _mouse_guest;
}

#pragma mark - Display events

static void cs_primary_create(SpiceChannel *channel, gint format,
                           gint width, gint height, gint stride,
                           gint shmid, gpointer imgdata, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    
    g_assert(format == SPICE_SURFACE_FMT_32_xRGB || format == SPICE_SURFACE_FMT_16_555);
    dispatch_semaphore_wait(self->_drawLock, DISPATCH_TIME_FOREVER);
    self->_canvasArea = CGRectMake(0, 0, width, height);
    self->_canvasFormat = format;
    self->_canvasStride = stride;
    self->_canvasData = imgdata;
    dispatch_semaphore_signal(self->_drawLock);
    
    cs_update_monitor_area(channel, NULL, data);
}

static void cs_primary_destroy(SpiceDisplayChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    self.ready = NO;
    
    dispatch_semaphore_wait(self->_drawLock, DISPATCH_TIME_FOREVER);
    self->_canvasArea = CGRectZero;
    self->_canvasFormat = 0;
    self->_canvasStride = 0;
    self->_canvasData = NULL;
    dispatch_semaphore_signal(self->_drawLock);
}

static void cs_invalidate(SpiceChannel *channel,
                       gint x, gint y, gint w, gint h, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    CGRect rect = CGRectIntersection(CGRectMake(x, y, w, h), self->_visibleArea);
    if (!CGRectIsEmpty(rect)) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [self drawRegion:rect];
        });
    }
}

static void cs_mark(SpiceChannel *channel, gint mark, gpointer data) {
    //CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    //@synchronized (self) {
    //    self->_mark = mark; // currently this does nothing for us
    //}
}

static gboolean cs_set_overlay(SpiceChannel *channel, void* pipeline_ptr, gpointer data) {
    //FIXME: implement overlay
    //CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    return false;
}

static void cs_update_monitor_area(SpiceChannel *channel, GParamSpec *pspec, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    SpiceDisplayMonitorConfig *cfg, *c = NULL;
    GArray *monitors = NULL;
    int i;
    
    DISPLAY_DEBUG(self, "update monitor area");
    if (self.monitorID < 0)
        goto whole;
    
    g_object_get(self.display, "monitors", &monitors, NULL);
    for (i = 0; monitors != NULL && i < monitors->len; i++) {
        cfg = &g_array_index(monitors, SpiceDisplayMonitorConfig, i);
        if (cfg->id == self.monitorID) {
            c = cfg;
            break;
        }
    }
    if (c == NULL) {
        DISPLAY_DEBUG(self, "update monitor: no monitor %d", (int)self.monitorID);
        self.ready = NO;
        if (spice_channel_test_capability(SPICE_CHANNEL(self.display),
                                          SPICE_DISPLAY_CAP_MONITORS_CONFIG)) {
            DISPLAY_DEBUG(self, "waiting until MonitorsConfig is received");
            g_clear_pointer(&monitors, g_array_unref);
            return;
        }
        goto whole;
    }
    
    if (c->surface_id != 0) {
        g_warning("FIXME: only support monitor config with primary surface 0, "
                  "but given config surface %u", c->surface_id);
        goto whole;
    }
    
    /* If only one head on this monitor, update the whole area */
    if (monitors->len == 1) {
        [self updateVisibleAreaWithRect:CGRectMake(0, 0, c->width, c->height)];
    } else {
        [self updateVisibleAreaWithRect:CGRectMake(c->x, c->y, c->width, c->height)];
    }
    self.ready = YES;
    g_clear_pointer(&monitors, g_array_unref);
    return;
    
whole:
    g_clear_pointer(&monitors, g_array_unref);
    /* by display whole surface */
    [self updateVisibleAreaWithRect:self->_canvasArea];
    self.ready = YES;
}

#pragma mark - Cursor events

static void cs_update_mouse_mode(SpiceChannel *channel, gpointer data)
{
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    enum SpiceMouseMode mouse_mode;
    
    g_object_get(channel, "mouse-mode", &mouse_mode, NULL);
    DISPLAY_DEBUG(self, "mouse mode %u", mouse_mode);
    
    if (mouse_mode == SPICE_MOUSE_MODE_SERVER) {
        self->_mouse_guest.x = -1;
        self->_mouse_guest.y = -1;
    }
}

static void cs_cursor_invalidate(CSDisplayMetal *self)
{
    // We implement two different textures so invalidate is not needed
}

static void cs_cursor_set(SpiceCursorChannel *channel,
                          G_GNUC_UNUSED GParamSpec *pspec,
                          gpointer data)
{
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
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
    if (!CGSizeEqualToSize(newSize, self.cursorSize) || !CGPointEqualToPoint(hotspot, self.cursorHotspot)) {
        [self rebuildCursorWithSize:newSize center:hotspot];
    }
    [self drawCursor:cursor_shape->data];
    self.cursorHidden = NO;
    cs_cursor_invalidate(self);
}

static void cs_cursor_move(SpiceCursorChannel *channel, gint x, gint y, gpointer data)
{
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    
    cs_cursor_invalidate(self); // old pointer buffer
    
    self->_mouse_guest.x = x;
    self->_mouse_guest.y = y;
    
    cs_cursor_invalidate(self); // new pointer buffer
    
    /* apparently we have to restore cursor when "cursor_move" */
    if (self.hasCursor) {
        self.cursorHidden = NO;
    }
}

static void cs_cursor_hide(SpiceCursorChannel *channel, gpointer data)
{
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    
    self.cursorHidden = YES;
    cs_cursor_invalidate(self);
}

static void cs_cursor_reset(SpiceCursorChannel *channel, gpointer data)
{
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    
    DISPLAY_DEBUG(self, "%s",  __FUNCTION__);
    [self destroyCursor];
    cs_cursor_invalidate(self);
}

#pragma mark - Channel events

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    gint channel_id;
    
    g_object_get(channel, "channel-id", &channel_id, NULL);
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        SpiceDisplayPrimary primary;
        if (channel_id != self.channelID) {
            return;
        }
        self.display = SPICE_DISPLAY_CHANNEL(channel);
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(channel, "display-primary-create",
                         G_CALLBACK(cs_primary_create), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "display-primary-destroy",
                         G_CALLBACK(cs_primary_destroy), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "display-invalidate",
                         G_CALLBACK(cs_invalidate), GLIB_OBJC_RETAIN(self));
        g_signal_connect_after(channel, "display-mark",
                               G_CALLBACK(cs_mark), GLIB_OBJC_RETAIN(self));
        g_signal_connect_after(channel, "notify::monitors",
                               G_CALLBACK(cs_update_monitor_area), GLIB_OBJC_RETAIN(self));
        g_signal_connect_after(channel, "gst-video-overlay",
                               G_CALLBACK(cs_set_overlay), GLIB_OBJC_RETAIN(self));
        if (spice_display_channel_get_primary(channel, 0, &primary)) {
            cs_primary_create(channel, primary.format, primary.width, primary.height,
                              primary.stride, primary.shmid, primary.data, (__bridge void *)self);
            cs_mark(channel, primary.marked, (__bridge void *)self);
        }
        
        spice_channel_connect(channel);
        return;
    }
    
    if (SPICE_IS_CURSOR_CHANNEL(channel)) {
        gpointer cursor_shape;
        if (channel_id != self.channelID) {
            return;
        }
        self.cursor = SPICE_CURSOR_CHANNEL(channel);
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
            cs_cursor_set(self.cursor, NULL, (__bridge void *)self);
        }
        return;
    }
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self.main = SPICE_MAIN_CHANNEL(channel);
        g_signal_connect(channel, "main-mouse-update",
                         G_CALLBACK(cs_update_mouse_mode), GLIB_OBJC_RETAIN(self));
        cs_update_mouse_mode(channel, data);
        return;
    }
}

static void cs_channel_destroy(SpiceSession *s, SpiceChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    gint channel_id;
    
    g_object_get(channel, "channel-id", &channel_id, NULL);
    DISPLAY_DEBUG(self, "channel_destroy %d", channel_id);
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        if (channel_id != self.channelID) {
            return;
        }
        cs_primary_destroy(self.display, (__bridge void *)self);
        self.display = NULL;
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_primary_create), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_primary_destroy), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_invalidate), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_mark), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_update_monitor_area), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_set_overlay), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    if (SPICE_IS_CURSOR_CHANNEL(channel)) {
        if (channel_id != self.channelID) {
            return;
        }
        self.cursor = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_set), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_move), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_hide), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_cursor_reset), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        self.main = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_update_mouse_mode), GLIB_OBJC_RELEASE(self));
        return;
    }
    
    return;
}

- (void)setDevice:(id<MTLDevice>)device {
    _device = device;
    [self rebuildDisplayTexture];
    [self rebuildDisplayVertices];
}

- (UTMScreenshot *)screenshot {
    CGImageRef img;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    
    dispatch_semaphore_wait(_drawLock, DISPATCH_TIME_FOREVER); // TODO: separate read lock so we don't block texture copy
    if (_canvasData) { // may be destroyed at this point
        CGDataProviderRef dataProviderRef = CGDataProviderCreateWithData(NULL, _canvasData, _canvasStride * _canvasArea.size.height, nil);
        img = CGImageCreate(_canvasArea.size.width, _canvasArea.size.height, 8, 32, _canvasStride, colorSpaceRef, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, dataProviderRef, NULL, NO, kCGRenderingIntentDefault);
        CGDataProviderRelease(dataProviderRef);
    } else {
        img = NULL;
    }
    dispatch_semaphore_signal(_drawLock);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    if (img) {
#if TARGET_OS_IPHONE
        UIImage *uiimg = [UIImage imageWithCGImage:img];
#else
        NSImage *uiimg = [[NSImage alloc] initWithCGImage:img size:NSZeroSize];
#endif
        CGImageRelease(img);
        return [[UTMScreenshot alloc] initWithImage:uiimg];
    } else {
        return UTMScreenshot.none;
    }
}

#pragma mark - Methods

- (instancetype)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID monitorID:(NSInteger)monitorID {
    if (self = [super init]) {
        GList *list;
        GList *it;
        
        self.drawLock = dispatch_semaphore_create(1);
        self.viewportScale = 1.0f;
        self.viewportOrigin = CGPointMake(0, 0);
        self.channelID = channelID;
        self.monitorID = monitorID;
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

- (instancetype)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID {
    return [self initWithSession:session channelID:channelID monitorID:0];
}

- (void)dealloc {
    if (self.display) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(self.display), (__bridge void *)self);
    }
    if (_cursor) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(_cursor), (__bridge void *)self);
    }
    UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.session);
    self.session = NULL;
}

- (void)updateVisibleAreaWithRect:(CGRect)rect {
    CGRect visible = CGRectIntersection(_canvasArea, rect);
    if (CGRectIsNull(visible)) {
        DISPLAY_DEBUG(self, "The monitor area is not intersecting primary surface");
        self.ready = NO;
        _visibleArea = CGRectZero;
    } else {
        _visibleArea = visible;
    }
    self.displaySize = _visibleArea.size;
    [self rebuildDisplayTexture];
    [self rebuildDisplayVertices];
}

- (void)rebuildDisplayTexture {
    if (CGRectIsEmpty(_canvasArea) || !self.device) {
        return;
    }
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    // don't worry that that components are reversed, we fix it in shaders
    textureDescriptor.pixelFormat = (_canvasFormat == SPICE_SURFACE_FMT_32_xRGB) ? MTLPixelFormatBGRA8Unorm : (MTLPixelFormat)43;// FIXME: MTLPixelFormatBGR5A1Unorm is supposed to be available.
    textureDescriptor.width = _visibleArea.size.width;
    textureDescriptor.height = _visibleArea.size.height;
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    self.displayTexture = [self.device newTextureWithDescriptor:textureDescriptor];
    dispatch_semaphore_signal(self.drawLock);
    [self drawRegion:_visibleArea];
}

- (void)rebuildDisplayVertices {
    // We flip the y-coordinates because pixman renders flipped
    UTMVertex quadVertices[] =
    {
        // Pixel positions, Texture coordinates
        { {  _visibleArea.size.width/2,   _visibleArea.size.height/2 },  { 1.f, 0.f } },
        { { -_visibleArea.size.width/2,   _visibleArea.size.height/2 },  { 0.f, 0.f } },
        { { -_visibleArea.size.width/2,  -_visibleArea.size.height/2 },  { 0.f, 1.f } },
        
        { {  _visibleArea.size.width/2,   _visibleArea.size.height/2 },  { 1.f, 0.f } },
        { { -_visibleArea.size.width/2,  -_visibleArea.size.height/2 },  { 0.f, 1.f } },
        { {  _visibleArea.size.width/2,  -_visibleArea.size.height/2 },  { 1.f, 1.f } },
    };
    
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    // Create our vertex buffer, and initialize it with our quadVertices array
    self.displayVertices = [self.device newBufferWithBytes:quadVertices
                                                    length:sizeof(quadVertices)
                                                   options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    self.displayNumVertices = sizeof(quadVertices) / sizeof(UTMVertex);
    dispatch_semaphore_signal(self.drawLock);
}

- (void)drawRegion:(CGRect)rect {
    NSInteger pixelSize = (_canvasFormat == SPICE_SURFACE_FMT_32_xRGB) ? 4 : 2;
    // create draw region
    MTLRegion region = {
        { rect.origin.x-_visibleArea.origin.x, rect.origin.y-_visibleArea.origin.y, 0 }, // MTLOrigin
        { rect.size.width, rect.size.height, 1} // MTLSize
    };
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    if (_canvasData != NULL) { // canvas may be destroyed by this time
        [self.displayTexture replaceRegion:region
                               mipmapLevel:0
                                 withBytes:(const char *)_canvasData + (NSUInteger)(rect.origin.y*_canvasStride + rect.origin.x*pixelSize)
                               bytesPerRow:_canvasStride];
    }
    dispatch_semaphore_signal(self.drawLock);
}

- (BOOL)visible {
    return self.ready;
}

- (void)requestResolution:(CGRect)bounds {
    if (!self.main) {
        UTMLog(@"ignoring change resolution because main channel not found");
        return;
    }
    spice_main_channel_update_display_enabled(self.main, (int)self.monitorID, TRUE, FALSE);
    spice_main_channel_update_display(self.main,
                                      (int)self.monitorID,
                                      bounds.origin.x,
                                      bounds.origin.y,
                                      bounds.size.width,
                                      bounds.size.height,
                                      TRUE);
    spice_main_channel_send_monitor_config(self.main);
}

#pragma mark - Cursor drawing

- (void)rebuildCursorWithSize:(CGSize)size center:(CGPoint)hotspot {
    // hotspot is the offset in buffer for the center of the pointer
    if (!self.device) {
        UTMLog(@"MTL device not ready for cursor draw");
        return;
    }
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    // don't worry that that components are reversed, we fix it in shaders
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    textureDescriptor.width = size.width;
    textureDescriptor.height = size.height;
    self.cursorTexture = [self.device newTextureWithDescriptor:textureDescriptor];

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
    self.cursorVertices = [self.device newBufferWithBytes:quadVertices
                                                   length:sizeof(quadVertices)
                                                  options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    self.cursorNumVertices = sizeof(quadVertices) / sizeof(UTMVertex);
    self.cursorSize = size;
    self.cursorHotspot = hotspot;
    self.hasCursor = YES;
    dispatch_semaphore_signal(self.drawLock);
}

- (void)destroyCursor {
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    self.cursorNumVertices = 0;
    self.cursorVertices = nil;
    self.cursorTexture = nil;
    self.cursorSize = CGSizeZero;
    self.cursorHotspot = CGPointZero;
    self.hasCursor = NO;
    dispatch_semaphore_signal(self.drawLock);
}

- (void)drawCursor:(const void *)buffer {
    const NSInteger pixelSize = 4;
    MTLRegion region = {
        { 0, 0 }, // MTLOrigin
        { self.cursorSize.width, self.cursorSize.height, 1} // MTLSize
    };
    dispatch_semaphore_wait(self.drawLock, DISPATCH_TIME_FOREVER);
    [self.cursorTexture replaceRegion:region
                          mipmapLevel:0
                            withBytes:buffer
                          bytesPerRow:self.cursorSize.width*pixelSize];
    dispatch_semaphore_signal(self.drawLock);
}

- (BOOL)cursorVisible {
    return !self.inhibitCursor && self.hasCursor && !self.cursorHidden;
}

- (CGPoint)cursorOrigin {
    CGPoint point = _mouse_guest;
    point.x -= self.displaySize.width/2;
    point.y -= self.displaySize.height/2;
    point.x *= self.viewportScale;
    point.y *= self.viewportScale;
    return point;
}

- (void)forceCursorPosition:(CGPoint)pos {
    _mouse_guest = pos;
}

@end
