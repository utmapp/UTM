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

@implementation UTMQemuImg {
    int (*_qemu_img_main)(int, const char *[]);
    NSMutableArray<NSString *> *_argv;
}

void *start_qemu_img(void *args) {
    UTMQemuImg *self = (__bridge_transfer UTMQemuImg *)args;
    intptr_t status;
    
    NSCAssert(self->_qemu_img_main != NULL, @"Started thread with invalid pointer.");
    
    int argc = (int)self->_argv.count;
    const char *argv[argc];
    for (int i = 0; i < self->_argv.count; i++) {
        argv[i] = [self->_argv[i] UTF8String];
    }
    status = self->_qemu_img_main(argc, argv);
    return (void *)status;
}

- (void)buildArgv {
    _argv = [NSMutableArray<NSString *> array];
    [_argv addObject:@"qemu-img"];
    switch (self.op) {
        case kUTMQemuImgCreate: {
            [_argv addObject:@"create"];
            [_argv addObject:@"-f"];
            self.compressed ? [_argv addObject:@"qcow2"] : [_argv addObject:@"raw"];
            if (self.encrypted) {
                [_argv addObject:@"-o"];
                [_argv addObject:[NSString stringWithFormat:@"encrypt.format=aes,encrypt.key-secret=%@", self.password]];
            }
            [_argv addObject:self.outputPath.path];
            [_argv addObject:[NSString stringWithFormat:@"%luM", self.sizeMiB]];
            break;
        }
        case kUTMQemuImgResize: {
            [_argv addObject:@"resize"];
            [_argv addObject:self.outputPath.path];
            [_argv addObject:[NSString stringWithFormat:@"%luM", self.sizeMiB]];
            break;
        }
        case kUTMQemuImgConvert: {
            [_argv addObject:@"convert"];
            [_argv addObject:@"-O"];
            self.compressed ? [_argv addObject:@"qcow2"] : [_argv addObject:@"raw"];
            if (self.encrypted) {
                [_argv addObject:@"-o"];
                [_argv addObject:[NSString stringWithFormat:@"encrypt.format=aes,encrypt.key-secret=%@", self.password]];
            }
            [_argv addObject:self.inputPath.path];
            [_argv addObject:self.outputPath.path];
            break;
        }
        default: {
            NSLog(@"Operation %lu not implemented!", self.op);
            break;
        }
    }
}

- (void)startWithCompletion:(void(^)(BOOL, NSString *))completion {
    void *dlctx;
    pthread_t qemu_thread;
    
    // FIXME: get rid of this
    static BOOL once = NO;
    if (once) {
        completion(NO, NSLocalizedString(@"Running qemu-img more than once is unimplemented. Restart the app to create another disk.", nil));
        return;
    }
    
    dlctx = dlopen("libqemu-img.dylib", RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion(NO, err);
        return;
    }
    _qemu_img_main = dlsym(dlctx, "qemu_img_main");
    if (_qemu_img_main == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion(NO, err);
        return;
    }
    [self buildArgv];
    // TODO: fix issues with launching qemu-img twice
    pthread_create(&qemu_thread, NULL, &start_qemu_img, (__bridge_retained void *)self);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        void *status;
        if (pthread_join(qemu_thread, &status)) {
            dlclose(dlctx);
            completion(NO, NSLocalizedString(@"Internal error has occurred.", @"qemu pthread join fail"));
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                completion(NO, err);
            } else {
                once = YES;
                completion(YES, nil);
            }
        }
    });
}

@end
