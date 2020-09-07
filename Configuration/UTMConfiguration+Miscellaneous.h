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

#import "UTMConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration (Miscellaneous)

@property (nonatomic, assign) BOOL inputLegacy;
@property (nonatomic, assign) BOOL inputScrollInvert;
@property (nonatomic, assign) BOOL soundEnabled;
@property (nonatomic, nullable, copy) NSString *soundCard;
@property (nonatomic, assign) BOOL debugLogEnabled;
@property (nonatomic, assign) BOOL ignoreAllConfiguration;
@property (nonatomic, nullable, copy) NSString *icon;
@property (nonatomic, assign) BOOL iconCustom;
@property (nonatomic, nullable, copy) NSString *notes;

- (void)migrateMiscellaneousConfigurationIfNecessary;

@end

NS_ASSUME_NONNULL_END
