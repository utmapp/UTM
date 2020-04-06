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
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#import <glib.h>
#import <spice-client.h>
#import <spice/vd_agent.h>

@interface CSSession ()

@property (nonatomic, readwrite, nullable) SpiceSession *session;
@property (nonatomic, readonly) BOOL sessionReadOnly;

@end

@implementation CSSession {
    SpiceMainChannel        *_main;
    NSInteger               _pasteboardChanges;
}

static NSString *utiForClipboardType(guint type)
{
    CFStringRef uti = NULL;
    switch (type) {
        case VD_AGENT_CLIPBOARD_UTF8_TEXT: {
            uti = kUTTypeUTF8PlainText;
            break;
        }
        case VD_AGENT_CLIPBOARD_IMAGE_PNG: {
            uti = kUTTypePNG;
            break;
        }
        case VD_AGENT_CLIPBOARD_IMAGE_BMP: {
            uti = kUTTypeBMP;
            break;
        }
        case VD_AGENT_CLIPBOARD_IMAGE_TIFF: {
            uti = kUTTypeTIFF;
            break;
        }
        case VD_AGENT_CLIPBOARD_IMAGE_JPG: {
            uti = kUTTypeJPEG;
            break;
        }
        default: {
            g_warning("unknown clipboard type %d", type);
            break;
        }
    }
    return (__bridge NSString *)uti;
}

// helper from spice-util.c

typedef enum {
    NEWLINE_TYPE_LF,
    NEWLINE_TYPE_CR_LF
} NewlineType;

static gssize get_line(const gchar *str, gsize len,
                       NewlineType type, gsize *nl_len)
{
    const gchar *p, *endl;
    gsize nl = 0;

    endl = (type == NEWLINE_TYPE_CR_LF) ? "\r\n" : "\n";
    p = g_strstr_len(str, len, endl);
    if (p) {
        len = p - str;
        nl = strlen(endl);
    }

    *nl_len = nl;
    return len;
}

static gchar* spice_convert_newlines(const gchar *str, gssize len,
                                     NewlineType from,
                                     NewlineType to)
{
    gssize length;
    gsize nl;
    GString *output;
    gint i;

    g_return_val_if_fail(str != NULL, NULL);
    g_return_val_if_fail(len >= -1, NULL);
    /* only 2 supported combinations */
    g_return_val_if_fail((from == NEWLINE_TYPE_LF &&
                          to == NEWLINE_TYPE_CR_LF) ||
                         (from == NEWLINE_TYPE_CR_LF &&
                          to == NEWLINE_TYPE_LF), NULL);

    if (len == -1)
        len = strlen(str);
    /* sometime we get \0 terminated strings, skip that, or it fails
       to utf8 validate line with \0 end */
    else if (len > 0 && str[len-1] == 0)
        len -= 1;

    /* allocate worst case, if it's small enough, we don't care much,
     * if it's big, malloc will put us in mmap'd region, and we can
     * over allocate.
     */
    output = g_string_sized_new(len * 2 + 1);

    for (i = 0; i < len; i += length + nl) {
        length = get_line(str + i, len - i, from, &nl);
        if (length < 0)
            break;

        g_string_append_len(output, str + i, length);

        if (nl) {
            /* let's not double \r if it's already in the line */
            if (to == NEWLINE_TYPE_CR_LF &&
                (output->len == 0 || output->str[output->len - 1] != '\r'))
                g_string_append_c(output, '\r');

            g_string_append_c(output, '\n');
        }
    }

    return g_string_free(output, FALSE);
}

G_GNUC_INTERNAL
gchar* spice_dos2unix(const gchar *str, gssize len)
{
    return spice_convert_newlines(str, len,
                                  NEWLINE_TYPE_CR_LF,
                                  NEWLINE_TYPE_LF);
}

G_GNUC_INTERNAL
gchar* spice_unix2dos(const gchar *str, gssize len)
{
    return spice_convert_newlines(str, len,
                                  NEWLINE_TYPE_LF,
                                  NEWLINE_TYPE_CR_LF);
}

