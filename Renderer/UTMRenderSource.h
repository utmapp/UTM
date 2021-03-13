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
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@protocol UTMRenderSource <NSObject>

@property (nonatomic, readonly) BOOL cursorVisible;
@property (nonatomic) CGPoint cursorOrigin;
@property (nonatomic) CGPoint viewportOrigin;
@property (nonatomic) CGFloat viewportScale;
@property (nonatomic, readonly) dispatch_semaphore_t drawLock;
@property (nonatomic, nullable) id<MTLDevice> device;
@property (nonatomic, nullable, readonly) id<MTLTexture> displayTexture;
@property (nonatomic, nullable, readonly) id<MTLTexture> cursorTexture;
@property (nonatomic, readonly) NSUInteger displayNumVertices;
@property (nonatomic, readonly) NSUInteger cursorNumVertices;
@property (nonatomic, nullable, readonly) id<MTLBuffer> displayVertices;
@property (nonatomic, nullable, readonly) id<MTLBuffer> cursorVertices;

@end

NS_ASSUME_NONNULL_END
