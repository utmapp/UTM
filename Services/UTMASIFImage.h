//
// Copyright © 2025 osy. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

@interface UTMASIFImage : NSObject

+ (nullable instancetype)sharedInstance;

- (BOOL)createBlankWithURL:(NSURL *)url numBlocks:(NSInteger)numBlocks error:(NSError * _Nullable *)error API_AVAILABLE(macosx(13), ios(16), tvos(16), watchos(9));
- (BOOL)resizeWithURL:(NSURL *)url size:(NSInteger)size error:(NSError * _Nullable *)error API_AVAILABLE(macosx(14), ios(17), tvos(17), watchos(10));
- (nullable NSDictionary<NSString *, NSObject *> *)retrieveInfo:(NSURL *)url error:(NSError * _Nullable *)error API_AVAILABLE(macosx(14), ios(17), tvos(17), watchos(10));

@end

NS_ASSUME_NONNULL_END
