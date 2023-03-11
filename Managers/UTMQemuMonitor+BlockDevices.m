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

#import "UTMQemuMonitor+BlockDevices.h"
#import "UTMQemuManager-Protected.h"
#import "UTMLogging.h"
#import "qapi-commands.h"
#import "error.h"

@implementation UTMQemuMonitor (BlockDevices)

- (NSDictionary<NSString *, NSString *> *)removableDrives {
    if (!self.isConnected) {
        return nil;
    }
    BlockInfoList *block = NULL;
    Error *qerr = NULL;
    block = qmp_query_block(&qerr, (__bridge void *)self);
    if (qerr) {
        UTMLog(@"Failed to query drives: %s", error_get_pretty(qerr));
        error_free(qerr);
        return nil;
    }
    if (!block) {
        UTMLog(@"Invalid return for query-block");
        return nil;
    }
    id dict = [NSMutableDictionary<NSString *, NSString *> dictionary];
    for (BlockInfoList *list = block; list->next; list = list->next) {
        const BlockInfo *info = list->value;
        if (info->removable) {
            NSString *drive = [NSString stringWithUTF8String:info->device];
            NSString *file;
            if (info->has_inserted) {
                file = [NSString stringWithUTF8String:info->inserted->file];
            } else {
                file = @"";
            }
            dict[drive] = file;
        }
    }
    qapi_free_BlockInfoList(block);
    return dict;
}

- (BOOL)ejectDrive:(NSString *)drive force:(BOOL)force error:(NSError * _Nullable *)error {
    Error *qerr = NULL;
    qmp_eject(true, [drive cStringUsingEncoding:NSUTF8StringEncoding], false, NULL, true, force, &qerr, (__bridge void *)self);
    if (qerr) {
        if (error) {
            *error = [self errorForQerror:qerr];
        }
        error_free(qerr);
        return NO;
    }
    return YES;
}

- (BOOL)changeMediumForDrive:(NSString *)drive path:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error {
    Error *qerr = NULL;
    qmp_blockdev_change_medium(true, [drive cStringUsingEncoding:NSUTF8StringEncoding], false, NULL, [path cStringUsingEncoding:NSUTF8StringEncoding], false, NULL, false, false, false, BLOCKDEV_CHANGE_READ_ONLY_MODE_RETAIN, &qerr, (__bridge void *)self);
    if (qerr) {
        if (error) {
            *error = [self errorForQerror:qerr];
        }
        error_free(qerr);
        return NO;
    }
    return YES;
}

@end
