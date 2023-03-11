//
// Copyright © 2023 osy. All rights reserved.
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

#import "UTMQemuMonitor.h"
#import "UTMQemuManager-Protected.h"
#import "UTMLogging.h"
#import "qapi-commands.h"
#import "qapi-emit-events.h"
#import "qapi-events.h"
#import "error.h"

static void utm_shutdown_handler(bool guest, ShutdownCause reason, void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuWillQuit:self guest:guest reason:reason];
}

static void utm_powerdown_handler(void *ctx) {
    
}

static void utm_reset_handler(bool guest, ShutdownCause reason, void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuHasReset:self guest:guest reason:reason];
}

static void utm_stop_handler(void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuHasStopped:self];
}

static void utm_resume_handler(void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuHasResumed:self];
}

static void utm_suspend_handler(void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuHasSuspended:self];
}

static void utm_suspend_disk_handler(void *ctx) {
    
}

static void utm_wakeup_handler(void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuHasWakeup:self];
}

static void utm_watchdog_handler(WatchdogAction action, void *ctx) {
    
}

static void utm_guest_panicked_handler(GuestPanicAction action, bool has_info, GuestPanicInformation *info, void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuError:self error:NSLocalizedString(@"Guest panic", @"UTMQemuManager")];
}

static void utm_block_image_corrupted_handler(const char *device, bool has_node_name, const char *node_name, const char *msg, bool has_offset, int64_t offset, bool has_size, int64_t size, bool fatal, void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    if (fatal) {
        [self.delegate qemuError:self error:[NSString stringWithFormat:@"%s, %s: %s", device, node_name, msg]];
    }
}

static void utm_block_io_error_handler(const char *device, bool has_node_name, const char *node_name, IoOperationType operation, BlockErrorAction action, bool has_nospace, bool nospace, const char *reason, void *ctx) {
    UTMQemuMonitor *self = (__bridge UTMQemuMonitor *)ctx;
    [self.delegate qemuError:self error:[NSString stringWithFormat:@"%s, %s: %s", device, node_name, reason]];
}

static void utm_spice_connected_handler(SpiceBasicInfo *server, SpiceBasicInfo *client, void *ctx) {
    
}

static void utm_spice_initialized_handler(SpiceServerInfo *server, SpiceChannel *client, void *ctx) {
    
}

static void utm_spice_disconnected_handler(SpiceBasicInfo *server, SpiceBasicInfo *client, void *ctx) {
    
}

static void utm_spice_migrate_completed_handler(void *ctx) {
    
}

static void utm_migration_handler(MigrationStatus status, void *ctx) {
    
}

static void utm_migration_pass_handler(int64_t pass, void *ctx) {
    
}

qapi_enum_handler_registry qapi_enum_handler_registry_data = {
    .qapi_shutdown_handler = utm_shutdown_handler,
    .qapi_powerdown_handler = utm_powerdown_handler,
    .qapi_reset_handler = utm_reset_handler,
    .qapi_stop_handler = utm_stop_handler,
    .qapi_resume_handler = utm_resume_handler,
    .qapi_suspend_handler = utm_suspend_handler,
    .qapi_suspend_disk_handler = utm_suspend_disk_handler,
    .qapi_wakeup_handler = utm_wakeup_handler,
    .qapi_watchdog_handler = utm_watchdog_handler,
    .qapi_guest_panicked_handler = utm_guest_panicked_handler,
    .qapi_block_image_corrupted_handler = utm_block_image_corrupted_handler,
    .qapi_block_io_error_handler = utm_block_io_error_handler,
    .qapi_spice_connected_handler = utm_spice_connected_handler,
    .qapi_spice_initialized_handler = utm_spice_initialized_handler,
    .qapi_spice_disconnected_handler = utm_spice_disconnected_handler,
    .qapi_spice_migrate_completed_handler = utm_spice_migrate_completed_handler,
    .qapi_migration_handler = utm_migration_handler,
    .qapi_migration_pass_handler = utm_migration_pass_handler,
};

@implementation UTMQemuMonitor

