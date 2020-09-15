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
        } else if ([self.configuration driveRemovableForIndex:i]) { // qemu not started yet
            drive.status = UTMDriveStatusEjected;
        } else {
            drive.status = UTMDriveStatusFixed;
            drive.path = [self.configuration driveImagePathForIndex:i];
        }
        [drives addObject:drive];
    }
    return drives;
}

- (BOOL)ejectDrive:(UTMDrive *)drive force:(BOOL)force error:(NSError * _Nullable __autoreleasing *)error {
    [self.viewState removeBookmarkForRemovableDrive:drive.name];
    if (!self.qemu.isConnected) {
        return YES; // not ready yet
    }
    return [self.qemu ejectDrive:drive.name force:force error:error];
}

- (BOOL)changeMediumForDrive:(UTMDrive *)drive url:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSData *bookmark = [url bookmarkDataWithOptions:0
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed create bookmark.", "UTMVirtualMachine+Drives")}];
        }
        return NO;
    }
    if (![self checkSandboxAccess:url error:error]) {
        return NO;
    }
    [self.viewState setBookmark:bookmark path:url.path forRemovableDrive:drive.name persistent:NO];
    if (!self.qemu.isConnected) {
        return YES; // not ready yet
    } else {
        return [self changeMediumForDriveInternal:drive bookmark:bookmark persistent:NO error:error];
    }
}

- (BOOL)changeMediumForDriveInternal:(UTMDrive *)drive bookmark:(NSData *)bookmark persistent:(BOOL)persistent error:(NSError * _Nullable __autoreleasing *)error {
    __block BOOL ret = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [self.system accessDataWithBookmark:bookmark
                         securityScoped:persistent
                             completion:^(BOOL success, NSData *newBookmark, NSString *path) {
        if (success) {
            [self.viewState setBookmark:newBookmark path:path forRemovableDrive:drive.name persistent:YES];
            [self.qemu changeMediumForDrive:drive.name path:path error:error];
        } else {
            if (error) {
                *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to access drive image path.", "UTMVirtualMachine+Drives")}];
            }
        }
        ret = success;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return ret;
}

- (void)restoreRemovableDrivesFromBookmarks {
    NSArray<UTMDrive *> *drives = self.drives;
    for (UTMDrive *drive in drives) {
        BOOL persistent = NO;
        NSData *bookmark = [self.viewState bookmarkForRemovableDrive:drive.name persistent:&persistent];
        if (bookmark) {
            NSString *path = nil;
            UTMLog(@"found bookmark for %@", drive.name);
            if (drive.status == UTMDriveStatusFixed) {
                UTMLog(@"%@ is no longer removable, removing bookmark", drive.name);
                [self.viewState removeBookmarkForRemovableDrive:drive.name];
                continue;
            }
            if (![self changeMediumForDriveInternal:drive bookmark:bookmark persistent:persistent error:nil]) {
                UTMLog(@"failed to change %@ image to %@", drive.name, path);
            }
        }
    }
}

- (BOOL)checkSandboxAccess:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:url.path]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"This version of UTM does not allow file access outside of UTM's Documents directory.", "UTMVirtualMachine+Drives")}];
        }
        return NO;
    }
    return YES;
}

@end
