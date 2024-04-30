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

#import <Foundation/Foundation.h>

@class CSDisplay;
@class CSInput;
@class CSPort;
@class CSUSBManager;

NS_ASSUME_NONNULL_BEGIN

@protocol UTMSpiceIODelegate<NSObject>

- (void)spiceDidCreateInput:(CSInput *)input NS_SWIFT_NAME(spiceDidCreateInput(_:));
- (void)spiceDidDestroyInput:(CSInput *)input NS_SWIFT_NAME(spiceDidDestroyInput(_:));
- (void)spiceDidCreateDisplay:(CSDisplay *)display NS_SWIFT_NAME(spiceDidCreateDisplay(_:));
- (void)spiceDidDestroyDisplay:(CSDisplay *)display NS_SWIFT_NAME(spiceDidDestroyDisplay(_:));
- (void)spiceDidUpdateDisplay:(CSDisplay *)display NS_SWIFT_NAME(spiceDidUpdateDisplay(_:));
- (void)spiceDidCreateSerial:(CSPort *)serial NS_SWIFT_NAME(spiceDidCreateSerial(_:));
- (void)spiceDidDestroySerial:(CSPort *)serial NS_SWIFT_NAME(spiceDidDestroySerial(_:));
#if defined(WITH_USB)
- (void)spiceDidChangeUsbManager:(nullable CSUSBManager *)usbManager NS_SWIFT_NAME(spiceDidChangeUsbManager(_:));
#endif

@optional
- (void)spiceDynamicResolutionSupportDidChange:(BOOL)supported;
- (void)spiceDidDisconnect;

@end

NS_ASSUME_NONNULL_END
