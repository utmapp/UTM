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

typedef enum ShutdownCause ShutdownCause;

NS_ASSUME_NONNULL_BEGIN

@class UTMQemuManager;

@protocol UTMQemuManagerDelegate <NSObject>

- (void)qemuHasStopped:(UTMQemuManager *)manager;
- (void)qemuHasReset:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason;
- (void)qemuHasResumed:(UTMQemuManager *)manager;
- (void)qemuHasSuspended:(UTMQemuManager *)manager;
- (void)qemuHasWakeup:(UTMQemuManager *)manager;
- (void)qemuWillQuit:(UTMQemuManager *)manager guest:(BOOL)guest reason:(ShutdownCause)reason;
- (void)qemuError:(UTMQemuManager *)manager error:(NSString *)error;
- (void)qemuQmpDidConnect:(UTMQemuManager *)manager;

@end

NS_ASSUME_NONNULL_END
