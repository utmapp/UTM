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

#import "QEMUHelper.h"
#import "UTMQemu.h"
#import "UTMQemuImg.h"
#import "UTMQemuSystem.h"
#import "UTMLogging.h"
#import <stdio.h>

@implementation QEMUHelper {
    UTMQemu *_qemu;
    NSMutableArray<NSData *> *_bookmarks;
}

- (instancetype)init {
    if (self = [super init]) {
        _bookmarks = [NSMutableArray<NSData *> array];
    }
    return self;
}

- (void)accessDataWithBookmark:(NSData *)bookmark {
    if (_qemu == nil) {
        [_bookmarks addObject:bookmark];
    } else {
        [_qemu accessDataWithBookmark:bookmark];
    }
}

- (void)ping:(void (^)(BOOL))onResponse {
    onResponse(_qemu != nil);
}

- (void)startDylib:(NSString *)dylib type:(QEMUHelperType)type argv:(NSArray<NSString *> *)argv completion:(void(^)(BOOL,NSString *))completion {
    switch (type) {
        case QEMUHelperTypeImg:
            _qemu = [[UTMQemuImg alloc] initWithArgv:argv];
            break;
        case QEMUHelperTypeSystem:
            _qemu = [[UTMQemuSystem alloc] initWithArgv:argv];
            break;
        default:
            NSAssert(0, @"Invalid helper type.");
            break;
    }
    
    [_qemu startDylib:dylib completion:^(BOOL success, NSString *msg) {
        completion(success, msg);
        self->_qemu = nil;
    }];
    
    // pass in any bookmarks in queue
    if (_bookmarks.count > 0) {
        for (NSData *bookmark in _bookmarks) {
            [_qemu accessDataWithBookmark:bookmark];
        }
        [_bookmarks removeAllObjects];
    }
}

@end
