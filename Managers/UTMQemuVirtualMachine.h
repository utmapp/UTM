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

#import "UTMVirtualMachine.h"
#import "UTMSpiceIODelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemuVirtualMachine : UTMVirtualMachine

@property (nonatomic, weak, nullable) id<UTMSpiceIODelegate> ioDelegate;

/// Set to true to request guest tools install.
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic) BOOL isGuestToolsInstallRequested;

/// Sends power off request to the guest
- (void)requestGuestPowerDown;

@end

NS_ASSUME_NONNULL_END
