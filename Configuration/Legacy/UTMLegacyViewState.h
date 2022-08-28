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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UTMLegacyViewState : NSObject

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) CGFloat displayOriginX;
@property (nonatomic, readonly) CGFloat displayOriginY;
@property (nonatomic, readonly) BOOL isKeyboardShown;
@property (nonatomic, readonly) BOOL isToolbarShown;
@property (nonatomic, readonly) BOOL hasSaveState;
@property (nonatomic, readonly, nullable) NSData *sharedDirectory;
@property (nonatomic, readonly, nullable) NSString *sharedDirectoryPath;
@property (nonatomic, readonly, nullable) NSData *shortcutBookmark;
@property (nonatomic, readonly, nullable) NSString *shortcutBookmarkPath;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (NSArray<NSString *> *)allDrives;
- (nullable NSData *)bookmarkForRemovableDrive:(NSString *)drive;
- (nullable NSString *)pathForRemovableDrive:(NSString *)drive;

@end

NS_ASSUME_NONNULL_END
