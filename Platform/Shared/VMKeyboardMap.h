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

typedef void (^KeyPressCallback)(NSInteger scanCode);

@interface VMKeyboardMap : NSObject

/// Emulate a sequence of key presses from a sequence of text
/// 
/// The processing will happen in a separate dispatch queue in order to handle delay between key strokes.
/// - Parameters:
///   - text: Text containing keypresses
///   - keyUp: Called for each key up
///   - keyDown: Called for each key down
///   - completion: Completion handler after all text is processed
- (void)mapText:(NSString *)text toKeyUp:(KeyPressCallback)keyUp keyDown:(KeyPressCallback)keyDown completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
