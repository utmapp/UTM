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

@property (nonatomic, nonnull) Class DiskImages2;
@property (nonatomic) Class DICreateASIFParams;
@property (nonatomic) Class DIResizeParams;
@property (nonatomic) Class DIImageInfoParams;
@property (nonatomic) SEL DICreateASIFParamsInitSelector;
@property (nonatomic) SEL DIResizeParamsInitSelector;
@property (nonatomic) SEL DIImageInfoParamsInitSelector;
@property (nonatomic) SEL DiskImages2CreateSelector;
@property (nonatomic) SEL DiskImages2ResizeSelector;
@property (nonatomic) SEL DiskImages2RetrieveInfoSelector;
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
    }
    self.DiskImages2 = [bundle classNamed:@"DiskImages2"];
    if (!self.DiskImages2) {
        UTMLog(@"Failed to load DiskImages2");
        return NO;
    }
    self.DIResizeParams = [bundle classNamed:@"DIResizeParams"];
    if (!self.DICreateASIFParams) {
        UTMLog(@"Failed to load DIResizeParams");
    }
    self.DIImageInfoParams = [bundle classNamed:@"DIImageInfoParams"];
    if (!self.DICreateASIFParams) {
        UTMLog(@"Failed to load DIImageInfoParams");
    }

    self.DICreateASIFParamsInitSelector = NSSelectorFromString(@"initWithURL:numBlocks:error:");
    self.DiskImages2CreateSelector = NSSelectorFromString(@"createBlankWithParams:error:");
    self.DIResizeParamsInitSelector = NSSelectorFromString(@"initWithURL:size:error:");
    self.DiskImages2ResizeSelector = NSSelectorFromString(@"resizeWithParams:error:");
    self.DIImageInfoParamsInitSelector = NSSelectorFromString(@"initWithURL:error:");
    self.DiskImages2RetrieveInfoSelector = NSSelectorFromString(@"retrieveInfoWithParams:error:");

    if (![self.DICreateASIFParams instancesRespondToSelector:self.DICreateASIFParamsInitSelector]) {
        UTMLog(@"DICreateASIFParams does not respond to 'initWithURL:numBlocks:error:'");
        self.DICreateASIFParamsInitSelector = nil;
    }
    if (![self.DiskImages2 respondsToSelector:self.DiskImages2CreateSelector]) {
        UTMLog(@"DiskImages2 does not respond to '+createBlankWithParams:error:'");
        self.DiskImages2CreateSelector = nil;
    }
    if (![self.DIResizeParams instancesRespondToSelector:self.DIResizeParamsInitSelector]) {
        UTMLog(@"DIResizeParams does not respond to 'initWithURL:size:error:'");
        self.DIResizeParamsInitSelector = nil;
    }
    if (![self.DiskImages2 respondsToSelector:self.DiskImages2ResizeSelector]) {
        UTMLog(@"DiskImages2 does not respond to '+resizeWithParams:error:'");
        self.DiskImages2ResizeSelector = nil;
    }
    if (![self.DIImageInfoParams instancesRespondToSelector:self.DIImageInfoParamsInitSelector]) {
        UTMLog(@"DIImageInfoParams does not respond to 'initWithURL:error:'");
        self.DIImageInfoParamsInitSelector = nil;
    }
    if (![self.DiskImages2 respondsToSelector:self.DiskImages2RetrieveInfoSelector]) {
        UTMLog(@"DiskImages2 does not respond to '+retrieveInfoWithParams:error:'");
        self.DiskImages2RetrieveInfoSelector = nil;
    }
    return YES;
}

- (NSError *)notimplementedError {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Not implemented.", "UTMASIFImage")}];
}

- (id)callInitSelector:(SEL)selector class:(Class)class URL:(NSURL *)url hasArg1:(BOOL)hasArg1 arg1:(NSInteger)arg1 error:(NSError * _Nullable *)error {
    id params = [class alloc];
    if (!params || !class || !selector) {
        *error = self.notimplementedError;
        return nil;
    }

    NSMethodSignature *sig = [params methodSignatureForSelector:selector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:selector];
    [inv setTarget:params];

    // Set arguments: indexes 0 and 1 are self and _cmd
    [inv setArgument:&url atIndex:2];
    if (hasArg1) {
        [inv setArgument:&arg1 atIndex:3];
        [inv setArgument:error atIndex:4];
    } else {
        [inv setArgument:error atIndex:3];
    }

    [inv invoke];

    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

- (BOOL)callDiskImage2Selector:(SEL)selector params:(id)params error:(NSError * _Nullable *)error {
    if (!selector) {
        *error = self.notimplementedError;
        return nil;
    }

    NSMethodSignature *sig = [self.DiskImages2 methodSignatureForSelector:selector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:selector];
    [inv setTarget:self.DiskImages2];

    [inv setArgument:&params atIndex:2];
    [inv setArgument:error atIndex:3];

    [inv invoke];

    BOOL success;
    [inv getReturnValue:&success];
    return success;
}

- (BOOL)createBlankWithURL:(NSURL *)url numBlocks:(NSInteger)numBlocks error:(NSError * _Nullable *)error API_AVAILABLE(macosx(13), ios(16), tvos(16), watchos(9)) {
    id params = [self callInitSelector:self.DICreateASIFParamsInitSelector class:self.DICreateASIFParams URL:url hasArg1:YES arg1:numBlocks error:error];
    if (!params) {
        return NO;
    }
    return [self callDiskImage2Selector:self.DiskImages2CreateSelector params:params error:error];
}

- (BOOL)resizeWithURL:(NSURL *)url size:(NSInteger)size error:(NSError * _Nullable *)error API_AVAILABLE(macosx(14), ios(17), tvos(17), watchos(10)) {
    id params = [self callInitSelector:self.DIResizeParamsInitSelector class:self.DIResizeParams URL:url hasArg1:YES arg1:size error:error];
    if (!params) {
        return NO;
    }
    return [self callDiskImage2Selector:self.DiskImages2ResizeSelector params:params error:error];
}

- (nullable NSDictionary<NSString *, NSObject *> *)retrieveInfo:(NSURL *)url error:(NSError * _Nullable *)error API_AVAILABLE(macosx(14), ios(17), tvos(17), watchos(10)) {
    id params = [self callInitSelector:self.DIImageInfoParamsInitSelector class:self.DIImageInfoParams URL:url hasArg1:NO arg1:0 error:error];
    if (!params) {
        return nil;
    }
    if (![self callDiskImage2Selector:self.DiskImages2RetrieveInfoSelector params:params error:error]) {
        return nil;
    }
    return [params valueForKey:@"imageInfo"];
}

@end
