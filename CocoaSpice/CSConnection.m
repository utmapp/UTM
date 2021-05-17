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
#import "UTMLogging.h"
#import <glib.h>
#import <spice-client.h>
#import <spice/vd_agent.h>

@interface CSConnection ()

@property (nonatomic, readwrite) CSSession *session;
@property (nonatomic, readwrite) CSUSBManager *usbManager;
@property (nonatomic, readwrite) CSInput *input;
@property (nonatomic, readwrite) SpiceSession *spiceSession;
@property (nonatomic, readwrite) SpiceMainChannel *spiceMain;
@property (nonatomic, readwrite) SpiceAudio *spiceAudio;
@property (nonatomic, readwrite) NSArray<CSDisplayMetal *> *monitors;

@end

@implementation CSConnection

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
            spice_session_disconnect(self.spiceSession);
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
    GArray *cfgs = NULL;
    SpiceDisplayMonitorConfig *cfg = NULL;
    int chid;
    
    g_object_get(display,
                 "channel-id", &chid,
                 "monitors", &cfgs,
                 NULL);
    g_return_if_fail(cfgs != NULL);
    
    NSMutableIndexSet *markedItems = [NSMutableIndexSet indexSet];
    NSMutableArray<CSDisplayMetal *> *oldMonitors = [self.monitors mutableCopy];
    NSMutableArray<CSDisplayMetal *> *newMonitors = [NSMutableArray array];
    
    // mark monitors that are in use
    for (int i = 0; i < cfgs->len; i++) {
        cfg = &g_array_index(cfgs, SpiceDisplayMonitorConfig, i);
        int j;
        for (j = 0; j < oldMonitors.count; j++) {
            CSDisplayMetal *monitor = oldMonitors[j];
            if (cfg->id == monitor.monitorID && chid == monitor.channelID) {
                [markedItems addIndex:j];
                break;
            }
        }
        if (j == oldMonitors.count) { // not seen
            CSDisplayMetal *monitor = [[CSDisplayMetal alloc] initWithSession:self.spiceSession channelID:chid monitorID:i];
            [newMonitors addObject:monitor];
            [self.delegate spiceDisplayCreated:self display:monitor];
        }
    }
    
    // mark monitors that are in other channels
    for (int j = 0; j < oldMonitors.count; j++) {
        CSDisplayMetal *monitor = oldMonitors[j];
        if (chid != monitor.channelID) {
            [markedItems addIndex:j];
        }
    }
    
    // set the new monitors array
    NSMutableArray<CSDisplayMetal *> *monitors = [[oldMonitors objectsAtIndexes:markedItems] mutableCopy];
    [oldMonitors removeObjectsAtIndexes:markedItems];
    [monitors addObjectsFromArray:newMonitors];
    self.monitors = monitors;
    
    // remove old monitors
    for (CSDisplayMetal *monitor in oldMonitors) {
        [self.delegate spiceDisplayDestroyed:self display:monitor];
    }
    
    g_clear_pointer(&cfgs, g_array_unref);
}

static void cs_main_agent_update(SpiceChannel *main, gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    gboolean agent_connected = false;
    CSConnectionAgentFeature features = kCSConnectionAgentFeatureNone;
    
    g_object_get(main, "agent-connected", &agent_connected, NULL);
    UTMLog(@"SPICE agent connected: %d", agent_connected);
    if (agent_connected) {
        if (spice_main_channel_agent_test_capability(SPICE_MAIN_CHANNEL(main), VD_AGENT_CAP_MONITORS_CONFIG)) {
            features |= kCSConnectionAgentFeatureMonitorsConfig;
        }
        [self.delegate spiceAgentConnected:self supportingFeatures:features];
    } else {
        [self.delegate spiceAgentDisconnected:self];
    }
}

