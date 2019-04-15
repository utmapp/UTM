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

#import "CSDisplayMetal.h"
#import <glib.h>
#import <spice-client.h>
#import <spice/protocol.h>

#define DISPLAY_DEBUG(display, fmt, ...) \
    SPICE_DEBUG("%d:%d " fmt, \
                (int)display.channelID, \
                (int)display.monitorID, \
                ## __VA_ARGS__)

@implementation CSDisplayMetal {
    SpiceDisplayChannel     *_display;
    
    gint                    _mark;
    gint                    _canvasFormat;
    gint                    _canvasStride;
    void                    *_canvasData;
    CGRect                  _canvasArea;
    CGRect                  _visibleArea;
    GWeakRef _overlay_weak_ref;
    
    BOOL                    _sigsconnected;
}

static void cs_primary_create(SpiceChannel *channel, gint format,
                           gint width, gint height, gint stride,
                           gint shmid, gpointer imgdata, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    
    self->_canvasArea = CGRectMake(0, 0, width, height);
    self->_canvasFormat = format;
    self->_canvasStride = stride;
    self->_canvasData = imgdata;
    
    cs_update_monitor_area(channel, data);
}

static void cs_primary_destroy(SpiceDisplayChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    self.ready = NO;
    self->_canvasArea = CGRectZero;
    self->_canvasFormat = 0;
    self->_canvasStride = 0;
    self->_canvasData = NULL;
}

static void cs_invalidate(SpiceChannel *channel,
                       gint x, gint y, gint w, gint h, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
#warning Unimplemented
}

static void cs_mark(SpiceChannel *channel, gint mark, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    self->_mark = mark;
}

static gboolean cs_set_overlay(SpiceChannel *channel, void* pipeline_ptr, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
#warning Unimplemented
    return false;
}

static void cs_update_monitor_area(SpiceChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    SpiceDisplayMonitorConfig *cfg, *c = NULL;
    GArray *monitors = NULL;
    int i;
    
    DISPLAY_DEBUG(self, "update monitor area");
    if (self.monitorID < 0)
        goto whole;
    
    g_object_get(self->_display, "monitors", &monitors, NULL);
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
        if (spice_channel_test_capability(SPICE_CHANNEL(self->_display),
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
    g_clear_pointer(&monitors, g_array_unref);
    return;
    
whole:
    g_clear_pointer(&monitors, g_array_unref);
    /* by display whole surface */
    [self updateVisibleAreaWithRect:self->_canvasArea];
    self.ready = YES;
}

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data) {
    CSDisplayMetal *self = (__bridge CSDisplayMetal *)data;
    gint channel_id;
    
    g_object_get(channel, "channel-id", &channel_id, NULL);
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        SpiceDisplayPrimary primary;
        if (channel_id != self.channelID) {
            return;
        }
        self->_display = SPICE_DISPLAY_CHANNEL(channel);
        NSCAssert(!self->_sigsconnected, @"Signals already connected!");
        g_signal_connect(channel, "display-primary-create",
                         G_CALLBACK(cs_primary_create), (__bridge void *)self);
        g_signal_connect(channel, "display-primary-destroy",
                         G_CALLBACK(cs_primary_destroy), (__bridge void *)self);
        g_signal_connect(channel, "display-invalidate",
                         G_CALLBACK(cs_invalidate), (__bridge void *)self);
        g_signal_connect_after(channel, "display-mark",
                               G_CALLBACK(cs_mark), (__bridge void *)self);
        g_signal_connect_after(channel, "notify::monitors",
                               G_CALLBACK(cs_update_monitor_area), (__bridge void *)self);
        g_signal_connect_after(channel, "gst-video-overlay",
                               G_CALLBACK(cs_set_overlay), (__bridge void *)self);
        self->_sigsconnected = YES;
        if (spice_display_channel_get_primary(channel, 0, &primary)) {
            cs_primary_create(channel, primary.format, primary.width, primary.height,
                              primary.stride, primary.shmid, primary.data, (__bridge void *)self);
            cs_mark(channel, primary.marked, (__bridge void *)self);
        }
        
        spice_channel_connect(channel);
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
        cs_primary_destroy(self->_display, (__bridge void *)self);
        self->_display = NULL;
        NSCAssert(self->_sigsconnected, @"Signals not connected!");
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_primary_create), (__bridge void *)self);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_primary_destroy), (__bridge void *)self);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_invalidate), (__bridge void *)self);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_mark), (__bridge void *)self);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_update_monitor_area), (__bridge void *)self);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_set_overlay), (__bridge void *)self);
        self->_sigsconnected = NO;
        return;
    }
    
    return;
}

- (id)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID monitorID:(NSInteger)monitorID {
    self = [self init];
    if (self) {
        GList *list;
        GList *it;
        
        _channelID = channelID;
        _monitorID = monitorID;
        _session = session;
        _sigsconnected = NO;
        g_object_ref(session);
        
        g_signal_connect(session, "channel-new",
                         G_CALLBACK(cs_channel_new), (__bridge void *)self);
        g_signal_connect(session, "channel-destroy",
                         G_CALLBACK(cs_channel_destroy), (__bridge void *)self);
        list = spice_session_get_channels(session);
        for (it = g_list_first(list); it != NULL; it = g_list_next(it)) {
            if (SPICE_IS_DISPLAY_CHANNEL(it->data)) {
                cs_channel_new(session, it->data, (__bridge void *)self);
            }
        }
        g_list_free(list);
    }
    return self;
}

- (id)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID {
    return [self initWithSession:session channelID:channelID monitorID:0];
}

- (void)dealloc {
    if (_display) {
        cs_channel_destroy(self.session, SPICE_CHANNEL(_display), (__bridge void *)self);
    }
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_new), (__bridge void *)self);
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_destroy), (__bridge void *)self);
    g_object_unref(_session);
    _session = NULL;
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
}

@end
