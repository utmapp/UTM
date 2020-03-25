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

@interface UTMViewState : NSObject

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

@property (nonatomic, assign) double displayScale;
@property (nonatomic, assign) double displayOriginX;
@property (nonatomic, assign) double displayOriginY;
@property (nonatomic, assign) double displaySizeWidth;
@property (nonatomic, assign) double displaySizeHeight;
@property (nonatomic, assign) BOOL showToolbar;
@property (nonatomic, assign) BOOL showKeyboard;
@property (nonatomic, assign) BOOL suspended;

- (id)initDefaults;
- (id)initWithDictionary:(NSMutableDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
