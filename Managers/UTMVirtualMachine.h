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
@class UTMQemuManager;

typedef NS_ENUM(NSInteger, UTMDisplayType) {
    UTMDisplayTypeFullGraphic,
    UTMDisplayTypeConsole
};

NS_ASSUME_NONNULL_BEGIN

@interface UTMVirtualMachine : NSObject<UTMQemuManagerDelegate>

@property (nonatomic, readonly, nullable) id<UTMInputOutput> ioService;
@property (nonatomic, readonly) NSURL *path;
@property (nonatomic, weak, nullable) id<UTMVirtualMachineDelegate> delegate;
@property (nonatomic, strong) NSURL *parentPath;
@property (nonatomic, strong, readonly) UTMConfiguration *configuration;
@property (nonatomic, assign, readonly) UTMVMState state;
@property (nonatomic, readonly, nullable) UTMQemuManager *qemu;
@property (nonatomic, readonly) BOOL busy;
@property (nonatomic, readonly) UIImage *screenshot;

+ (BOOL)URLisVirtualMachine:(NSURL *)url;
+ (NSString *)virtualMachineName:(NSURL *)url;
+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent;

- (id)initWithURL:(NSURL *)url;
- (id)initWithConfiguration:(UTMConfiguration *)configuration withDestinationURL:(NSURL *)dstUrl;

- (BOOL)saveUTMWithError:(NSError * _Nullable *)err;

- (BOOL)startVM;
- (BOOL)quitVM;
- (BOOL)resetVM;
- (BOOL)pauseVM;
- (BOOL)saveVM;
- (BOOL)deleteSaveVM;
- (BOOL)resumeVM;

- (UTMDisplayType)supportedDisplayType;
- (void)requestInputTablet:(BOOL)tablet completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
