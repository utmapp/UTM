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
#import "UTMInputOutput.h"

@protocol UTMConfigurable;
@class UTMLogging;
@class CSScreenshot;

NS_ASSUME_NONNULL_BEGIN

@interface UTMVirtualMachine : NSObject

@property (nonatomic, readonly, nullable) NSURL *path;
@property (nonatomic) BOOL isShortcut;
@property (nonatomic, readonly, nullable) NSData *bookmark;
@property (nonatomic, weak, nullable) id<UTMVirtualMachineDelegate> delegate;
@property (nonatomic, readonly, copy) id<UTMConfigurable> config;
@property (nonatomic, readonly) UTMViewState *viewState;
@property (nonatomic, assign, readonly) UTMVMState state;
@property (nonatomic, readonly, nullable) CSScreenshot *screenshot;

+ (BOOL)URLisVirtualMachine:(NSURL *)url NS_SWIFT_NAME(isVirtualMachine(url:));
+ (NSString *)virtualMachineName:(NSURL *)url;
+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent;

+ (nullable UTMVirtualMachine *)virtualMachineWithURL:(NSURL *)url;
+ (nullable UTMVirtualMachine *)virtualMachineWithBookmark:(NSData *)bookmark;
+ (UTMVirtualMachine *)virtualMachineWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl;

- (BOOL)reloadConfigurationWithError:(NSError * _Nullable *)err;
- (void)saveUTMWithCompletion:(void (^)(NSError * _Nullable))completion;

- (void)accessShortcutWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

- (void)startVM;
- (void)startVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)quitVM;
- (void)quitVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)requestVmStopForce:(BOOL)force NS_SWIFT_NAME(requestVmStop(force:));
- (void)quitVMForce:(BOOL)force completion:(void (^)(NSError * _Nullable))completion NS_SWIFT_NAME(quitVM(force:completion:));
- (void)resetVM;
- (void)resetVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)pauseVM;
- (void)pauseVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)saveVM;
- (void)saveVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)deleteSaveVM;
- (void)deleteSaveVMWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)resumeVM;
- (void)resumeVMWithCompletion:(void (^)(NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
