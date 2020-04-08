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

#import <MobileCoreServices/MobileCoreServices.h>
#import "VMConfigSharingViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Sharing.h"
#import "VMConfigSwitch.h"

@interface VMConfigSharingViewController ()

@end

@implementation VMConfigSharingViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showShareDirectoryOptions:self.shareDirectoryEnabledSwitch.on animated:NO];
    if (self.configuration.shareDirectoryEnabled) {
        [self refreshBookmark];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell == self.selectDirectoryCell) {
        [self selectDirectory];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)showShareDirectoryOptions:(BOOL)visible animated:(BOOL)animated {
    [self cells:self.directorySharingCells setHidden:!visible];
    if (self.configuration.shareDirectoryName.length == 0) {
        self.shareDirectoryNameLabel.text = NSLocalizedString(@"Browse...", @"VMConfigSharingViewController");
    }
    [self reloadDataAnimated:animated];
}

- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender {
    if (sender == self.shareDirectoryEnabledSwitch) {
        [self showShareDirectoryOptions:sender.on animated:YES];
        if (!sender.on) {
            self.configuration.shareDirectoryName = @"";
            self.configuration.shareDirectoryBookmark = [NSData data];
        }
    }
    [super configSwitchChanged:sender];
}

#pragma mark - Shared Directory

- (void)selectDirectory {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ (__bridge NSString *)kUTTypeFolder ]
                                                               inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)refreshBookmark {
    BOOL stale;
    NSError *err;
    NSData *data = self.configuration.shareDirectoryBookmark;
    NSURL *bookmark = [NSURL URLByResolvingBookmarkData:data
                                                options:0
                                          relativeToURL:nil
                                    bookmarkDataIsStale:&stale
                                                  error:&err];
    if (!bookmark) {
        NSLog(@"bookmark invalid: %@", err);
        [self showAlert:NSLocalizedString(@"Shared path is no longer valid. Please re-choose.", @"VMConfigSharingViewController") completion:nil];
        self.configuration.shareDirectoryBookmark = [NSData data];
        self.configuration.shareDirectoryName = @"";
    } else if (stale) {
        NSLog(@"bookmark stale");
        if ([bookmark startAccessingSecurityScopedResource]) {
            data = [bookmark bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                      includingResourceValuesForKeys:nil
                                       relativeToURL:nil
                                               error:&err];
            [bookmark stopAccessingSecurityScopedResource];
            if (!data) {
                NSLog(@"cannot recreate bookmark: %@", err);
                [self showAlert:NSLocalizedString(@"Shared path has moved. Please re-choose.", @"VMConfigSharingViewController") completion:nil];
                self.configuration.shareDirectoryBookmark = [NSData data];
                self.configuration.shareDirectoryName = @"";
            } else {
                self.configuration.shareDirectoryBookmark = data;
            }
        }
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSAssert(urls.count == 1, @"Invalid picker result");
    NSURL *url = urls[0];
    NSError *err;
    NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&err];
    if (!bookmark) {
        [self showAlert:err.localizedDescription completion:nil];
    } else {
        NSLog(@"Saving bookmark for %@", url);
        self.configuration.shareDirectoryBookmark = bookmark;
        self.configuration.shareDirectoryName = url.lastPathComponent;
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    
}

@end
