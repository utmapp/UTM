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

@class CSScreenshot;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kUTMBundleConfigFilename;

@interface UTMVirtualMachine ()

/// Display title for UI elements
///
/// This property is observable and must only be accessed on the main thread. 
@property (nonatomic, readonly) NSString *detailsTitleLabel;

/// Display subtitle for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) NSString *detailsSubtitleLabel;

/// Display icon path for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, nullable, readonly) NSURL *detailsIconUrl;

/// Display user-specified notes for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, nullable, readonly) NSString *detailsNotes;

/// Display VM target system for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) NSString *detailsSystemTargetLabel;

/// Display VM architecture for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) NSString *detailsSystemArchitectureLabel;

/// Display RAM (formatted) for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) NSString *detailsSystemMemoryLabel;

/// Display current VM state as a string for UI elements
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) NSString *stateLabel;

@property (nonatomic, readwrite) NSURL *path;
@property (nonatomic, readwrite) UTMConfigurationWrapper *config;
@property (nonatomic, readwrite, nullable) CSScreenshot *screenshot;
@property (nonatomic, readwrite) UTMRegistryEntry *registryEntry;
@property (nonatomic) NSArray *anyCancellable;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithConfiguration:(UTMConfigurationWrapper *)configuration packageURL:(NSURL *)packageURL NS_DESIGNATED_INITIALIZER;

/// Updates the internal state and view state
/// @param state New state
- (void)changeState:(UTMVMState)state;

/// Creates an error with a generic message
/// @returns Generic UTM error
- (NSError *)errorGeneric;

/// Creates an error with a specified message
/// @param message Localized message if possible
/// @returns UTM error with the localized description set to `message`
- (NSError *)errorWithMessage:(nullable NSString *)message;

/// Save screenshot to disk
- (void)saveScreenshot;

/// Delete existing screenshot on disk
- (void)deleteScreenshot;

/// Overridden by subclass to provide an update to `self.screenshot`
- (void)updateScreenshot;

@end

NS_ASSUME_NONNULL_END
