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
#import "UTMVirtualMachineDelegate.h"

@protocol UTMConfigurable;
@class UTMLogging;
@class UTMViewState;
@class CSScreenshot;

NS_ASSUME_NONNULL_BEGIN

/// Abstract interface to a UTM virtual machine
@interface UTMVirtualMachine : NSObject

/// Path where the .utm is stored
@property (nonatomic, readonly, nullable) NSURL *path;

/// True if the .utm is loaded outside of the default storage
///
/// This property is observable and must only be accessed on the main thread. 
@property (nonatomic) BOOL isShortcut;

/// Bookmark data of the .utm bundle (can be inside or outside storage)
///
/// This is nil if a bookmark cannot be created for any reason (such as access denied)
@property (nonatomic, readonly, nullable) NSData *bookmark;

/// Set by caller to handle VM events
@property (nonatomic, weak, nullable) id<UTMVirtualMachineDelegate> delegate;

/// Configuration for this VM
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) id<UTMConfigurable> config;

/// Additional configuration on a short lived, per-host basis
///
/// This includes display size, bookmarks to removable drives, etc.
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) UTMViewState *viewState;

/// Current VM state, can observe this property for state changes or use the delegate
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, assign, readonly) UTMVMState state;

/// If non-null, is the most recent screenshot image of the running VM
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly, nullable) CSScreenshot *screenshot;

/// Display VM as "deleted" for UI elements
///
/// This is a workaround for SwiftUI bugs not hiding deleted elements.
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic) BOOL isDeleted;

/// Display VM as "busy" for UI elements
///
/// This is shorthand for checking if the `state` is one of the busy ones.
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) BOOL isBusy;

/// Whether the next start of this VM should have the -snapshot flag set
///
/// This will be passed to UTMQemuSystem,
/// and will be cleared when the VM stops or has an error.
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic) BOOL isRunningAsSnapshot;

/// Checks if a save state exists
///
/// This property is observable and must only be accessed on the main thread.
@property (nonatomic, readonly) BOOL hasSaveState;

/// Checks if a file URL is a .utm bundle
/// @param url File URL
+ (BOOL)URLisVirtualMachine:(NSURL *)url NS_SWIFT_NAME(isVirtualMachine(url:));

/// Get name of UTM virtual machine from a file
/// @param url File URL
+ (NSString *)virtualMachineName:(NSURL *)url;

/// Get the path of a UTM virtual machine from a name and parent directory
/// @param name VM name
/// @param parent Base directory file URL
+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent;

/// Create an existing UTM virtual machine from a path
/// @param url File URL
+ (nullable UTMVirtualMachine *)virtualMachineWithURL:(NSURL *)url;

/// Create an existing UTM virtual machine from a file bookmark
/// @param bookmark Bookmark data
+ (nullable UTMVirtualMachine *)virtualMachineWithBookmark:(NSData *)bookmark;

/// Create a new UTM virtual machine from a configuration
///
/// `-saveUTMWithCompletion:` should be called to save to disk.
/// @param configuration VM configuration
/// @param dstUrl Parent file URL to save to
+ (UTMVirtualMachine *)virtualMachineWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl;

/// Discard any changes to configuration by reloading from disk
/// @param err Error thrown
/// @returns True if successful
- (BOOL)reloadConfigurationWithError:(NSError * _Nullable *)err;

/// Save .utm bundle to disk
///
/// This will create a configuration file and any auxiliary data files if needed.
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)saveUTMWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Starts accessing security scoped bookmark for this .utm bundle
///
/// Must be called if this UTM VM is a shortcut. Otherwise, this will do nothing.
/// If called, on `-dealloc`, the security scoped resource will be released.
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)accessShortcutWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Starts the VM
///
/// Any error will be passed to the `delegate`
- (void)requestVmStart;

/// Starts the VM
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmStartWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Stops the VM
///
/// Waits for the VM to acknowledge the stop request before attempting to clean up.
/// Any error will be passed to the `delegate`
- (void)requestVmStop;

/// Stops the VM
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmStopWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Stops the VM without waiting
///
/// Any error will be passed to the `delegate`
/// @param force If true, will not wait for VM to stop before cleanup
- (void)requestVmStopForce:(BOOL)force NS_SWIFT_NAME(requestVmStop(force:));

/// Stops the VM
///
/// @param force If true, will not wait for VM to stop before cleanup
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmStopForce:(BOOL)force completion:(void (^)(NSError * _Nullable))completion NS_SWIFT_NAME(vmStop(force:completion:));

/// Restarts the VM
///
/// Any error will be passed to the `delegate`
- (void)requestVmReset;

/// Restarts the VM
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmResetWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Pauses the VM
///
/// Any error will be passed to the `delegate`
/// @param save Save VM state.
- (void)requestVmPauseSave:(BOOL)save NS_SWIFT_NAME(requestVmPause(save:));

/// Pauses the VM
///
/// @param save Save VM state.
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmPauseSave:(BOOL)save completion:(void (^)(NSError * _Nullable))completion NS_SWIFT_NAME(vmPause(save:completion:));

/// Saves the current VM state
///
/// Any error will be passed to the `delegate`
- (void)requestVmSaveState;

/// Saves the current VM state
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmSaveStateWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Deletes the saved VM state
///
/// Any error will be passed to the `delegate`
- (void)requestVmDeleteState;

/// Deletes the saved VM state
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmDeleteStateWithCompletion:(void (^)(NSError * _Nullable))completion;

/// Resumes a paused VM
///
/// Any error will be passed to the `delegate`
- (void)requestVmResume;

/// Resumes a paused VM
///
/// @param completion Handler always will be called on completion
/// @returns Any error thrown will be non-null passed to the `completion` handler
- (void)vmResumeWithCompletion:(void (^)(NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
