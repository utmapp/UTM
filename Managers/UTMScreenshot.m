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

#import "TargetConditionals.h"
#import "UTMScreenshot.h"

@implementation UTMScreenshot

+ (UTMScreenshot *)none {
    static dispatch_once_t pred = 0;
    static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (instancetype)init {
    return [super init];
}

#if TARGET_OS_IPHONE
- (instancetype)initWithImage:(UIImage *)image {
    if (self = [self init]) {
        _image = image;
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (self = [self init]) {
        _image = [[UIImage alloc] initWithContentsOfFile:url.path];
        if (_image == nil) {
            self = nil;
        }
    }
    return self;
}

- (void)writeToURL:(NSURL *)url atomically:(BOOL)atomically {
    [UIImagePNGRepresentation(_image) writeToURL:url atomically:atomically];
}
#else
- (instancetype)initWithImage:(NSImage *)image {
    if (self = [self init]) {
        _image = image;
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (self = [self init]) {
        _image = [[NSImage alloc] initWithContentsOfURL:url];
        if (_image == nil) {
            self = nil;
        }
    }
    return self;
}

- (void)writeToURL:(NSURL *)url atomically:(BOOL)atomically {
    CGImageRef cgRef = [self.image CGImageForProposedRect:NULL
                                                  context:nil
                                                    hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[self.image size]];   // if you want the same resolution
    NSData *pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [pngData writeToURL:url atomically:atomically];
}
#endif

@end
