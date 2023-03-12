//
// Copyright © 2023 osy. All rights reserved.
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

#import "UTMQemuManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Interface with QEMU Guest Agent
@interface UTMQemuGuestAgent : UTMQemuManager

/// Attempt synchronization with guest agent
///
/// If an error is returned, any number of things could have happened including:
///   * Guest Agent has not started on the guest side
///   * Guest Agent has not been installed yet
///   * Guest Agent is too slow to respond
/// - Parameter completion: Callback to run on completion
- (void)synchronizeWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Set guest time
/// - Parameters:
///   - time: time in seconds, relative to the Epoch of 1970-01-01 in UTC.
///   - completion: Callback to run on completion
- (void)guestSetTime:(NSTimeInterval)time withCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
