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

#import "CSSession+Sharing.h"
#import <spice-client.h>

static const NSString *const kDefaultShareReadme =
    @"You have not selected a shared directory. This is a temporary directory "
     "that can be deleted at any time. You can access these files on the host "
     "at ~/Documents/Public relative to UTM's sandbox (if enabled). To select a "
     "permanent shared directory, shut down the VM and select a shared "
     "directory from the VM details screen.";

@implementation CSSession (Sharing)

- (void)setSharedDirectory:(NSString *)path readOnly:(BOOL)readOnly {
    g_object_set(self.session, "shared-dir", [path cStringUsingEncoding:NSUTF8StringEncoding], NULL);
    g_object_set(self.session, "share-dir-ro", readOnly, NULL);
}

- (NSURL *)defaultPublicShare {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *publicShare = [documentsDir URLByAppendingPathComponent:@"Public" isDirectory:YES];
    BOOL isDir = NO;
    if (![fileManager fileExistsAtPath:publicShare.path isDirectory:&isDir] || !isDir) {
        [fileManager removeItemAtURL:publicShare error:nil]; // remove file if exists
        [fileManager createDirectoryAtURL:publicShare withIntermediateDirectories:NO attributes:nil error:nil];
    }
    return publicShare;
}

- (void)createDefaultShareReadme {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *readme = [self.defaultPublicShare URLByAppendingPathComponent:@"README.txt"];
    if (![fileManager fileExistsAtPath:readme.path]) {
        [kDefaultShareReadme writeToURL:readme atomically:YES encoding:NSASCIIStringEncoding error:nil];
    }
}

@end
