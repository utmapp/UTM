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

#import "UTMQemuVirtualMachine+Drives.h"
#import "UTMLogging.h"
#import "UTMViewState.h"
#import "UTMDrive.h"
#import "UTMQemu.h"
#import "UTMQemuManager+BlockDevices.h"
#import "UTM-Swift.h"

extern NSString *const kUTMErrorDomain;

@interface UTMQemuVirtualMachine ()

@property (nonatomic, readonly, nullable) UTMQemuManager *qemu;
@property (nonatomic, readonly, nullable) UTMQemu *system;

- (void)saveViewState;

@end

@implementation UTMQemuVirtualMachine (Drives)

- (BOOL)ejectDrive:(UTMDrive *)drive force:(BOOL)force error:(NSError * _Nullable __autoreleasing *)error {
    NSString *oldPath = [self.viewState pathForRemovableDrive:drive.name];
    [self.viewState removeBookmarkForRemovableDrive:drive.name];
    [self saveViewState];
    [self.system stopAccessingPath:oldPath];
    if (!self.qemu.isConnected) {
        return YES; // not running
    }
    return [self.qemu ejectDrive:[NSString stringWithFormat:@"drive%@", drive.name] force:force error:error];
}

- (BOOL)changeMediumForDrive:(UTMDrive *)drive url:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    [url startAccessingSecurityScopedResource];
    NSData *bookmark = [url bookmarkDataWithOptions:0
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    [url stopAccessingSecurityScopedResource];
    if (!bookmark) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed create bookmark.", "UTMVirtualMachine+Drives")}];
        }
        return NO;
    }
    if (!self.qemu.isConnected) {
        // On macOS, the `bookmark` will not work for the helper process.
        // This is caught and addressed in `restoreRemovableDrivesFromBookmarksWithError`.
        [self.viewState setBookmark:bookmark path:url.path forRemovableDrive:drive.name persistent:YES];
        [self saveViewState];
        return YES; // not ready yet
    } else {
        [self.viewState setBookmark:bookmark path:url.path forRemovableDrive:drive.name persistent:NO];
        NSString *oldPath = [self.viewState pathForRemovableDrive:drive.name];
        if (oldPath) {
            [self.system stopAccessingPath:oldPath];
        }
        return [self changeMediumForDriveInternal:drive bookmark:bookmark securityScoped:NO error:error];
    }
}

- (BOOL)changeMediumForDriveInternal:(UTMDrive *)drive bookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped error:(NSError * _Nullable __autoreleasing *)error {
    __block BOOL ret = NO;
    __block NSError *qemuError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [self.system accessDataWithBookmark:bookmark
                         securityScoped:securityScoped
                             completion:^(BOOL success, NSData *newBookmark, NSString *path) {
        if (success) {
            [self.viewState setBookmark:newBookmark path:path forRemovableDrive:drive.name persistent:YES];
            [self saveViewState];
            success = [self.qemu changeMediumForDrive:[NSString stringWithFormat:@"drive%@", drive.name] path:path error:&qemuError];
        } else {
            qemuError = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to access drive image path.", "UTMVirtualMachine+Drives")}];
        }
        ret = success;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    *error = qemuError;
    return ret;
}

- (BOOL)restoreRemovableDrivesFromBookmarksWithError:(NSError * _Nullable __autoreleasing *)error {
    NSArray<UTMDrive *> *drives = self.drives;
    BOOL ret = YES;
    BOOL viewStateChanged = NO;
    for (UTMDrive *drive in drives) {
        BOOL persistent = NO;
        NSData *bookmark = [self.viewState bookmarkForRemovableDrive:drive.name persistent:&persistent];
        if (bookmark) {
            UTMLog(@"found bookmark for %@", drive.name);
            if (drive.status == UTMDriveStatusFixed) {
                UTMLog(@"%@ is no longer removable, removing bookmark", drive.name);
                [self.viewState removeBookmarkForRemovableDrive:drive.name];
                viewStateChanged = YES;
                continue;
            }
            if (![self changeMediumForDriveInternal:drive bookmark:bookmark securityScoped:persistent error:error]) {
#if TARGET_OS_IPHONE
                UTMLog(@"failed to change %@ image", drive.name);
                // remove the bad bookmark
                [self.viewState removeBookmarkForRemovableDrive:drive.name];
                viewStateChanged = YES;
                ret = NO;
                break;
#else
                // On macOS, at this point it is possible that a disk image was chosen while the VM was powered down.
                // This results in an invalid bookmark so we need to re-run changeMediumForDrive.
                // If the viewState contains the path for the drive, we can use that to create a new bookmark.
                NSString* path = [self.viewState pathForRemovableDrive:drive.name];
                if (path) {
                    NSURL* url = [NSURL fileURLWithPath:path];
                    if (![self changeMediumForDrive:drive url:url error:error]) {
                        UTMLog(@"failed to change %@ image to %@", drive.name, path);
                        // remove the bad bookmark
                        [self.viewState removeBookmarkForRemovableDrive:drive.name];
                        viewStateChanged = YES;
                        ret = NO;
                        break;
                    }
                }
#endif
            }
        }
    }
    if (viewStateChanged) {
        [self saveViewState];
    }
    return ret;
}

@end
