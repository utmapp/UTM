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

NS_ASSUME_NONNULL_BEGIN

@interface UTMVirtualMachine ()

/// Parent directory where the .utm bundle resides, may not be accessible if this is a shortcut
@property (nonatomic, strong) NSURL *parentPath;

@property (nonatomic, readwrite) UTMViewState *viewState;

/// Reference to logger for VM stdout/stderr
@property (nonatomic) UTMLogging *logging;

@property (nonatomic, assign, readwrite) UTMVMState state;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl;

/// Load a plist into a NSDictionary representation
/// @param path Path to plist
/// @param err Error thrown if failed
/// @returns A dictionary on success, nil on failure and `err` contains the thrown error
- (NSDictionary *)loadPlist:(NSURL *)path withError:(NSError **)err;

/// Saves a plist to disk
/// @param path Path to save to
/// @param dict Dictionary to convert to plist
/// @param err Error thrown if failed
/// @returns true if successful, otherwise `err` contains the thrown error
- (BOOL)savePlist:(NSURL *)path dict:(NSDictionary *)dict withError:(NSError **)err;

/// (Re)loads the view state from disk
- (void)loadViewState;

/// Saves the current view state to disk
- (void)saveViewState;

@end

NS_ASSUME_NONNULL_END
