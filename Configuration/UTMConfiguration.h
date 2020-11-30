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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration : NSObject<NSCopying>

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, nullable, copy) NSURL *existingPath;
@property (nonatomic, nullable, copy) NSURL *selectedCustomIconPath;
@property (nonatomic, nullable, copy) NSNumber *version;

- (void)migrateConfigurationIfNecessary;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path NS_DESIGNATED_INITIALIZER;

- (NSURL*)terminalInputOutputURL;
- (void)resetDefaults;
- (void)reloadConfigurationWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path;

@end

NS_ASSUME_NONNULL_END
