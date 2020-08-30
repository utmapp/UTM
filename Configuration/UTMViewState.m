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
const NSString *const kUTMViewStateRemovableDrivesKey = @"RemovableDrives";

@interface UTMViewState ()

@property (nonatomic, nullable) NSURL *path;

@end

@implementation UTMViewState {
    NSMutableDictionary *_rootDict;
    NSMutableDictionary<NSString *, NSData *> *_removableDrives;
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

#pragma mark - Removable drives

- (void)setBookmark:(NSData *)bookmark forRemovableDrive:(NSString *)drive {
    [self propertyWillChange];
    _removableDrives[drive] = bookmark;
}

- (void)removeBookmarkForRemovableDrive:(NSString *)drive {
    [self propertyWillChange];
    [_removableDrives removeObjectForKey:drive];
}

- (nullable NSData *)bookmarkForRemovableDrive:(NSString *)drive {
    return _removableDrives[drive];
}

#pragma mark - Init

- (instancetype)initDefaults {
    self = [super init];
    if (self) {
        _rootDict = [NSMutableDictionary dictionary];
        _removableDrives = [NSMutableDictionary dictionary];
        _rootDict[kUTMViewStateRemovableDrivesKey] = _removableDrives;
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

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary {
    self = [super init];
    if (self) {
        _rootDict = dictionary;
        _removableDrives = dictionary[kUTMViewStateRemovableDrivesKey];
        if (!_removableDrives) {
            _removableDrives = [NSMutableDictionary dictionary];
            _rootDict[kUTMViewStateRemovableDrivesKey] = _removableDrives;
        }
    }
    return self;
}

@end
