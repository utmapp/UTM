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

#import "UTMQemuImg.h"
#import "UTMLogging.h"
#import <dlfcn.h>

@implementation UTMQemuImg {
    int (*_main)(int, const char *[]);
}

static void *start_qemu_img(void *args) {
    UTMQemuImg *self = (__bridge_transfer UTMQemuImg *)args;
    
    NSCAssert(self->_main != NULL, @"Started thread with invalid function.");
    NSCAssert(self.argv, @"Started thread with invalid argv.");
    
    int argc = (int)self.argv.count + 1;
    const char *argv[argc];
    argv[0] = "qemu-img";
    for (int i = 0; i < self.argv.count; i++) {
        argv[i+1] = [self.argv[i] UTF8String];
    }
    self.status = self->_main(argc, argv);
    dispatch_semaphore_signal(self.done);
    return NULL;
}

- (instancetype)initWithArgv:(NSArray<NSString *> *)argv {
    if (self = [super initWithArgv:argv]) {
        self.entry = start_qemu_img;
    }
    return self;
}

- (void)buildArgv {
    [self clearArgv];
    switch (self.op) {
        case kUTMQemuImgCreate: {
            [self pushArgv:@"create"];
            [self pushArgv:@"-f"];
            self.compressed ? [self pushArgv:@"qcow2"] : [self pushArgv:@"raw"];
            if (self.encrypted) {
                [self pushArgv:@"-o"];
                [self pushArgv:[NSString stringWithFormat:@"encrypt.format=aes,encrypt.key-secret=%@", self.password]];
            }
            [self pushArgv:self.outputPath.path];
            [self pushArgv:[NSString stringWithFormat:@"%ldM", self.sizeMiB]];
            break;
        }
        case kUTMQemuImgResize: {
            [self pushArgv:@"resize"];
            [self pushArgv:self.outputPath.path];
            [self pushArgv:[NSString stringWithFormat:@"%ldM", self.sizeMiB]];
            break;
        }
        case kUTMQemuImgConvert: {
            [self pushArgv:@"convert"];
            [self pushArgv:@"-O"];
            self.compressed ? [self pushArgv:@"qcow2"] : [self pushArgv:@"raw"];
            if (self.encrypted) {
                [self pushArgv:@"-o"];
                [self pushArgv:[NSString stringWithFormat:@"encrypt.format=aes,encrypt.key-secret=%@", self.password]];
            }
            [self pushArgv:self.inputPath.path];
            [self pushArgv:self.outputPath.path];
            break;
        }
        default: {
            UTMLog(@"Operation %lu not implemented!", self.op);
            break;
        }
    }
}

- (BOOL)didLoadDylib:(void *)handle {
    _main = dlsym(handle, "qemu_img_main");
    return (_main != NULL);
}

- (void)startWithCompletion:(void(^)(BOOL, NSString *))completion {
    // FIXME: get rid of this
    static BOOL once = NO;
    if (!self.hasRemoteProcess && once) {
        completion(NO, NSLocalizedString(@"Running qemu-img more than once is unimplemented. Restart the app to create another disk.", nil));
        return;
    }
    [self buildArgv];
    if (self.inputPath) {
        [self accessDataWithBookmark:[self.inputPath bookmarkDataWithOptions:0
                                              includingResourceValuesForKeys:nil
                                                               relativeToURL:nil
                                                                       error:nil]];
    }
    if (self.outputPath) {
        NSURL *outputDirectory = [self.outputPath URLByDeletingLastPathComponent];
        [self accessDataWithBookmark:[outputDirectory bookmarkDataWithOptions:0
                                               includingResourceValuesForKeys:nil
                                                                relativeToURL:nil
                                                                        error:nil]];
    }
    [self start:@"qemu-img" completion:completion];
    once = YES;
}

@end
