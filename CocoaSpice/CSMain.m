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

#import "CSMain.h"
#import "UTMLogging.h"
#import <glib.h>
#import <spice-client.h>
#import <pthread.h>
#import "gst_ios_init.h"

@interface CSMain ()

@property (nonatomic, readwrite) BOOL running;
@property (nonatomic) pthread_t spiceThread;

@end

@implementation CSMain {
    GMainContext *_main_context;
    GMainLoop *_main_loop;
}

static void logHandler(const gchar *log_domain, GLogLevelFlags log_level,
                       const gchar *message, gpointer user_data)
{
    GDateTime *now;
    gchar *dateTimeStr;
    
    char* levelStr = "UNKNOWN";
    if (log_level & G_LOG_LEVEL_ERROR) {
        levelStr = "ERROR";
    } else if (log_level & G_LOG_LEVEL_CRITICAL) {
        levelStr = "CRITICAL";
    } else if (log_level & G_LOG_LEVEL_WARNING) {
        levelStr = "WARNING";
    } else if (log_level & G_LOG_LEVEL_MESSAGE) {
        levelStr = "MESSAGE";
    } else if (log_level & G_LOG_LEVEL_INFO) {
        levelStr = "INFO";
    } else if (log_level & G_LOG_LEVEL_DEBUG) {
        levelStr = "DEBUG";
    }
    
    now = g_date_time_new_now_local();
    dateTimeStr = g_date_time_format(now, "%Y-%m-%d %T");
    
    fprintf(stdout, "%s,%03d %s %s-%s\n", dateTimeStr,
            g_date_time_get_microsecond(now) / 1000, levelStr,
            log_domain, message);
    
    g_date_time_unref(now);
    g_free(dateTimeStr);
}

void *spice_main_loop(void *args) {
    CSMain *self = (__bridge_transfer CSMain *)args;
    
    gst_ios_init();
    
    g_main_context_ref(self->_main_context);
    g_main_context_push_thread_default(self->_main_context);
    g_main_loop_run(self->_main_loop);
    g_main_context_pop_thread_default(self->_main_context);
    g_main_context_unref(self->_main_context);
    
    return NULL;
}

+ (CSMain *)sharedInstance {
    static CSMain *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void *)glibMainContext {
    return _main_context;
}

- (id)init {
    self = [super init];
    if (self) {
        if ((_main_context = g_main_context_new()) == NULL) {
            return nil;
        }
        if ((_main_loop = g_main_loop_new(_main_context, FALSE)) == NULL) {
            g_main_context_unref(_main_context);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self spiceStop];
    g_main_loop_unref(_main_loop);
    g_main_context_unref(_main_context);
}

- (void)spiceSetDebug:(BOOL)enabled {
    spice_util_set_debug(enabled);
    g_log_set_handler(NULL, G_LOG_LEVEL_MASK, logHandler, NULL);
}

- (BOOL)spiceStart {
    @synchronized (self) {
        if (!self.running) {
            pthread_t spiceThread;
            spice_util_set_main_context(_main_context);
            if (pthread_create(&spiceThread, NULL, &spice_main_loop, (__bridge_retained void *)self) != 0) {
                return NO;
            }
            self.running = YES;
            self.spiceThread = spiceThread;
        }
    }
    return YES;
}

- (void)spiceStop {
    @synchronized (self) {
        if (self.running) {
            void *status;
            spice_util_set_main_context(NULL);
            g_main_loop_quit(_main_loop);
            pthread_join(self.spiceThread, &status);
            self.running = NO;
            self.spiceThread = NULL;
        }
    }
}

@end
