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

@class UTMQemuMonitor;

@protocol UTMQemuMonitorDelegate <NSObject>

- (void)qemuHasStopped:(UTMQemuMonitor *)monitor;
- (void)qemuHasReset:(UTMQemuMonitor *)monitor guest:(BOOL)guest reason:(ShutdownCause)reason;
- (void)qemuHasResumed:(UTMQemuMonitor *)monitor;
- (void)qemuHasSuspended:(UTMQemuMonitor *)monitor;
- (void)qemuHasWakeup:(UTMQemuMonitor *)monitor;
- (void)qemuWillQuit:(UTMQemuMonitor *)monitor guest:(BOOL)guest reason:(ShutdownCause)reason;
- (void)qemuError:(UTMQemuMonitor *)monitor error:(NSString *)error;
- (void)qemuQmpDidConnect:(UTMQemuMonitor *)monitor;

@end

NS_ASSUME_NONNULL_END
