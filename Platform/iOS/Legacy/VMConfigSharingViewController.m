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
#import "UIViewController+Extensions.h"
#import "VMConfigSharingViewController.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMLogging.h"
#import "VMConfigSwitch.h"
#import "VMConfigDirectoryPickerViewController.h"

@interface VMConfigSharingViewController ()

@property (nonatomic) NSURL *shareDirectory;

@end

@implementation VMConfigSharingViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showShareDirectoryOptions:self.shareDirectoryEnabledSwitch.on animated:NO];
    if (self.configuration.shareDirectoryEnabled) {
        [self refreshBookmark];
    }
}

- (void)showShareDirectoryOptions:(BOOL)visible animated:(BOOL)animated {
    [self cells:self.directorySharingCells setHidden:!visible];
    if (self.configuration.shareDirectoryName.length == 0) {
        self.selectDirectoryCell.detailTextLabel.text = NSLocalizedString(@"Browse...", @"VMConfigSharingViewController");
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
        UTMLog(@"bookmark invalid: %@", err);
        [self showAlert:NSLocalizedString(@"Shared path is no longer valid. Please re-choose.", @"VMConfigSharingViewController") actions:nil completion:nil];
        self.configuration.shareDirectoryBookmark = [NSData data];
        self.configuration.shareDirectoryName = @"";
    } else if (stale) {
        UTMLog(@"bookmark stale");
        if ([bookmark startAccessingSecurityScopedResource]) {
            data = [bookmark bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                      includingResourceValuesForKeys:nil
                                       relativeToURL:nil
                                               error:&err];
            [bookmark stopAccessingSecurityScopedResource];
            if (!data) {
                UTMLog(@"cannot recreate bookmark: %@", err);
                [self showAlert:NSLocalizedString(@"Shared path has moved. Please re-choose.", @"VMConfigSharingViewController") actions:nil completion:nil];
                self.configuration.shareDirectoryBookmark = [NSData data];
                self.configuration.shareDirectoryName = @"";
            } else {
                self.configuration.shareDirectoryBookmark = data;
            }
        }
    }
    self.shareDirectory = bookmark;
}

- (void)selectURL:(NSURL *)url {
    NSError *err;
    NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&err];
    if (!bookmark) {
        [self showAlert:err.localizedDescription actions:nil completion:nil];
    } else {
        UTMLog(@"Saving bookmark for %@", url);
        self.configuration.shareDirectoryBookmark = bookmark;
        self.configuration.shareDirectoryName = url.lastPathComponent;
    }
    self.shareDirectory = url;
}


- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSAssert(urls.count == 1, @"Invalid picker result");
    [self selectURL:urls[0]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    
}

#pragma mark - Directory picker (sandboxed)

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"selectDirectorySegue"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMConfigDirectoryPickerViewController class]], @"Invalid segue destination");
        VMConfigDirectoryPickerViewController *destination = (VMConfigDirectoryPickerViewController *)segue.destinationViewController;
        destination.selectedDirectory = self.shareDirectory;
    }
}

- (IBAction)unwindToShareViewFromDirectoryPicker:(UIStoryboardSegue*)sender {
    NSAssert([sender.sourceViewController isKindOfClass:[VMConfigDirectoryPickerViewController class]], @"Invalid segue destination");
    VMConfigDirectoryPickerViewController *source = (VMConfigDirectoryPickerViewController *)sender.sourceViewController;
    [self selectURL:source.selectedDirectory];
}

@end
