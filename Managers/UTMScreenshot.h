//
// Copyright © 2020 osy. All rights reserved.
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

#import "TargetConditionals.h"
#if TARGET_OS_IPHONE
#include <UIKit/UIKit.h>
#else
#include <AppKit/AppKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface UTMScreenshot : NSObject

@property (class, nonatomic, readonly) UTMScreenshot *none;

#if TARGET_OS_IPHONE
@property (nonatomic, readonly, nullable) UIImage *image;
#else
@property (nonatomic, readonly, nullable) NSImage *image;
#endif

- (instancetype)init NS_DESIGNATED_INITIALIZER;
#if TARGET_OS_IPHONE
- (instancetype)initWithImage:(UIImage *)image;
#else
- (instancetype)initWithImage:(NSImage *)image;
#endif
- (instancetype)initWithContentsOfURL:(NSURL *)url;
- (void)writeToURL:(NSURL *)url atomically:(BOOL)atomically;

@end

NS_ASSUME_NONNULL_END