static void cs_channel_new(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    SPICE_DEBUG("new channel (#%d)", chid);
    
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        SPICE_DEBUG("new main channel");
        g_assert(!self.spiceMain); // should only be 1 main channel
        self.spiceMain = SPICE_MAIN_CHANNEL(channel);
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(channel, "channel-event",
                         G_CALLBACK(cs_main_channel_event), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "main_agent_update",
                         G_CALLBACK(cs_main_agent_update), GLIB_OBJC_RETAIN(self));
    }
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        SPICE_DEBUG("new display channel (#%d)", chid);
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(channel, "notify::monitors",
                         G_CALLBACK(cs_display_monitors), GLIB_OBJC_RETAIN(self));
        spice_channel_connect(channel);
    }
    
    if (SPICE_IS_PLAYBACK_CHANNEL(channel)) {
        SPICE_DEBUG("new audio channel");
        if (self.audioEnabled) {
            self.spiceAudio = spice_audio_get(s, [CSMain sharedInstance].glibMainContext);
            spice_channel_connect(channel);
        } else {
            SPICE_DEBUG("audio disabled");
        }
    }

    if (SPICE_IS_PORT_CHANNEL(channel)) {
        SPICE_DEBUG("new port channel");
        spice_channel_connect(channel);
    }
}

static void cs_channel_destroy(SpiceSession *s, SpiceChannel *channel, gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    int chid;
    
    g_object_get(channel, "channel-id", &chid, NULL);
    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        SPICE_DEBUG("zap main channel");
        self.spiceMain = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_main_channel_event), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_main_agent_update), GLIB_OBJC_RELEASE(self));
    }
    
    if (SPICE_IS_DISPLAY_CHANNEL(channel)) {
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        SPICE_DEBUG("zap display channel (#%d)", chid);
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_display_monitors), GLIB_OBJC_RELEASE(self));
        for (CSDisplayMetal *monitor in self.monitors) {
            [self.delegate spiceDisplayDestroyed:self display:monitor];
        }
        self.monitors = [NSArray<CSDisplayMetal *> array];
    }
    
    if (SPICE_IS_PLAYBACK_CHANNEL(channel)) {
        SPICE_DEBUG("zap audio channel");
        self.spiceAudio = NULL;
    }
}

static void cs_connection_destroy(SpiceSession *session,
                               gpointer data)
{
    CSConnection *self = (__bridge CSConnection *)data;
    [self.delegate spiceDisconnected:self];
}

- (void)setHost:(NSString *)host {
    g_object_set(self.spiceSession, "host", [host UTF8String], NULL);
}

- (NSString *)host {
    gchar *strhost;
    g_object_get(self.spiceSession, "host", &strhost, NULL);
    NSString *nshost = [NSString stringWithUTF8String:strhost];
    g_free(strhost);
    return nshost;
}

- (void)setPort:(NSString *)port {
    g_object_set(self.spiceSession, "port", [port UTF8String], NULL);
}

- (NSString *)port {
    gchar *strhost;
    g_object_get(self.spiceSession, "port", &strhost, NULL);
    NSString *nshost = [NSString stringWithUTF8String:strhost];
    g_free(strhost);
    return nshost;
}

- (void)dealloc {
    UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(self.spiceSession, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.spiceSession, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.spiceSession, G_CALLBACK(cs_connection_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.spiceSession);
    self.spiceSession = NULL;
}

- (instancetype)initWithHost:(NSString *)host port:(NSString *)port {
    if (self = [super init]) {
        self.spiceSession = spice_session_new();
        self.host = host;
        self.port = port;
        UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
        g_signal_connect(self.spiceSession, "channel-new",
                         G_CALLBACK(cs_channel_new), GLIB_OBJC_RETAIN(self));
        g_signal_connect(self.spiceSession, "channel-destroy",
                         G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RETAIN(self));
        g_signal_connect(self.spiceSession, "disconnected",
                         G_CALLBACK(cs_connection_destroy), GLIB_OBJC_RETAIN(self));
        
#if !defined(WITH_QEMU_TCI)
        SpiceUsbDeviceManager *manager = spice_usb_device_manager_get(self.spiceSession, NULL);
        g_assert(manager != NULL);
        self.usbManager = [[CSUSBManager alloc] initWithUsbDeviceManager:manager];
#endif
        self.input = [[CSInput alloc] initWithSession:self.spiceSession];
        self.session = [[CSSession alloc] initWithSession:self.spiceSession];
        self.monitors = [NSArray<CSDisplayMetal *> array];
    }
    return self;
}

- (BOOL)connect {
    return spice_session_connect(self.spiceSession);
}

- (void)disconnect {
    spice_session_disconnect(self.spiceSession);
}

@end
