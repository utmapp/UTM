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

#import "UTMLegacyViewState.h"

const NSString *const kUTMViewStateDisplayScaleKey = @"DisplayScale";
const NSString *const kUTMViewStateDisplayOriginXKey = @"DisplayOriginX";
const NSString *const kUTMViewStateDisplayOriginYKey = @"DisplayOriginY";
const NSString *const kUTMViewStateShowToolbarKey = @"ShowToolbar";
const NSString *const kUTMViewStateShowKeyboardKey = @"ShowKeyboard";
const NSString *const kUTMViewStateSuspendedKey = @"Suspended";
const NSString *const kUTMViewStateSharedDirectoryKey = @"SharedDirectory";
const NSString *const kUTMViewStateSharedDirectoryPathKey = @"SharedDirectoryPath";
const NSString *const kUTMViewStateShortcutBookmarkKey = @"ShortcutBookmark";
const NSString *const kUTMViewStateShortcutBookmarkPathKey = @"ShortcutBookmarkPath";
const NSString *const kUTMViewStateRemovableDrivesKey = @"RemovableDrives";
const NSString *const kUTMViewStateRemovableDrivesPathKey = @"RemovableDrivesPath";

@implementation UTMLegacyViewState {
    NSMutableDictionary *_rootDict;
    NSMutableDictionary<NSString *, NSData *> *_removableDrives;
    NSMutableDictionary<NSString *, NSString *> *_removableDrivesPath;
}

#pragma mark - Properties

- (NSDictionary *)dictRepresentation {
    return (NSDictionary *)_rootDict;
}

- (CGFloat)displayScale {
    return [_rootDict[kUTMViewStateDisplayScaleKey] floatValue];
}

- (CGFloat)displayOriginX {
    return [_rootDict[kUTMViewStateDisplayOriginXKey] floatValue];
}

- (CGFloat)displayOriginY {
    return [_rootDict[kUTMViewStateDisplayOriginYKey] floatValue];
}

- (BOOL)isKeyboardShown {
    return [_rootDict[kUTMViewStateShowToolbarKey] boolValue];
}

- (BOOL)isToolbarShown {
    return [_rootDict[kUTMViewStateShowToolbarKey] boolValue];
}

- (BOOL)hasSaveState {
    return [_rootDict[kUTMViewStateSuspendedKey] boolValue];
}

- (NSData *)sharedDirectory {
    return _rootDict[kUTMViewStateSharedDirectoryKey];
}

- (NSString *)sharedDirectoryPath {
    return _rootDict[kUTMViewStateSharedDirectoryPathKey];
}

- (NSData *)shortcutBookmark {
    return _rootDict[kUTMViewStateShortcutBookmarkKey];
}

- (NSString *)shortcutBookmarkPath {
    return _rootDict[kUTMViewStateShortcutBookmarkPathKey];
}

#pragma mark - Removable drives

- (NSArray<NSString *> *)allDrives {
    return [_removableDrives allKeys];
}

- (nullable NSData *)bookmarkForRemovableDrive:(NSString *)drive {
    return _removableDrives[drive];
}

- (nullable NSString *)pathForRemovableDrive:(NSString *)drive {
    return _removableDrivesPath[drive];
}

#pragma mark - Init

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _rootDict = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)dictionary, kCFPropertyListMutableContainers));
        _removableDrives = _rootDict[kUTMViewStateRemovableDrivesKey];
        _removableDrivesPath = _rootDict[kUTMViewStateRemovableDrivesPathKey];
        if (!_removableDrives) {
            _removableDrives = [NSMutableDictionary dictionary];
            _rootDict[kUTMViewStateRemovableDrivesKey] = _removableDrives;
        }
        if (!_removableDrivesPath) {
            _removableDrivesPath = [NSMutableDictionary dictionary];
            _rootDict[kUTMViewStateRemovableDrivesPathKey] = _removableDrivesPath;
        }
    }
    return self;
}

@end
