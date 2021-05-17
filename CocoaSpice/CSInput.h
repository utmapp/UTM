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
#import "UTMRenderSource.h"
@import CoreGraphics;

typedef struct _SpiceSession SpiceSession;

typedef NS_ENUM(NSInteger, CSInputKey) {
    kCSInputKeyPress,
    kCSInputKeyRelease
};

typedef NS_OPTIONS(NSUInteger, CSInputButton) {
    kCSInputButtonNone = 0,
    kCSInputButtonLeft = (1 << 0),
    kCSInputButtonMiddle = (1 << 1),
    kCSInputButtonRight = (1 << 2)
};

typedef NS_ENUM(NSInteger, CSInputScroll) {
    kCSInputScrollUp,
    kCSInputScrollDown,
    kCSInputScrollSmooth
};

NS_ASSUME_NONNULL_BEGIN

@interface CSInput : NSObject

@property (nonatomic, readonly, assign) BOOL serverModeCursor;
@property (nonatomic, assign) BOOL disableInputs;

- (void)sendKey:(CSInputKey)type code:(int)scancode;
- (void)sendPause:(CSInputKey)type;
- (void)releaseKeys;

- (void)sendMouseMotion:(CSInputButton)button point:(CGPoint)point;
- (void)sendMouseMotion:(CSInputButton)button point:(CGPoint)point forMonitorID:(NSInteger)monitorID;
- (void)sendMouseScroll:(CSInputScroll)type button:(CSInputButton)button dy:(CGFloat)dy;
- (void)sendMouseButton:(CSInputButton)button pressed:(BOOL)pressed point:(CGPoint)point;
- (void)requestMouseMode:(BOOL)server;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSession:(SpiceSession *)session NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
