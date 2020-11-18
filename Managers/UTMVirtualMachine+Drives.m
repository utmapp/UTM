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
        if ([self.configuration driveRemovableForIndex:i]) {
            // removable drive
            if (path.length > 0) {
                drive.status = UTMDriveStatusInserted;
                drive.path = path;
            } else {
                path = [self.configuration driveImagePathForIndex:i];
                if (path.length > 0) {
                    drive.path = path;
                    drive.status = UTMDriveStatusInserted;
                } else {
                    drive.path = @"";
                    drive.status = UTMDriveStatusEjected;
                }
            }
        } else {
            // fixed drive
            drive.status = UTMDriveStatusFixed;
            drive.path = [self.configuration driveImagePathForIndex:i];
        }
        [drives addObject:drive];
    }
    return drives;
}

- (BOOL)ejectDrive:(UTMDrive *)drive force:(BOOL)force error:(NSError * _Nullable __autoreleasing *)error {
    [self.viewState removeBookmarkForRemovableDrive:drive.name];
    [self.configuration setImagePath:@"" forIndex:drive.index];
    bool saved = [self saveUTMWithError:error];
    if (!saved) {
        return NO;
    }
    if (self.qemu.isConnected) {
        return [self.qemu ejectDrive:drive.name force:force error:error];
    } else {
        // not running
        drive.status = UTMDriveStatusEjected;
        return YES;
    }
}

- (BOOL)changeMediumForDrive:(UTMDrive *)drive url:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    // assume security scoped, it doesn't hurt even if the file is in the documents directory!
    BOOL securityScoped = YES;
    if (securityScoped && ![url startAccessingSecurityScopedResource]) {
        return NO;
    }
    NSUInteger createOptions = securityScoped ? ( 1 << 11 ) : 0;
    NSData *bookmark = [url bookmarkDataWithOptions:createOptions
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to create bookmark.", "UTMVirtualMachine+Drives")}];
        }
        return NO;
    }
    // save configuration
    [self.configuration setImagePath:url.path forIndex:drive.index];
    bool saved = [self saveUTMWithError:error];
    if (!saved) {
        return NO;
    }
    if (!self.qemu.isConnected) {
        [self.viewState setBookmark:bookmark path:url.path forRemovableDrive:drive.name];
        return YES; // VM not running
    } else {
        bool ret = [self changeMediumForDriveInternal:drive bookmark:bookmark securityScoped:securityScoped error:error];
        if (ret) {
            [self.viewState setBookmark:bookmark path:url.path forRemovableDrive:drive.name];
        }
        return ret;
    }
}

- (BOOL)changeMediumForDriveInternal:(UTMDrive *)drive bookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped error:(NSError * _Nullable __autoreleasing *)error {
    __block BOOL ret = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [self.system accessDataWithBookmark:bookmark
                         securityScoped:securityScoped
                             completion:^(BOOL success, NSData *newBookmark, NSString *path) {
        if (success) {
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
        NSData *bookmark = [self.viewState bookmarkForRemovableDrive:drive.name];
        if (bookmark) {
            NSString *path = nil;
            UTMLog(@"found bookmark for %@", drive.name);
            if (drive.status == UTMDriveStatusFixed) {
                UTMLog(@"%@ is no longer removable, removing bookmark", drive.name);
                [self.viewState removeBookmarkForRemovableDrive:drive.name];
                continue;
            }
            if (![self changeMediumForDriveInternal:drive bookmark:bookmark securityScoped:YES error:nil]) {
                UTMLog(@"failed to change %@ image to %@", drive.name, path);
            }
        }
    }
}

@end
