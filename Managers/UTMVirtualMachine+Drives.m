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

#import "UTMVirtualMachine+Drives.h"
#import "UTMLogging.h"
#import "UTMViewState.h"
#import "UTMDrive.h"
#import "UTMQemu.h"
#import "UTMQemuManager+BlockDevices.h"

extern NSString *const kUTMErrorDomain;

@interface UTMVirtualMachine ()

@property (nonatomic, readonly, nullable) UTMQemuManager *qemu;
@property (nonatomic, readonly, nullable) UTMQemu *system;

- (void)saveViewState;

@end

@implementation UTMVirtualMachine (Drives)

- (NSArray<UTMDrive *> *)drives {
    NSInteger count = self.configuration.countDrives;
    id drives = [NSMutableArray<UTMDrive *> arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        UTMDrive *drive = [UTMDrive new];
        drive.index = i;
        drive.imageType = [self.configuration driveImageTypeForIndex:i];
        drive.interface = [self.configuration driveInterfaceTypeForIndex:i];
        drive.name = [self.configuration driveNameForIndex:i];
        if ([self.configuration driveRemovableForIndex:i]) {
            // removable drive -> path stored only in viewState
            NSString *path = [self.viewState pathForRemovableDrive:drive.name];
            if (path.length > 0) {
                drive.status = UTMDriveStatusInserted;
                drive.path = path;
            } else {
                drive.status = UTMDriveStatusEjected;
                drive.path = nil;
            }
        } else {
            // fixed drive -> path stored in configuration
            drive.status = UTMDriveStatusFixed;
            drive.path = [self.configuration driveImagePathForIndex:i];
        }
        [drives addObject:drive];
    }
    return drives;
}

- (BOOL)ejectDrive:(UTMDrive *)drive force:(BOOL)force error:(NSError * _Nullable __autoreleasing *)error {
    NSString *oldPath = [self.viewState pathForRemovableDrive:drive.name];
    [self.viewState removeBookmarkForRemovableDrive:drive.name];
    [self saveViewState];
    [self.system stopAccessingPath:oldPath];
    if (!self.qemu.isConnected) {
        return YES; // not running
    }
    return [self.qemu ejectDrive:drive.name force:force error:error];
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
            success = [self.qemu changeMediumForDrive:drive.name path:path error:&qemuError];
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
    for (UTMDrive *drive in drives) {
        BOOL persistent = NO;
        NSData *bookmark = [self.viewState bookmarkForRemovableDrive:drive.name persistent:&persistent];
        if (bookmark) {
            UTMLog(@"found bookmark for %@", drive.name);
            if (drive.status == UTMDriveStatusFixed) {
                UTMLog(@"%@ is no longer removable, removing bookmark", drive.name);
                [self.viewState removeBookmarkForRemovableDrive:drive.name];
                continue;
            }
            if (![self changeMediumForDriveInternal:drive bookmark:bookmark securityScoped:persistent error:error]) {
#if TARGET_OS_IPHONE
                UTMLog(@"failed to change %@ image", drive.name);
                return NO;
#else
                // On macOS, at this point it is possible that a disk image was chosen while the VM was powered down.
                // This results in an invalid bookmark so we need to re-run changeMediumForDrive.
                // If the viewState contains the path for the drive, we can use that to create a new bookmark.
                NSString* path = [self.viewState pathForRemovableDrive:drive.name];
                if (path) {
                    NSURL* url = [NSURL fileURLWithPath:path];
                    if (![self changeMediumForDrive:drive url:url error:error]) {
                        UTMLog(@"failed to change %@ image to %@", drive.name, path);
                        return NO;
                    }
                } else {
                    continue;
                }
#endif
            }
        }
    }
    return YES;
}

@end
