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

@protocol UTMConfigurable;
@class UTMVirtualMachine;
@class CSDisplayMetal;
@class CSInput;

NS_ASSUME_NONNULL_BEGIN

/// VM operation states
typedef NS_ENUM(NSUInteger, UTMVMState) {
    kVMStopped,
    kVMStarting,
    kVMStarted,
    kVMPausing,
    kVMPaused,
    kVMResuming,
    kVMStopping
};

/// Handles UTM VM events
@protocol UTMVirtualMachineDelegate <NSObject>

/// Called when VM state changes
///
/// Will always be called from the main thread.
/// @param vm Virtual machine
/// @param state New state
- (void)virtualMachine:(UTMVirtualMachine *)vm didTransitionToState:(UTMVMState)state;

/// Called when VM errors
///
/// Will always be called from the main thread.
/// @param vm Virtual machine
/// @param message Localized error message when supported, English message otherwise
- (void)virtualMachine:(UTMVirtualMachine *)vm didErrorWithMessage:(NSString *)message;

@optional

/// Called when VM installation updates progress
/// @param vm Virtual machine
/// @param progress Number between 0.0 and 1.0 indiciating installation progress
- (void)virtualMachine:(UTMVirtualMachine *)vm didUpdateInstallationProgress:(double)progress;

@end

NS_ASSUME_NONNULL_END
