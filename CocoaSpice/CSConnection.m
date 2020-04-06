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

#import "CocoaSpice.h"
#import <glib.h>
#import <spice-client.h>

@interface CSConnection ()

@property (nonatomic, readwrite) CSSession *session;

@end

@implementation CSConnection {
    SpiceSession     *_session;
    SpiceMainChannel *_main;
    SpiceAudio       *_audio;
    NSMutableArray<NSMutableArray<CSDisplayMetal *> *> *_monitors;
    NSMutableArray<NSMutableArray<CSInput *> *> *_inputs;
    CSSession        *_csSession;
}

static void cs_main_channel_event(SpiceChannel *channel, SpiceChannelEvent event,
                               gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    const GError *error = NULL;
    
    switch (event) {
        case SPICE_CHANNEL_OPENED:
            g_message("main channel: opened");
            [self.delegate spiceConnected:self];
            break;
        case SPICE_CHANNEL_SWITCHING:
            g_message("main channel: switching host");
            break;
        case SPICE_CHANNEL_CLOSED:
            /* this event is only sent if the channel was succesfully opened before */
            g_message("main channel: closed");
            spice_session_disconnect(self->_session);
            break;
        case SPICE_CHANNEL_ERROR_IO:
        case SPICE_CHANNEL_ERROR_TLS:
        case SPICE_CHANNEL_ERROR_LINK:
        case SPICE_CHANNEL_ERROR_CONNECT:
        case SPICE_CHANNEL_ERROR_AUTH:
            error = spice_channel_get_error(channel);
            if (error) {
                g_message("channel error: %s", error->message);
            }
            [self.delegate spiceError:self err:(error ? [NSString stringWithUTF8String:error->message] : nil)];
            break;
        default:
            /* TODO: more sophisticated error handling */
            g_warning("unknown main channel event: %u", event);
            /* connection_disconnect(conn); */
            break;
    }
}

static void cs_display_monitors(SpiceChannel *display, GParamSpec *pspec,
                             gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    GArray *monitors = NULL;
    int chid;
    NSUInteger i;
    
    g_object_get(display,
                 "channel-id", &chid,
                 "monitors", &monitors,
                 NULL);
    g_return_if_fail(monitors != NULL);
    
    if (!self->_monitors) {
        self->_monitors = [NSMutableArray<NSMutableArray<CSDisplayMetal *> *> array];
    }
    if (!self->_inputs) {
        self->_inputs = [NSMutableArray<NSMutableArray<CSInput *> *> array];
    }
    
    // create enough outer arrays to let us index
    while (self->_monitors.count <= chid) {
        [self->_monitors addObject:[NSMutableArray<CSDisplayMetal *> array]];
    }
    while (self->_inputs.count <= chid) {
        [self->_inputs addObject:[NSMutableArray<CSInput *> array]];
    }
    
    // create new monitors for this display
    for (i = self->_monitors[chid].count; i < monitors->len; i++) {
        CSDisplayMetal *monitor = [[CSDisplayMetal alloc] initWithSession:self->_session channelID:chid monitorID:i];
        [self->_monitors[chid] addObject:monitor];
        
        CSInput *input = [[CSInput alloc] initWithSession:self->_session channelID:chid monitorID:i];
        [self->_inputs[chid] addObject:input];
        
        [self.delegate spiceDisplayCreated:self display:monitor input:input];
    }
    
    // clear any extra displays
    NSUInteger total = self->_monitors.count;
    for (i = monitors->len; i < total; i++) {
        [self->_monitors[chid] removeLastObject];
    }
    total = self->_inputs.count;
    for (i = monitors->len; i < total; i++) {
        [self->_inputs[chid] removeLastObject];
    }
    
    g_clear_pointer(&monitors, g_array_unref);
}

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    SPICE_DEBUG("new channel (#%d)", chid);
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        SPICE_DEBUG("new main channel");
        g_assert(!self->_main); // should only be 1 main channel
        self->_main = SPICE_MAIN_CHANNEL(channel);
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(channel, "channel-event",
                         G_CALLBACK(cs_main_channel_event), GLIB_OBJC_RETAIN(self));
    }
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        SPICE_DEBUG("new display channel (#%d)", chid);
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(channel, "notify::monitors",
                         G_CALLBACK(cs_display_monitors), GLIB_OBJC_RETAIN(self));
        spice_channel_connect(channel);
    }
    
    if (SPICE_IS_PLAYBACK_CHANNEL(channel)) {
        SPICE_DEBUG("new audio channel");
        if (self.audioEnabled) {
            self->_audio = spice_audio_get(s, self.glibMainContext);
            spice_channel_connect(channel);
        } else {
            SPICE_DEBUG("audio disabled");
        }
    }
}