- (BOOL)didGetUnhandledKey:(NSString *)key value:(id)value {
    if ([key isEqualToString:@"QMP"]) {
        UTMLog(@"Got QMP handshake: %@", value);
        [self.delegate qemuQmpDidConnect:self];
        return YES;
    }
    return NO;
}

- (BOOL)qmpEnterCommandModeWithError:(NSError * _Nullable __autoreleasing *)error {
    NSDictionary *cmd = @{
        @"execute": @"qmp_capabilities"
    };
    Error *qerr = NULL;
    qmp_rpc_call((__bridge CFDictionaryRef)cmd, NULL, &qerr, (__bridge void *)self);
    if (qerr != NULL) {
        if (error) {
            *error = [self errorForQerror:qerr];
            error_free(qerr);
        }
        return NO;
    } else {
        self.isConnected = YES;
        return YES;
    }
}

- (BOOL)continueBootWithError:(NSError * _Nullable __autoreleasing *)error {
    Error *qerr = NULL;
    qmp_cont(&qerr, (__bridge void *)self);
    if (qerr != NULL) {
        if (error) {
            *error = [self errorForQerror:qerr];
            error_free(qerr);
        }
        self.isConnected = NO;
        return NO;
    } else {
        return YES;
    }
}

- (void)qmpPowerCommand:(NSString *)command completion:(void (^ _Nullable)(NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        Error *qerr = NULL;
        NSError *err;
        NSDictionary *cmd = @{
            @"execute": command
        };
        qmp_rpc_call((__bridge CFDictionaryRef)cmd, NULL, &qerr, (__bridge void *)self);
        if (qerr) {
            err = [self errorForQerror:qerr];
            error_free(qerr);
        }
        if (completion) {
            completion(err);
        }
    });
}

- (void)qmpHmpCommand:(NSString *)cmd completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        Error *qerr = NULL;
        NSError *err;
        NSString *result;
        char *res;
        res = qmp_human_monitor_command([cmd cStringUsingEncoding:NSASCIIStringEncoding], false, 0, &qerr, (__bridge void *)self);
        if (res) {
            result = [NSString stringWithCString:res encoding:NSASCIIStringEncoding];
            g_free(res);
        }
        if (qerr) {
            err = [self errorForQerror:qerr];
            error_free(qerr);
        }
        if (completion) {
            completion(result, err);
        }
    });
}

- (void)qemuPowerDownWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self qmpPowerCommand:@"system_powerdown" completion:completion];
}

- (void)qemuResetWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self qmpPowerCommand:@"system_reset" completion:completion];
}

- (void)qemuStopWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self qmpPowerCommand:@"stop" completion:completion];
}

- (void)qemuResumeWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self qmpPowerCommand:@"cont" completion:completion];
}

- (void)qemuQuitWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self qmpPowerCommand:@"quit" completion:completion];
}

- (void)qemuSaveStateWithCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion snapshotName:(NSString *)name {
    NSString *cmd = [NSString stringWithFormat:@"savevm %@", name];
    [self qmpHmpCommand:cmd completion:completion];
}

- (void)qemuDeleteStateWithCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion snapshotName:(NSString *)name {
    NSString *cmd = [NSString stringWithFormat:@"delvm %@", name];
    [self qmpHmpCommand:cmd completion:completion];
}

- (void)mouseIndexForAbsolute:(BOOL)absolute withCompletion:(void (^)(int64_t, NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        MouseInfoList *info = NULL;
        Error *qerr = NULL;
        int64_t index = -1;
        NSError *err;
        info = qmp_query_mice(&qerr, (__bridge void *)self);
        if (qerr) {
            err = [self errorForQerror:qerr];
            error_free(qerr);
        }
        if (info) {
            for (MouseInfoList *list = info; list; list = list->next) {
                if (list->value->absolute == absolute) {
                    index = list->value->index;
                    break;
                }
            }
            qapi_free_MouseInfoList(info);
        }
        if (completion) {
            completion(index, err);
        }
    });
}

- (void)mouseSelect:(int64_t)index withCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSString *cmd = [NSString stringWithFormat:@"mouse_set %lld", index];
    [self qmpHmpCommand:cmd completion:completion];
}

@end
