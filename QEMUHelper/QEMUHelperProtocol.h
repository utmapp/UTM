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

typedef void (^tokenCallback_t)(BOOL);

NS_ASSUME_NONNULL_BEGIN

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol QEMUHelperProtocol

@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *environment;
@property (nonatomic, nullable) NSString *currentDirectoryPath;

- (void)accessDataWithBookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion;
- (void)stopAccessingPath:(nullable NSString *)path;
- (void)startQemu:(NSString *)binName standardOutput:(NSFileHandle *)standardOutput standardError:(NSFileHandle *)standardError libraryBookmark:(NSData *)libBookmark argv:(NSArray<NSString *> *)argv completion:(void(^)(BOOL,NSString *))completion;
- (void)terminate;

/// Helper holds on to the token to keep this XPC service active
///
/// If this is not called after `startQemu`, XNU may terminate this helper as idle.
/// - Parameter token: Token to hold, result may be discarded.
- (void)assertActiveWithToken:(tokenCallback_t)token;

@end

NS_ASSUME_NONNULL_END
