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
#import "CSConnectionDelegate.h"
#import "UTMRenderSource.h"
#import "UTMQemuManagerDelegate.h"
#import "UTMInputOutput.h"

@class UTMConfiguration;
@class UTMLogging;
@class UTMQemuManager;
@class UTMScreenshot;

typedef NS_ENUM(NSInteger, UTMDisplayType) {
    UTMDisplayTypeFullGraphic,
    UTMDisplayTypeConsole
};

NS_ASSUME_NONNULL_BEGIN

@interface UTMVirtualMachine : NSObject<UTMQemuManagerDelegate>

@property (nonatomic, readonly, nullable) NSURL *path;
@property (nonatomic, weak, nullable) id<UTMVirtualMachineDelegate> delegate;
@property (nonatomic, weak, nullable) id ioDelegate;
@property (nonatomic, strong) NSURL *parentPath;
@property (nonatomic, readonly, copy) UTMConfiguration *configuration;
@property (nonatomic, readonly) UTMViewState *viewState;
@property (nonatomic, assign, readonly) UTMVMState state;
@property (nonatomic, readonly) BOOL busy;
@property (nonatomic, readonly, nullable) UTMScreenshot *screenshot;

+ (BOOL)URLisVirtualMachine:(NSURL *)url NS_SWIFT_NAME(isVirtualMachine(url:));
+ (NSString *)virtualMachineName:(NSURL *)url;
+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithConfiguration:(UTMConfiguration *)configuration withDestinationURL:(NSURL *)dstUrl;

- (BOOL)reloadConfigurationWithError:(NSError * _Nullable *)err;
- (BOOL)saveUTMWithError:(NSError * _Nullable *)err;

- (BOOL)startVM;
- (BOOL)quitVM;
- (BOOL)resetVM;
- (BOOL)pauseVM;
- (BOOL)saveVM;
- (BOOL)deleteSaveVM;
- (BOOL)resumeVM;

- (UTMDisplayType)supportedDisplayType;

@end

NS_ASSUME_NONNULL_END