static void cs_clipboard_got_from_guest(SpiceMainChannel *main, guint selection,
                                        guint type, const guchar *data, guint size,
                                        gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;

    SPICE_DEBUG("clipboard got data");
    
    if (type == VD_AGENT_CLIPBOARD_UTF8_TEXT) {
        gchar *conv = NULL;
        /* on windows, gtk+ would already convert to LF endings, but
           not on unix */
        if (spice_main_channel_agent_test_capability(self->_main, VD_AGENT_CAP_GUEST_LINEEND_CRLF)) {
            conv = spice_dos2unix((gchar*)data, size);
            size = (guint)strlen(conv);
        }
        NSString *string = [NSString stringWithUTF8String:(conv ? conv : (const char *)data)];
        self->_pasteboardChanges = [UIPasteboard generalPasteboard].changeCount + 1;
        [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:(__bridge NSString *)kUTTypeUTF8PlainText];
        g_free(conv);
    } else {
        NSString *uti = utiForClipboardType(type);
        if (uti) {
            NSData *pasteData = [NSData dataWithBytes:data length:size];
            self->_pasteboardChanges = [UIPasteboard generalPasteboard].changeCount + 1;
            [[UIPasteboard generalPasteboard] setData:pasteData forPasteboardType:uti];
        }
    }
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

    NSString *uti = utiForClipboardType(type);
    NSData *data = [[UIPasteboard generalPasteboard] dataForPasteboardType:uti];
    spice_main_channel_clipboard_selection_notify(self->_main, selection, type, data.bytes, data.length);\

    return TRUE;
}

static void cs_clipboard_release(SpiceMainChannel *main, guint selection,
                                 gpointer user_data)
{
    CSSession *self = (__bridge CSSession *)user_data;
    self->_pasteboardChanges = [UIPasteboard generalPasteboard].changeCount + 1;
    [UIPasteboard generalPasteboard].items = @[];
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pasteboardDidChange:)
                                                     name:UIPasteboardChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pasteboardDidRemove:)
                                                     name:UIPasteboardRemovedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        _pasteboardChanges = [UIPasteboard generalPasteboard].changeCount;
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
        
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
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
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_new), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.session, G_CALLBACK(cs_channel_destroy), GLIB_OBJC_RELEASE(self));
    g_object_unref(self.session);
    self.session = NULL;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIPasteboardChangedNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIPasteboardRemovedNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

#pragma mark - Notification handler

- (void)pasteboardDidChange:(NSNotification *)notification {
    NSLog(@"seen UIPasteboardChangedNotification");
    if (!self.shareClipboard || self.sessionReadOnly) {
        return;
    }
    if ([UIPasteboard generalPasteboard].changeCount <= _pasteboardChanges) {
        NSLog(@"ignoring excess pasteboard change");
        return;
    } else {
        _pasteboardChanges = [UIPasteboard generalPasteboard].changeCount;
    }
    guint32 type = VD_AGENT_CLIPBOARD_NONE;
    NSArray *types = [[UIPasteboard generalPasteboard] pasteboardTypes];
    if ([types containsObject:(__bridge NSString *)kUTTypePNG]) {
        type = VD_AGENT_CLIPBOARD_IMAGE_PNG;
    } else if ([types containsObject:(__bridge NSString *)kUTTypeBMP]) {
        type = VD_AGENT_CLIPBOARD_IMAGE_BMP;
    } else if ([types containsObject:(__bridge NSString *)kUTTypeTIFF]) {
        type = VD_AGENT_CLIPBOARD_IMAGE_TIFF;
    } else if ([types containsObject:(__bridge NSString *)kUTTypeJPEG]) {
        type = VD_AGENT_CLIPBOARD_IMAGE_JPG;
    } else if ([[UIPasteboard generalPasteboard] hasStrings]) {
        type = VD_AGENT_CLIPBOARD_UTF8_TEXT;
    } else {
        NSLog(@"pasteboard with unrecognized type");
    }
    if (spice_main_channel_agent_test_capability(self->_main, VD_AGENT_CAP_CLIPBOARD_BY_DEMAND)) {
        spice_main_channel_clipboard_selection_grab(self->_main, VD_AGENT_CLIPBOARD_SELECTION_CLIPBOARD, &type, 1);
    }
}

- (void)pasteboardDidRemove:(NSNotification *)notification {
    NSLog(@"seen UIPasteboardRemovedNotification");
    if (!self.shareClipboard || self.sessionReadOnly) {
        return;
    }
    _pasteboardChanges = [UIPasteboard generalPasteboard].changeCount;
    guint32 type = VD_AGENT_CLIPBOARD_UTF8_TEXT;
    if (spice_main_channel_agent_test_capability(self->_main, VD_AGENT_CAP_CLIPBOARD_BY_DEMAND)) {
        spice_main_channel_clipboard_selection_grab(self->_main, VD_AGENT_CLIPBOARD_SELECTION_CLIPBOARD, &type, 1);
    }
}

- (void)willEnterForeground:(NSNotification *)notification {
    if ([UIPasteboard generalPasteboard].changeCount > _pasteboardChanges) {
        [self pasteboardDidChange:notification];
    }
}

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
    if (spice_main_channel_agent_test_capability(self->_main,
                                                 VD_AGENT_CAP_GUEST_LINEEND_CRLF)) {
        char *conv = NULL;
        conv = spice_unix2dos([text cStringUsingEncoding:NSUTF8StringEncoding], text.length);
        text = [NSString stringWithUTF8String:conv];
        g_free(conv);
    }
    return text;
}

@end
