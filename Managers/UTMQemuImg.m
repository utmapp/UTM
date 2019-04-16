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

#import "UTMQemuImg.h"
#import <dlfcn.h>
#import <pthread.h>

@implementation UTMQemuImg

- (void)buildArgv {
    [self pushArgv:@"qemu-img"];
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
            [self pushArgv:[NSString stringWithFormat:@"%luM", self.sizeMiB]];
            break;
        }
        case kUTMQemuImgResize: {
            [self pushArgv:@"resize"];
            [self pushArgv:self.outputPath.path];
            [self pushArgv:[NSString stringWithFormat:@"%luM", self.sizeMiB]];
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
            NSLog(@"Operation %lu not implemented!", self.op);
            break;
        }
    }
}

- (void)startWithCompletion:(void(^)(BOOL, NSString *))completion {
    // FIXME: get rid of this
    static BOOL once = NO;
    if (once) {
        completion(NO, NSLocalizedString(@"Running qemu-img more than once is unimplemented. Restart the app to create another disk.", nil));
        return;
    }
    [self buildArgv];
    [self startDylib:@"libqemu-img.dylib" main:@"qemu_img_main" completion:completion];
    once = YES;
}

@end
