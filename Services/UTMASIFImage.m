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

#import <Availability.h>
#import "UTMASIFImage.h"
#import "UTMLogging.h"

extern NSString *const kUTMErrorDomain;

@interface UTMASIFImage ()

@property (nonatomic, nonnull) Class DICreateASIFParams;
@property (nonatomic, nonnull) Class DiskImages2;
@property (nonatomic, nonnull) SEL DICreateASIFParamsInitSelector;
@property (nonatomic, nonnull) SEL DiskImages2CreateSelector;
@property (nonatomic, nonnull, readonly) NSError *notimplementedError;

@end

@implementation UTMASIFImage

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UTMASIFImage *instance = [[self alloc] init];
        if (@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)) {
            if ([instance load]) {
                sharedInstance = instance;
            }
        } else {
            UTMLog(@"Not loading DiskImages2.framework due to unsupported operating system version.");
        }
    });

    return sharedInstance;
}

- (BOOL)load API_AVAILABLE(macosx(13), ios(16), tvos(16), watchos(9)) {
    NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/DiskImages2.framework"];
    if (!bundle) {
        UTMLog(@"Failed to create bundle DiskImages2.framework");
        return NO;
    }
    if (![bundle load]) {
        UTMLog(@"Failed to load DiskImages2.framework");
        return NO;
    }

    self.DICreateASIFParams = [bundle classNamed:@"DICreateASIFParams"];
    if (!self.DICreateASIFParams) {
        UTMLog(@"Failed to load DICreateASIFParams");
        return NO;
    }
    self.DiskImages2 = [bundle classNamed:@"DiskImages2"];
    if (!self.DiskImages2) {
        UTMLog(@"Failed to load DiskImages2");
        return NO;
    }

    self.DICreateASIFParamsInitSelector = NSSelectorFromString(@"initWithURL:numBlocks:error:");
    self.DiskImages2CreateSelector = NSSelectorFromString(@"createBlankWithParams:error:");

    if (![self.DICreateASIFParams instancesRespondToSelector:self.DICreateASIFParamsInitSelector]) {
        UTMLog(@"DICreateASIFParams does not respond to 'initWithURL:numBlocks:error:'");
        return NO;
    }
    if (![self.DiskImages2 respondsToSelector:self.DiskImages2CreateSelector]) {
        UTMLog(@"DiskImages2 does not respond to '+createBlankWithParams:error:'");
        return NO;
    }
    return YES;
}

- (NSError *)notimplementedError {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Not implemented.", "UTMASIFImage")}];
}

- (id)callDICreateASIFParamsInitWithURL:(NSURL *)url numBlocks:(NSInteger)numBlocks error:(NSError * _Nullable *)error {
    id params = [self.DICreateASIFParams alloc];
    if (!params) {
        *error = self.notimplementedError;
        return nil;
    }

    NSMethodSignature *sig = [params methodSignatureForSelector:self.DICreateASIFParamsInitSelector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:self.DICreateASIFParamsInitSelector];
    [inv setTarget:params];

    // Set arguments: indexes 0 and 1 are self and _cmd
    [inv setArgument:&url atIndex:2];
    [inv setArgument:&numBlocks atIndex:3];
    [inv setArgument:error atIndex:4];

    [inv invoke];

    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

- (BOOL)callDiskImage2CreateBlankWithParams:(id)params error:(NSError * _Nullable *)error {
    NSMethodSignature *sig = [self.DiskImages2 methodSignatureForSelector:self.DiskImages2CreateSelector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:self.DiskImages2CreateSelector];
    [inv setTarget:self.DiskImages2];

    [inv setArgument:&params atIndex:2];
    [inv setArgument:error atIndex:3];

    [inv invoke];

    BOOL success;
    [inv getReturnValue:&success];
    return success;
}

- (BOOL)createBlankWithURL:(NSURL *)url numBlocks:(NSInteger)numBlocks error:(NSError * _Nullable *)error {
    id params = [self callDICreateASIFParamsInitWithURL:url numBlocks:numBlocks error:error];
    if (!params) {
        return NO;
    }
    return [self callDiskImage2CreateBlankWithParams:params error:error];
}

@end
