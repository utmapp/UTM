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

#import "UTMViewState.h"
#import "UTM-Swift.h"

const NSString *const kUTMViewStateDisplayScaleKey = @"DisplayScale";
const NSString *const kUTMViewStateDisplayOriginXKey = @"DisplayOriginX";
const NSString *const kUTMViewStateDisplayOriginYKey = @"DisplayOriginY";
const NSString *const kUTMViewStateDisplaySizeWidthKey = @"DisplaySizeWidth";
const NSString *const kUTMViewStateDisplaySizeHeightKey = @"DisplaySizeHeight";
const NSString *const kUTMViewStateShowToolbarKey = @"ShowToolbar";
const NSString *const kUTMViewStateShowKeyboardKey = @"ShowKeyboard";
const NSString *const kUTMViewStateSuspendedKey = @"Suspended";
const NSString *const kUTMViewStateSharedDirectoryKey = @"SharedDirectory";
const NSString *const kUTMViewStateSharedDirectoryPathKey = @"SharedDirectoryPath";
const NSString *const kUTMViewStateRemovableDrivesKey = @"RemovableDrives";
const NSString *const kUTMViewStateRemovableDrivesPathKey = @"RemovableDrivesPath";

@interface UTMViewState ()

@property (nonatomic, nullable) NSURL *path;

@end

@implementation UTMViewState {
    NSMutableDictionary *_rootDict;
    NSMutableDictionary<NSString *, NSData *> *_removableDrives;
    NSMutableDictionary<NSString *, NSData *> *_removableDrivesTemp;
    NSMutableDictionary<NSString *, NSString *> *_removableDrivesPath;
    NSMutableDictionary<NSString *, NSString *> *_removableDrivesPathTemp;
    BOOL _deleted;
    BOOL _active;
}

#pragma mark - Properties

- (NSDictionary *)dictRepresentation {
    return (NSDictionary *)_rootDict;
}

- (double)displayScale {
    return [_rootDict[kUTMViewStateDisplayScaleKey] doubleValue];
}

- (void)setDisplayScale:(double)displayScale {
    [self propertyWillChange];
    _rootDict[kUTMViewStateDisplayScaleKey] = @(displayScale);
}

- (double)displayOriginX {
    return [_rootDict[kUTMViewStateDisplayOriginXKey] doubleValue];
}

- (void)setDisplayOriginX:(double)displayOriginX {
    [self propertyWillChange];
    _rootDict[kUTMViewStateDisplayOriginXKey] = @(displayOriginX);
}

- (double)displayOriginY {
    return [_rootDict[kUTMViewStateDisplayOriginYKey] doubleValue];
}

- (void)setDisplayOriginY:(double)displayOriginY {
    [self propertyWillChange];
    _rootDict[kUTMViewStateDisplayOriginYKey] = @(displayOriginY);
}

- (double)displaySizeWidth {
    return [_rootDict[kUTMViewStateDisplaySizeWidthKey] doubleValue];
}

- (void)setDisplaySizeWidth:(double)displaySizeWidth {
    [self propertyWillChange];
    _rootDict[kUTMViewStateDisplaySizeWidthKey] = @(displaySizeWidth);
}

- (double)displaySizeHeight {
    return [_rootDict[kUTMViewStateDisplaySizeHeightKey] doubleValue];
}

- (void)setDisplaySizeHeight:(double)displaySizeHeight {
    [self propertyWillChange];
    _rootDict[kUTMViewStateDisplaySizeHeightKey] = @(displaySizeHeight);
}

- (BOOL)showToolbar {
    return [_rootDict[kUTMViewStateShowToolbarKey] boolValue];
}

- (void)setShowToolbar:(BOOL)showToolbar {
    [self propertyWillChange];
    _rootDict[kUTMViewStateShowToolbarKey] = @(showToolbar);
}

- (BOOL)showKeyboard {
    return [_rootDict[kUTMViewStateShowKeyboardKey] boolValue];
}

- (void)setShowKeyboard:(BOOL)showKeyboard {
    [self propertyWillChange];
    _rootDict[kUTMViewStateShowKeyboardKey] = @(showKeyboard);
}

- (BOOL)suspended {
    return [_rootDict[kUTMViewStateSuspendedKey] boolValue];
}

