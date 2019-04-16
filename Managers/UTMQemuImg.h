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

typedef NS_ENUM(NSUInteger, UTMQemuImgOperation) {
    kUTMQemuImgNoop,
    kUTMQemuImgCheck,
    kUTMQemuImgCreate,
    kUTMQemuImgCommit,
    kUTMQemuImgConvert,
    kUTMQemuImgInfo,
    kUTMQemuImgSnapshotList,
    kUTMQemuImgSnapshotApply,
    kUTMQemuImgSnapshotCreate,
    kUTMQemuImgSnapshotDelete,
    kUTMQemuImgRebase,
    kUTMQemuImgResize
};

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemuImg : NSObject

@property (nonatomic, assign) UTMQemuImgOperation op;
@property (nonatomic, strong) NSURL *outputPath;
@property (nonatomic, strong) NSURL *inputPath;
@property (nonatomic, assign) NSUInteger sizeMiB;
@property (nonatomic, assign) BOOL compressed;
@property (nonatomic, assign) BOOL encrypted;
@property (nonatomic, strong) NSString *password; // TODO: Use keychain
@property (nonatomic, assign) NSUInteger snapshotID;

- (void)startWithCompletion:(void(^)(BOOL, NSString *))completion;

@end

NS_ASSUME_NONNULL_END
