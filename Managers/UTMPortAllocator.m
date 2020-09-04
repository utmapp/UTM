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

#import "UTMPortAllocator.h"
#import "UTMLogging.h"
#include <arpa/inet.h>
#include <sys/socket.h>

static UTMPortAllocator *gPortAllocatorInstance;
static const NSInteger kStartingPort = 4000;

static NSInteger firstZeroBit(UInt64 x) {
    UInt64 r = x;
    NSInteger t = 0;
    while ((r & 1) != 0) {
        r = r >> 1;
        t = t + 1;
    }
    return (t < 64) ? t : -1;
}

BOOL isPortAvailable(NSInteger port) {
    struct sockaddr_in addr = {0};
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        UTMLog(@"failed to create socket");
        return YES; // let's fail when server is created
    }
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(port);
    if (connect(sockfd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(sockfd);
        return YES;
    } else {
        close(sockfd);
        return NO; // in use
    }
}

@interface UTMPortAllocator ()

@property (nonatomic) NSMutableArray<NSNumber *> *usedBitmap;

@end

@implementation UTMPortAllocator

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        gPortAllocatorInstance = [[UTMPortAllocator alloc] init];
    }
}

+ (UTMPortAllocator *)sharedInstance {
    return gPortAllocatorInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.usedBitmap = [NSMutableArray new];
    }
    return self;
}

- (NSInteger)allocatePortInternal {
    @synchronized (self.usedBitmap) {
        for (NSInteger x = 0; x < self.usedBitmap.count; x++) {
            UInt64 bitmap = [self.usedBitmap[x] unsignedLongLongValue];
            NSInteger y = firstZeroBit(bitmap);
            if (y >= 0) {
                self.usedBitmap[x] = @(bitmap | (1 << y));
                return kStartingPort + 64*x + y;
            }
        }
        NSInteger x = self.usedBitmap.count;
        [self.usedBitmap addObject:@(1)];
        return kStartingPort + 64*x;
    }
}

- (NSInteger)allocatePort {
    NSInteger port;
    BOOL isAvailable;
    do {
        port = [self allocatePortInternal];
        isAvailable = isPortAvailable(port);
        if (!isAvailable) {
            UTMLog(@"port %lu is in use, trying next one", port);
        }
    } while (!isAvailable);
    return port;
}

- (void)freePort:(NSInteger)port {
    NSInteger bit = port - kStartingPort;
    if (bit < 0) {
        UTMLog(@"Invalid port %lu", port);
        return;
    }
    NSInteger x = bit / 64;
    NSInteger y = bit % 64;
    @synchronized (self.usedBitmap) {
        if (x >= self.usedBitmap.count) {
            UTMLog(@"Port %lu exceeds bitmap length", port);
            return;
        }
        UInt64 bitmap = [self.usedBitmap[x] unsignedLongLongValue];
        if ((bitmap & (1 << y)) == 0) {
            UTMLog(@"Trying to free port %lu twice!", port);
            return;
        }
        self.usedBitmap[x] = @(bitmap & ~(1 << y));
    }
}

@end
