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

@class UIImage;
@class UTMViewState;

NS_ASSUME_NONNULL_BEGIN

@protocol UTMInputOutput <NSObject>

- (BOOL)startWithError:(NSError **)err;
- (void)connectWithCompletion: (void(^)(BOOL, NSError* _Nullable)) block;
- (void)disconnect;
- (void)setDebugMode: (BOOL)debugMode;
- (UIImage* _Nullable)screenshot;
- (void)syncViewState:(UTMViewState *)viewState;
- (void)restoreViewState:(UTMViewState *)viewState;

@end

NS_ASSUME_NONNULL_END
