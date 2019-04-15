//
// Copyright © 2019 Halts. All rights reserved.
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

#import "UTMVirtualMachine.h"
#import "UTMConfiguration.h"

NSString *const kUTMBundleConfigFilename = @"config.plist";
NSString *const kUTMBundleExtension = @"utm";

@interface UTMVirtualMachine ()

- (NSURL *)packageURLForName:(NSString *)name;

@end

@implementation UTMVirtualMachine

+ (BOOL)URLisVirtualMachine:(NSURL *)url {
    return [url.pathExtension isEqualToString:kUTMBundleExtension];
}

+ (NSString *)virtualMachineName:(NSURL *)url {
    return [[[NSFileManager defaultManager] displayNameAtPath:url.path] stringByDeletingPathExtension];
}

+ (NSURL *)virtualMachinePath:(NSString *)name inParentURL:(NSURL *)parent {
    return [[parent URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (id)init {
    self = [super init];
    return self;
}

- (id)initWithURL:(NSURL *)url {
    self = [self init];
    if (self) {
        self.parentPath = url.URLByDeletingLastPathComponent;
        NSString *name = [UTMVirtualMachine virtualMachineName:url];
        NSError *err;
        NSData *data = [NSData dataWithContentsOfURL:[url URLByAppendingPathComponent:kUTMBundleConfigFilename]];
        id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:&err];
        if (err) {
            NSLog(@"Error reading %@: %@\n", url, err.localizedDescription);
            self = nil;
            return self;
        }
        if (![plist isKindOfClass:[NSMutableDictionary class]]) {
            NSLog(@"Wrong data format %@!\n", url);
            self = nil;
            return self;
        }
        self.configuration = [[UTMConfiguration alloc] initWithDictionary:plist name:name];
    }
    return self;
}

- (id)initDefaults:(NSString *)name withDestinationURL:(NSURL *)dstUrl {
    self = [self init];
    if (self) {
        self.parentPath = dstUrl;
        self.configuration = [[UTMConfiguration alloc] initDefaults:name];
    }
    return self;
}

- (NSURL *)packageURLForName:(NSString *)name {
    return [[self.parentPath URLByAppendingPathComponent:name] URLByAppendingPathExtension:kUTMBundleExtension];
}

- (void)saveUTMWithError:(NSError * _Nullable *)err {
    NSURL *url = [self packageURLForName:self.configuration.changeName];
    NSError *_err;
    if (!self.configuration.name) { // new package
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&_err];
        if (_err && err) {
            *err = _err;
            return;
        }
        self.configuration.name = self.configuration.changeName;
    } else if (![self.configuration.name isEqualToString:self.configuration.changeName]) { // rename if needed
        [[NSFileManager defaultManager] moveItemAtURL:[self packageURLForName:self.configuration.name] toURL:url error:&_err];
        if (_err && err) {
            *err = _err;
            return;
        }
        self.configuration.name = self.configuration.changeName;
    }
    // serialize config.plist
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self.configuration.dictRepresentation format:NSPropertyListXMLFormat_v1_0 options:0 error:&_err];
    if (_err && err) {
        *err = _err;
        return;
    }
    // write config.plist
    [data writeToURL:[url URLByAppendingPathComponent:kUTMBundleConfigFilename] options:NSDataWritingAtomic error:&_err];
    if (_err && err) {
        *err = _err;
    }
}

@end
