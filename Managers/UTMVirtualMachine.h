//
// Copyright © 2019 Halts. All rights reserved.
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

@class UTMConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface UTMVirtualMachine : NSObject

@property (nonatomic, strong) id<UTMVirtualMachineDelegate> delegate;
@property (nonatomic, strong) NSURL *parentPath;
@property (nonatomic, strong) UTMConfiguration *configuration;
@property (nonatomic, assign, readonly) UTMVMState state;

+ (BOOL)URLisVirtualMachine:(NSURL *)url;
+ (NSString *)virtualMachineName:(NSURL *)url;
+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent;
- (id)initWithURL:(NSURL *)url;
- (id)initDefaults:(NSString *)name withDestinationURL:(NSURL *)dstUrl;
- (void)saveUTMWithError:(NSError * _Nullable *)err;

@end

NS_ASSUME_NONNULL_END