static void cs_channel_destroy(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        SPICE_DEBUG("zap main channel");
        self->_main = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_main_channel_event), GLIB_OBJC_RELEASE(self));
    }
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        SPICE_DEBUG("zap display channel (#%d)", chid);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_display_monitors), GLIB_OBJC_RELEASE(self));
        [self->_monitors[chid] removeAllObjects];
        [self->_inputs[chid] removeAllObjects];
    }
    
    if (SPICE_IS_PLAYBACK_CHANNEL(channel)) {
        SPICE_DEBUG("zap audio channel");
        self->_audio = NULL;
    }
}

static void cs_connection_destroy(SpiceSession *session,
                               gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    [self.delegate spiceDisconnected:self];
}

- (NSArray<NSArray<CSDisplayMetal *> *> *)monitors {
    return _monitors;
}

- (NSArray<NSArray<CSInput *> *> *)inputs {
    return _inputs;
}

@synthesize session = _csSession;

- (void)setHost:(NSString *)host {
    g_object_set(_session, "host", [host UTF8String], NULL);
}

- (NSString *)host {
    gchar *strhost;
    g_object_get(_session, "host", &strhost, NULL);
    NSString *nshost = [NSString stringWithUTF8String:strhost];
    g_free(strhost);
    return nshost;
}

- (void)setPort:(NSString *)port {
    g_object_set(_session, "port", [port UTF8String], NULL);
}

- (NSString *)port {
    gchar *strhost;
    g_object_get(_session, "port", &strhost, NULL);
    NSString *nshost = [NSString stringWithUTF8String:strhost];
    g_free(strhost);
    return nshost;
}

- (void)setGlibMainContext:(void *)glibMainContext {
    if (_glibMainContext != NULL) {
        g_main_context_unref((GMainContext *)_glibMainContext);
    }
    if (glibMainContext) {
        g_main_context_ref((GMainContext *)glibMainContext);
    }
    _glibMainContext = glibMainContext;
}

- (id)init {
    self = [super init];
    if (self) {
        _session = spice_session_new();
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(_session, "channel-new",
                         G_CALLBACK(cs_channel_new), GLIB_OBJC_RETAIN(self));
        g_signal_connect(_session, "channel-destroy",
                         G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RETAIN(self));
        g_signal_connect(_session, "disconnected",
                         G_CALLBACK(cs_connection_destroy), GLIB_OBJC_RETAIN(self));
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(_session, G_CALLBACK(cs_connection_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(_session);
    _session = NULL;
    self.glibMainContext = NULL;
}

- (id)initWithHost:(NSString *)host port:(NSString *)port {
    self = [self init];
    if (self) {
        self.host = host;
        self.port = port;
    }
    return self;
}

- (BOOL)connect {
    self.session = [[CSSession alloc] initWithSession:_session];
    [self.delegate spiceSessionCreated:self session:self.session];
    return spice_session_connect(_session);
}

- (void)disconnect {
    spice_session_disconnect(_session);
    self.session = NULL;
}

@end
