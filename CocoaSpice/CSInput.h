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

typedef NS_ENUM(NSUInteger, SendKeyType) {
    SEND_KEY_PRESS,
    SEND_KEY_RELEASE
};

typedef NS_ENUM(NSUInteger, SendButtonType) {
    SEND_BUTTON_NONE = 0,
    SEND_BUTTON_LEFT = 1,
    SEND_BUTTON_MIDDLE = 2,
    SEND_BUTTON_RIGHT = 4
};

typedef NS_ENUM(NSUInteger, SendScrollType) {
    SEND_SCROLL_UP,
    SEND_SCROLL_DOWN,
    SEND_SCROLL_SMOOTH
};

NS_ASSUME_NONNULL_BEGIN

@interface CSInput : NSObject <UTMRenderSource>

@property (nonatomic, readonly, nullable) SpiceSession *session;
@property (nonatomic, readonly, assign) NSInteger channelID;
@property (nonatomic, readonly, assign) NSInteger monitorID;
@property (nonatomic, readonly, assign) BOOL serverModeCursor;
@property (nonatomic, readonly, assign) BOOL hasCursor;
@property (nonatomic, assign) BOOL disableInputs;
@property (nonatomic, readonly) CGSize cursorSize;
@property (nonatomic, assign) CGSize displaySize;
@property (nonatomic, assign) BOOL inhibitCursor;

- (void)sendKey:(SendKeyType)type code:(int)scancode;
- (void)sendPause:(SendKeyType)type;
- (void)releaseKeys;

- (void)sendMouseMotion:(SendButtonType)button point:(CGPoint)point;
- (void)sendMouseScroll:(SendScrollType)type button:(SendButtonType)button dy:(CGFloat)dy;
- (void)sendMouseButton:(SendButtonType)button pressed:(BOOL)pressed point:(CGPoint)point;
- (void)requestMouseMode:(BOOL)server;
- (void)forceCursorPosition:(CGPoint)pos;

- (id)initWithSession:(nonnull SpiceSession *)session channelID:(NSInteger)channelID monitorID:(NSInteger)monitorID;

@end

NS_ASSUME_NONNULL_END
