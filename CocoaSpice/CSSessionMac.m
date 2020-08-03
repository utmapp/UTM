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

#import "CSSession.h"
#import "CocoaSpice.h"
#import "UTMLogging.h"
#import <glib.h>
#import <spice-client.h>
#import <spice/vd_agent.h>

@interface CSSession ()

@property (nonatomic, readwrite, nullable) SpiceSession *session;
@property (nonatomic, readonly) BOOL sessionReadOnly;

@end

@implementation CSSession {
    SpiceMainChannel        *_main;
}

static void cs_clipboard_got_from_guest(SpiceMainChannel *main, guint selection,
                                        guint type, const guchar *data, guint size,
                                        gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;

    SPICE_DEBUG("clipboard got data");
}

static gboolean cs_clipboard_grab(SpiceMainChannel *main, guint selection,
                                  guint32* types, guint32 ntypes,
                                  gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;
    
    if (selection != VD_AGENT_CLIPBOARD_SELECTION_CLIPBOARD) {
        SPICE_DEBUG("skipping grab unimplemented selection: %d", selection);
        return FALSE;
    }

    if (self.sessionReadOnly || !self.shareClipboard) {
        SPICE_DEBUG("ignoring clipboard_grab");
        return TRUE;
    }

    for (int n = 0; n < ntypes; ++n) {
        spice_main_channel_clipboard_selection_request(self->_main, selection,
                                                       types[n]);
    }

    return TRUE;
}

static gboolean cs_clipboard_request(SpiceMainChannel *main, guint selection,
                                     guint type, gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;
    
    if (selection != VD_AGENT_CLIPBOARD_SELECTION_CLIPBOARD) {
        SPICE_DEBUG("skipping request unimplemented selection: %d", selection);
        return FALSE;
    }

    if (self.sessionReadOnly || !self.shareClipboard) {
        SPICE_DEBUG("ignoring clipboard_request");
        return FALSE;
    }

    return TRUE;
}

static void cs_clipboard_release(SpiceMainChannel *main, guint selection,
                                 gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;
}

static void cs_channel_new(SpiceSession *session, SpiceChannel *channel,
                           gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;

    if (SPICE_IS_MAIN_CHANNEL(channel)) {
        SPICE_DEBUG("Changing main channel from %p to %p", self->_main, channel);
        self->_main = SPICE_MAIN_CHANNEL(channel);
        g_signal_connect(channel, "main-clipboard-selection-grab",
                         G_CALLBACK(cs_clipboard_grab), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "main-clipboard-selection-request",
                         G_CALLBACK(cs_clipboard_request), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "main-clipboard-selection-release",
                         G_CALLBACK(cs_clipboard_release), GLIB_OBJC_RETAIN(self));
        g_signal_connect(channel, "main-clipboard-selection",
                         G_CALLBACK(cs_clipboard_got_from_guest), GLIB_OBJC_RETAIN(self));
    }
}

static void cs_channel_destroy(SpiceSession *session, SpiceChannel *channel,
                               gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;

    if (SPICE_IS_MAIN_CHANNEL(channel) && SPICE_MAIN_CHANNEL(channel) == self->_main) {
        self->_main = NULL;
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_clipboard_grab), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_clipboard_request), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_clipboard_release), GLIB_OBJC_RELEASE(self));
        g_signal_handlers_disconnect_by_func(channel, G_CALLBACK(cs_clipboard_got_from_guest), GLIB_OBJC_RELEASE(self));
    }
}

#pragma mark - Initializers

- (id)init {
    if (self = [super init]) {
    }
    return self;
}

- (id)initWithSession:(nonnull SpiceSession *)session {
    self = [self init];
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
            cs_channel_new(session, it->data, (__bridge void *)self);
        }
        g_list_free(list);
    }
    return self;
}

- (void)dealloc {
    UTMLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.session);
    self.session = NULL;
}

#pragma mark - Notification handler


#pragma mark - Instance methods

- (BOOL)sessionReadOnly {
    return spice_session_get_read_only(_session);
}
        
/* This will convert line endings if needed (between Windows/Unix conventions),
 * and will make sure 'len' does not take into account any trailing \0 as this could
 * cause some confusion guest side.
 * The 'len' argument will be modified by this function to the length of the modified
 * string
 */
- (NSString *)fixupClipboardText:(NSString *)text {
    return text;
}

#pragma mark - Shared Directory

- (void)setSharedDirectory:(NSString *)path readOnly:(BOOL)readOnly {
    g_object_set(_session, "shared-dir", [path cStringUsingEncoding:NSUTF8StringEncoding], NULL);
    g_object_set(_session, "share-dir-ro", readOnly, NULL);
}

@end