- (void)setSuspended:(BOOL)suspended {
    [self propertyWillChange];
    _rootDict[kUTMViewStateSuspendedKey] = @(suspended);
}

- (BOOL)deleted {
    return _deleted;
}

- (void)setDeleted:(BOOL)deleted {
    [self propertyWillChange];
    _deleted = deleted;
}

- (BOOL)active {
    return _active;
}

- (void)setActive:(BOOL)active {
    [self propertyWillChange];
    _active = active;
}

- (NSData *)sharedDirectory {
    return _rootDict[kUTMViewStateSharedDirectoryKey];
}

- (void)setSharedDirectory:(NSData *)sharedDirectory {
    [self propertyWillChange];
    if (sharedDirectory) {
        _rootDict[kUTMViewStateSharedDirectoryKey] = sharedDirectory;
    } else {
        [_rootDict removeObjectForKey:kUTMViewStateSharedDirectoryKey];
    }
}

- (NSString *)sharedDirectoryPath {
    return _rootDict[kUTMViewStateSharedDirectoryPathKey];
}

- (void)setSharedDirectoryPath:(NSString *)sharedDirectoryPath {
    [self propertyWillChange];
    if (sharedDirectoryPath) {
        _rootDict[kUTMViewStateSharedDirectoryPathKey] = sharedDirectoryPath;
    } else {
        [_rootDict removeObjectForKey:kUTMViewStateSharedDirectoryPathKey];
    }
}

#pragma mark - Removable drives

- (void)setBookmark:(NSData *)bookmark path:(NSString *)path forRemovableDrive:(NSString *)drive persistent:(BOOL)persistent {
    [self propertyWillChange];
    if (persistent) {
        _removableDrives[drive] = bookmark;
        _removableDrivesPath[drive] = path;
        [_removableDrivesTemp removeObjectForKey:drive];
        [_removableDrivesPathTemp removeObjectForKey:drive];
    } else {
        _removableDrivesTemp[drive] = bookmark;
        _removableDrivesPathTemp[drive] = path;
    }
}

- (void)removeBookmarkForRemovableDrive:(NSString *)drive {
    [self propertyWillChange];
    [_removableDrives removeObjectForKey:drive];
    [_removableDrivesTemp removeObjectForKey:drive];
    [_removableDrivesPath removeObjectForKey:drive];
    [_removableDrivesPathTemp removeObjectForKey:drive];
}

- (nullable NSData *)bookmarkForRemovableDrive:(NSString *)drive persistent:(out BOOL *)persistent {
    NSData *temp = _removableDrivesTemp[drive];
    if (temp) {
        *persistent = NO;
        return temp;
    } else {
        *persistent = YES;
        return _removableDrives[drive];
    }
}

- (nullable NSString *)pathForRemovableDrive:(NSString *)drive {
    NSString *temp = _removableDrivesPathTemp[drive];
    if (temp) {
        return temp;
    } else {
        return _removableDrivesPath[drive];
    }
}

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _rootDict = [NSMutableDictionary dictionary];
        _removableDrives = [NSMutableDictionary dictionary];
        _removableDrivesTemp = [NSMutableDictionary dictionary];
        _removableDrivesPath = [NSMutableDictionary dictionary];
        _removableDrivesPathTemp = [NSMutableDictionary dictionary];
        _rootDict[kUTMViewStateRemovableDrivesKey] = _removableDrives;
        _rootDict[kUTMViewStateRemovableDrivesPathKey] = _removableDrivesPath;
        self.displayScale = 1.0;
        self.displayOriginX = 0;
        self.displayOriginY = 0;
        self.displaySizeWidth = 0;
        self.displaySizeHeight = 0;
        self.showKeyboard = NO;
        self.showToolbar = YES;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _rootDict = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)dictionary, kCFPropertyListMutableContainers));
        _removableDrives = _rootDict[kUTMViewStateRemovableDrivesKey];
        _removableDrivesPath = _rootDict[kUTMViewStateRemovableDrivesPathKey];
        _removableDrivesTemp = [NSMutableDictionary dictionary];
        _removableDrivesPathTemp = [NSMutableDictionary dictionary];
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
