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

#import <TargetConditionals.h>
#import "UTMVirtualMachine+Drives.h"
#import "UTMLogging.h"
#import "UTMViewState.h"
#import "UTMDrive.h"
#import "UTMQemu.h"
#import "UTMQemuManager+BlockDevices.h"

#if TARGET_OS_IPHONE
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = 0;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = 0;
#else
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = NSURLBookmarkCreationWithSecurityScope;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = NSURLBookmarkResolutionWithSecurityScope;
#endif

@interface UTMVirtualMachine ()

@property (nonatomic, readonly) UTMQemuManager *qemu;
@property (nonatomic, readonly) UTMQemu *system;
@property (nonatomic) UTMViewState *viewState;

@end

@implementation UTMVirtualMachine (Drives)

- (NSArray<UTMDrive *> *)drives {
    NSInteger count = self.configuration.countDrives;
    id drives = [NSMutableArray<UTMDrive *> arrayWithCapacity:count];
    id removableDrives = self.qemu.removableDrives;
    for (NSInteger i = 0; i < count; i++) {
        UTMDrive *drive = [UTMDrive new];
        drive.index = i;
        drive.imageType = [self.configuration driveImageTypeForIndex:i];
        drive.interface = [self.configuration driveInterfaceTypeForIndex:i];
        drive.name = [NSString stringWithFormat:@"drive%lu", i];
        NSString *path = removableDrives[drive.name];
        if (path) {
            if (path.length > 0) {
                drive.status = UTMDriveStatusInserted;
                drive.path = path;
            } else {
                drive.status = UTMDriveStatusEjected;
            }
        } else {
            drive.status = UTMDriveStatusFixed;
            drive.path = [self.configuration driveImagePathForIndex:i];
        }
        [drives addObject:drive];
    }
    return drives;
}

- (BOOL)ejectDrive:(UTMDrive *)drive force:(BOOL)force error:(NSError * _Nullable __autoreleasing *)error {
    return [self.qemu ejectDrive:drive.name force:force error:error];
}

- (BOOL)changeMediumForDrive:(UTMDrive *)drive url:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    if (![self saveBookmarkForDrive:drive url:url error:error]) {
        return NO;
    }
    if (!self.qemu.isConnected) {
        return YES; // not ready yet
    }
    
    NSData *bookmark = [url bookmarkDataWithOptions:0
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        return NO;
    }
    [self.system accessDataWithBookmark:bookmark];
    if (![self.qemu changeMediumForDrive:drive.name path:url.path error:error]) {
        return NO;
    }
    return [self saveBookmarkForDrive:drive url:url error:error];
}

- (BOOL)saveBookmarkForDrive:(UTMDrive *)drive url:(nullable NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSData *bookmark = [url bookmarkDataWithOptions:kBookmarkCreationOptions
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (bookmark) {
        [self.viewState setBookmark:bookmark forRemovableDrive:drive.name];
    } else {
        [self.viewState removeBookmarkForRemovableDrive:drive.name];
    }
    return (bookmark != nil);
}

- (void)restoreRemovableDrivesFromBookmarks {
    NSArray<UTMDrive *> *drives = self.drives;
    for (UTMDrive *drive in drives) {
        NSData *bookmark = [self.viewState bookmarkForRemovableDrive:drive.name];
        if (bookmark) {
            UTMLog(@"found bookmark for %@", drive.name);
            if (drive.status == UTMDriveStatusFixed) {
                UTMLog(@"%@ is no longer removable, removing bookmark", drive.name);
                [self saveBookmarkForDrive:drive url:nil error:nil];
                continue;
            }
            BOOL stale;
            NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                                   options:kBookmarkResolutionOptions
                                             relativeToURL:nil
                                       bookmarkDataIsStale:&stale
                                                     error:nil];
            if (!url) {
                UTMLog(@"failed to resolve bookmark for %@", drive.name);
                continue;
            }
            if (stale) {
                UTMLog(@"bookmark is stale, attempting to re-create");
                if (![self saveBookmarkForDrive:drive url:url error:nil]) {
                    UTMLog(@"bookmark re-creation failed");
                }
            }
            if (![self changeMediumForDrive:drive url:url error:nil]) {
                UTMLog(@"failed to change %@ image to %@", drive.name, url);
            }
        }
    }
}

@end
