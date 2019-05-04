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

#import "UTMQemuManager.h"
#import "UTMJSONStream.h"
#import "qapi-commands.h"
#import "qapi-dispatch-events.h"
#import "qapi-events.h"
#import "error.h"

extern NSString *const kUTMErrorDomain;
const int64_t kRPCTimeout = (int64_t)60*1000000000;

static void utm_shutdown_handler(bool guest, ShutdownCause reason, void *ctx) {
    
}

static void utm_powerdown_handler(void *ctx) {
    
}

static void utm_reset_handler(bool guest, ShutdownCause reason, void *ctx) {
}

static void utm_stop_handler(void *ctx) {
    
}

static void utm_resume_handler(void *ctx) {
    
}

static void utm_suspend_handler(void *ctx) {
    
}

static void utm_suspend_disk_handler(void *ctx) {
    
}

static void utm_wakeup_handler(void *ctx) {
    
}

static void utm_watchdog_handler(WatchdogAction action, void *ctx) {
    
}

static void utm_guest_panicked_handler(GuestPanicAction action, bool has_info, GuestPanicInformation *info, void *ctx) {
    
}

static void utm_block_image_corrupted_handler(const char *device, bool has_node_name, const char *node_name, const char *msg, bool has_offset, int64_t offset, bool has_size, int64_t size, bool fatal, void *ctx) {
    
}

static void utm_block_io_error_handler(const char *device, bool has_node_name, const char *node_name, IoOperationType operation, BlockErrorAction action, bool has_nospace, bool nospace, const char *reason, void *ctx) {
    
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

@implementation UTMQemuManager {
    UTMJSONStream *_jsonStream;
    void (^_rpc_finish)(NSDictionary *, NSError *);
    dispatch_semaphore_t _cmd_lock;
}

void qmp_rpc_call(CFDictionaryRef args, CFDictionaryRef *ret, Error **err, void *ctx) {
    UTMQemuManager *self = (__bridge UTMQemuManager *)ctx;
    dispatch_semaphore_t rpc_sema = dispatch_semaphore_create(0);
    __block NSDictionary *dict;
    __block NSError *nserr;
    dispatch_semaphore_wait(self->_cmd_lock, DISPATCH_TIME_FOREVER);
    self->_rpc_finish = ^(NSDictionary *ret_dict, NSError *ret_err){
        NSCAssert(ret_dict || ret_err, @"Both dict and err are null");
        nserr = ret_err;
        dict = ret_dict;
        dispatch_semaphore_signal(rpc_sema);
        self->_rpc_finish = nil;
    };
    if (![self.jsonStream sendDictionary:(__bridge NSDictionary *)args]) {
        self->_rpc_finish(nil, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No connection for RPC.", "UTMQemuManager")}]);
    }
    if (dispatch_semaphore_wait(rpc_sema, dispatch_time(DISPATCH_TIME_NOW, kRPCTimeout)) != 0) {
        self->_rpc_finish = nil;
        nserr = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Timed out waiting for RPC.", "UTMQemuManager")}];
    }
    if (ret) {
        *ret = CFBridgingRetain(dict);
    }
    dict = nil;
    if (nserr) {
        error_setg(err, "%s", [nserr.localizedDescription cStringUsingEncoding:NSUTF8StringEncoding]);
        NSLog(@"RPC: %@", nserr);
    }
    dispatch_semaphore_signal(self->_cmd_lock);
}

- (id)init {
    self = [super init];
    if (self) {
        _jsonStream = [[UTMJSONStream alloc] initHost:@"127.0.0.1" port:4444];
        _jsonStream.delegate = self;
        _cmd_lock = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)dealloc {
    if (_rpc_finish) {
        _rpc_finish(nil, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Manager being deallocated, killing pending RPC.", "UTMQemuManager")}]);
    }
}

- (void)connect {
    [_jsonStream connect];
}

- (void)disconnect {
    [_jsonStream disconnect];
}

- (void)jsonStream:(UTMJSONStream *)stream seenError:(NSError *)error {
    if (_rpc_finish) {
        _rpc_finish(nil, error);
    }
}

- (void)jsonStream:(UTMJSONStream *)stream receivedDictionary:(NSDictionary *)dict {
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        if ([key isEqualToString:@"return"]) {
            if (self->_rpc_finish) {
                self->_rpc_finish(dict, nil);
            } else {
                NSLog(@"Got unexpected 'return' response: %@", dict);
            }
            *stop = YES;
        } else if ([key isEqualToString:@"error"]) {
            if (self->_rpc_finish) {
                self->_rpc_finish(nil, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: dict[@"error"][@"desc"]}]);
            } else {
                NSLog(@"Got unexpected 'error' response: %@", dict);
            }
            *stop = YES;
        } else if ([key isEqualToString:@"event"]) {
            const char *event = [dict[@"event"] cStringUsingEncoding:NSASCIIStringEncoding];
            qapi_event_dispatch(event, (__bridge CFTypeRef)dict, (__bridge void *)self);
            *stop = YES;
        } else if ([key isEqualToString:@"QMP"]) {
            NSLog(@"Got QMP handshake: %@", dict);
            qmp_qmp_capabilities(false, NULL, NULL, (__bridge void *)self);
            *stop = YES;
        }
    }];
}

- (NSError *)errorForQerror:(Error *)qerr {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithCString:error_get_pretty(qerr) encoding:NSASCIIStringEncoding]}];
}

- (void)vmPowerAction:(void (*)(Error **, void *))func completion:(void (^ _Nullable)(NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        Error *qerr = NULL;
        NSError *err;
        func(&qerr, (__bridge void *)self);
        if (qerr) {
            err = [self errorForQerror:qerr];
            error_free(qerr);
        }
        if (completion) {
            completion(err);
        }
    });
}

- (void)vmPowerDownWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self vmPowerAction:qmp_system_powerdown completion:completion];
}

- (void)vmResetWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self vmPowerAction:qmp_system_reset completion:completion];
}

- (void)vmStopWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self vmPowerAction:qmp_stop completion:completion];
}

- (void)vmQuitWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self vmPowerAction:qmp_quit completion:completion];
}

@end

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
