//
// Copyright © 2021 osy. All rights reserved.
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

#import "UTMConfiguration.h"
#import "UTM-Swift.h"

@interface UTMConfiguration ()

@property (nonatomic, readwrite) NSString *uuid;

@end

@implementation UTMConfiguration

+ (NSString *)diskImagesDirectory {
    return @"Images";
}

+ (NSString *)debugLogName {
    return @"debug.log";
}

- (instancetype)init {
    if (self = [super init]) {
        self.uuid = [[NSUUID UUID] UUIDString];
    }
    return self;
}

#pragma mark - Properties

- (void)setName:(NSString *)name {
    [self propertyWillChange];
    _name = name;
}

- (void)setExistingPath:(NSURL *)existingPath {
    [self propertyWillChange];
    _existingPath = existingPath;
}

- (void)setSelectedCustomIconPath:(NSURL *)selectedCustomIconPath {
    [self propertyWillChange];
    _selectedCustomIconPath = selectedCustomIconPath;
}

@end
