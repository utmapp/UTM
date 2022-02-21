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
@property (nonatomic, readonly) NSString *detailsTitleLabel;

/// Display subtitle for UI elements
@property (nonatomic, readonly) NSString *detailsSubtitleLabel;

/// Display icon path for UI elements
@property (nonatomic, nullable, readonly) NSURL *detailsIconUrl;

/// Display user-specified notes for UI elements
@property (nonatomic, nullable, readonly) NSString *detailsNotes;

/// Display VM target system for UI elements
@property (nonatomic, readonly) NSString *detailsSystemTargetLabel;

/// Display VM architecture for UI elements
@property (nonatomic, readonly) NSString *detailsSystemArchitectureLabel;

/// Display RAM (formatted) for UI elements
@property (nonatomic, readonly) NSString *detailsSystemMemoryLabel;

@property (nonatomic, readwrite, nullable) NSURL *path;
@property (nonatomic, readwrite, copy) id<UTMConfigurable> config;
@property (nonatomic, readwrite, nullable) CSScreenshot *screenshot;

/// Checks if a given path contains an Apple VM
/// @param path Path to check
/// @returns true if `path` is valid and points to an Apple UTM VM
+ (BOOL)isAppleVMForPath:(NSURL *)path;

/// Get a URL for a .utm package
/// @param name Name of package
/// @returns URL of the package that may not exist
- (NSURL *)packageURLForName:(NSString *)name;

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

/// Reload configuration from disk
/// @param reload Attempt to re-use the existing config object
/// @param err Error thrown if failed
/// @returns true if successful, otherwise `err` contains the thrown error
- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err;

/// Load screenshot from disk
- (void)loadScreenshot;

/// Save screenshot to disk
- (void)saveScreenshot;

/// Delete existing screenshot on disk
- (void)deleteScreenshot;

/// Overridden by subclass to provide an update to `self.screenshot`
- (void)updateScreenshot;

@end

NS_ASSUME_NONNULL_END
