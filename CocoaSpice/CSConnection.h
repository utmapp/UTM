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
#import "CSConnectionDelegate.h"

@class CSDisplayMetal;

NS_ASSUME_NONNULL_BEGIN

@interface CSConnection : NSObject

@property (nonatomic, readonly) NSArray<NSArray<CSDisplayMetal *> *> *monitors;
@property (nonatomic, readonly) NSArray<NSArray<CSInput *> *> *inputs;
@property (nonatomic, readonly) CSSession *session;
@property (nonatomic, weak, nullable) id<CSConnectionDelegate> delegate;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *port;
@property (nonatomic, assign) BOOL audioEnabled;
@property (nonatomic, assign, nullable) void *glibMainContext;

- (id)initWithHost:(NSString *)host port:(NSString *)port;
- (BOOL)connect;
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
