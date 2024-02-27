//
// Copyright © 2024 osy. All rights reserved.
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

@protocol UTMRemoteConnectDelegate;

NS_ASSUME_NONNULL_BEGIN

@protocol UTMRemoteConnectInterface <NSObject>

@property (nonatomic, weak) id<UTMRemoteConnectDelegate> connectDelegate;

- (BOOL)connectWithError:(NSError * _Nullable *)error;
- (void)disconnect;

@end

@protocol UTMRemoteConnectDelegate <NSObject>

- (void)remoteInterface:(id<UTMRemoteConnectInterface>)remoteInterface didErrorWithMessage:(NSString *)message;
- (void)remoteInterfaceDidConnect:(id<UTMRemoteConnectInterface>)remoteInterface;

@end

NS_ASSUME_NONNULL_END
