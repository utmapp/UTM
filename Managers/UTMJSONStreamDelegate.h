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

NS_ASSUME_NONNULL_BEGIN

@class UTMJSONStream;

@protocol UTMJSONStreamDelegate <NSObject>

- (void)jsonStream:(UTMJSONStream *)stream connected:(BOOL)readStream;
- (void)jsonStream:(UTMJSONStream *)stream receivedDictionary:(NSDictionary *)dict;
- (void)jsonStream:(UTMJSONStream *)stream seenError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
