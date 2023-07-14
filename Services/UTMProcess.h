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

@class UTMProcess;

NS_ASSUME_NONNULL_BEGIN

typedef int (*UTMProcessThreadEntry)(UTMProcess *self, int argc, const char * _Nonnull argv[_Nonnull], const char * _Nonnull envp[_Nonnull]);

@interface UTMProcess : NSObject

@property (nonatomic, readonly) BOOL hasRemoteProcess;
@property (nonatomic, readonly) NSURL *libraryURL;
@property (nonatomic) NSArray<NSString *> *argv;
@property (nonatomic, readonly) NSString *arguments;
@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *environment;
@property (nonatomic) NSInteger status;
@property (nonatomic) NSInteger fatal;
@property (nonatomic) UTMProcessThreadEntry entry;
@property (nonatomic, nullable) NSPipe *standardOutput;
@property (nonatomic, nullable) NSPipe *standardError;
@property (nonatomic, nullable) NSURL *currentDirectoryUrl;

- (instancetype)init;
- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments NS_DESIGNATED_INITIALIZER;
- (void)pushArgv:(nullable NSString *)arg;
- (void)clearArgv;
- (void)startProcess:(nonnull NSString *)name completion:(nonnull void (^)(NSError * _Nullable))completion;
- (void)stopProcess;
- (void)accessDataWithBookmark:(NSData *)bookmark;
- (void)accessDataWithBookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion;
- (void)stopAccessingPath:(nullable NSString *)path;
- (void)processHasExited:(NSInteger)exitCode message:(nullable NSString *)message;
- (BOOL)didLoadDylib:(void *)handle;

@end

NS_ASSUME_NONNULL_END
