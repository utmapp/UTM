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

#import "VMListViewController.h"
#import "AppDelegate.h"
#import "VMListViewCell.h"
#import "UTMConfigurationDelegate.h"
#import "UTMConfiguration.h"
#import "UTMVirtualMachine.h"
#import "UIViewController+Extensions.h"
#import "VMDisplayMetalViewController.h"
#import "VMDisplayTerminalViewController.h"
#import "UTMScreenshot.h"
#import "UTMJailbreak.h"

@import SafariServices;

@interface VMListViewController ()

@property (nonatomic, readonly) NSURL *documentsPath;
@property (nonatomic, strong) UTMVirtualMachine *modifyingVM;
@property (nonatomic, strong) NSArray<UTMVirtualMachine *> *vmList;
@property (nonatomic, nullable, strong) UIAlertController *alert;
@property (nonatomic, strong) dispatch_semaphore_t viewVisibleSema;
@property (nonatomic, strong) dispatch_queue_t viewVisibleQueue;

@end

@implementation VMListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Do any additional setup after loading the view.
    [self.collectionView setDragInteractionEnabled:YES];
    
    // Set up context menu
    UIMenuItem *deleteItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", @"Delete context menu")
                                                        action:NSSelectorFromString(@"deleteAction:")];
    UIMenuItem *duplicateItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Clone", @"Clone context menu")
                                                           action:NSSelectorFromString(@"cloneAction:")];
    UIMenuItem *shareItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Share", @"Share context menu")
                                                       action:NSSelectorFromString(@"shareAction:")];
    [[UIMenuController sharedMenuController] setMenuItems:@[deleteItem, duplicateItem, shareItem]];
    
    // Set up refresh
    UIRefreshControl *refresh = [UIRefreshControl new];
    [refresh addTarget:self action:@selector(refreshWithSender:) forControlEvents:UIControlEventValueChanged];
    self.collectionView.refreshControl = refresh;
    
    self.viewVisibleSema = dispatch_semaphore_create(0);
    self.viewVisibleQueue = dispatch_queue_create("View Visible Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_wait(self.viewVisibleSema, DISPATCH_TIME_FOREVER);
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UTMImportNotification object:nil];
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_wait(self.viewVisibleSema, DISPATCH_TIME_FOREVER);
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    dispatch_semaphore_signal(self.viewVisibleSema);
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(importUTM:) name:UTMImportNotification object:nil];
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSURL *openURL = delegate.openURL;
    
    // refresh list
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        [self reloadData];
        
        // Did we startup with an URL?
        if (openURL) {
            [[NSNotificationCenter defaultCenter] postNotificationName:UTMImportNotification object:delegate];
        }
    });
    
#if !defined(WITH_QEMU_TCI)
    if (!jb_has_jit_entitlement()) {
        [self showStartupMessage];
    }
#endif
}

#pragma mark - Properties

- (NSURL *)documentsPath {
    return [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
}

#pragma mark - Helpers

- (void)reloadData {
    self.vmList = [self fetchVirtualMachines];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

- (NSArray<UTMVirtualMachine *> *)fetchVirtualMachines {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.documentsPath includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray<UTMVirtualMachine *> *vms = [[NSMutableArray alloc] initWithCapacity:files.count];
    for (NSURL *file in files) {
        NSNumber *isDir;
        [file getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
        if ([isDir boolValue] && [UTMVirtualMachine URLisVirtualMachine:file]) {
            UTMVirtualMachine *vm = [[UTMVirtualMachine alloc] initWithURL:file];
            if (vm) {
                [vms addObject:vm];
            }
        }
    }
    return vms;
}

- (NSString *)createNewDefaultName {
    NSString *(^nameForId)(NSUInteger) = ^(NSUInteger i) {
        return [NSString stringWithFormat:@"Virtual Machine %lu", i];
    };
    NSUInteger idx = 1;
    do {
        NSString *name = nameForId(idx);
        NSURL *file = [UTMVirtualMachine virtualMachinePath:name inParentURL:self.documentsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:file.path]) {
            return name;
        }
    } while (idx++ < 1000);
    return [[NSProcessInfo processInfo] globallyUniqueString];
}

- (void)showAlertSerialized:(NSString *)msg isQuestion:(BOOL)isQuestion completion:(nullable void (^)(void))completion {
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_t waitUntilCompletion = dispatch_semaphore_create(0);
        void (^handler)(UIAlertAction *action) = ^(UIAlertAction *action){
            dispatch_semaphore_signal(waitUntilCompletion);
            if (completion) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), completion);
            }
        };
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (isQuestion) {
                UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"VMListViewController") style:UIAlertActionStyleDestructive handler:handler];
                UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"VMListViewController") style:UIAlertActionStyleCancel handler:nil];
                [self showAlert:msg actions:@[yes, no] completion:nil];
            } else {
                [self showAlert:msg actions:nil completion:handler];
            }
        });
        dispatch_semaphore_wait(waitUntilCompletion, DISPATCH_TIME_FOREVER);
    });
}

- (void)showStartupMessage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownStartupAlert"]) {
        [self showAlertSerialized:NSLocalizedString(@"Welcome to UTM! Due to a bug in iOS, if you force kill this app, the system will be unstable and you cannot launch UTM again until you reboot. The recommended way to terminate this app is the button on the top left.", @"Startup message") isQuestion:NO completion:^{
            [defaults setBool:YES forKey:@"HasShownStartupAlert"];
        }];
    }
}

- (void)cloneVM:(NSURL *)url {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Name", @"Clone VM name prompt title")
                                                                   message:NSLocalizedString(@"New VM name", @"Clone VM name prompt message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields[0].text;
        NSURL *newPath = [UTMVirtualMachine virtualMachinePath:name inParentURL:self.documentsPath];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Saving %@...", @"Save VM overlay"), name]];
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:newPath error:&err];
            [self workCompletedWhenVisible:err.localizedDescription];
            [self reloadData];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button") style:UIAlertActionStyleCancel handler:nil]];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [UTMVirtualMachine virtualMachineName:url];
    }];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareVM:(NSURL *)url rect: (CGRect)rect {
    NSArray *objectsToShare = @[url];

    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];

    // Exclude all activities except AirDrop.
    NSArray *excludedActivities = @[UIActivityTypePostToTwitter, UIActivityTypePostToFacebook,
                                       UIActivityTypePostToWeibo,
                                       UIActivityTypeMessage, UIActivityTypeMail,
                                       UIActivityTypePrint, UIActivityTypeCopyToPasteboard,
                                       UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll,
                                       UIActivityTypeAddToReadingList, UIActivityTypePostToFlickr,
                                       UIActivityTypePostToVimeo, UIActivityTypePostToTencentWeibo];
    controller.excludedActivityTypes = excludedActivities;

    [controller.popoverPresentationController setSourceView: self.view];
    [controller.popoverPresentationController setSourceRect: rect];
    
    // Present the controller
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)deleteVM:(NSURL *)url {
    NSString *name = [UTMVirtualMachine virtualMachineName:url];
    [self showAlertSerialized:NSLocalizedString(@"Are you sure you want to delete this VM? Any drives associated will also be deleted.", @"Delete confirmation") isQuestion:YES completion:^{
        NSError *err = nil;
        [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Deleting %@...", @"Delete VM overlay"), name]];
        [[NSFileManager defaultManager] removeItemAtURL:url error:&err];
        [self workCompletedWhenVisible:err.localizedDescription];
        [self reloadData];
    }];
}

#pragma mark - Navigation

- (nonnull UTMVirtualMachine *)vmForCell:(id)cell {
    NSIndexPath *index = [self.collectionView indexPathForCell:cell];
    NSAssert(index, @"Cannot find index for selected VM");
    NSAssert(index.section == 0, @"Invalid section");
    return self.vmList[index.row];
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"editVMConfig"]){
        NSAssert([segue.destinationViewController isKindOfClass:[UINavigationController class]], @"Destination not a navigation view");
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        NSAssert([navController.topViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid segue destination");
        id<UTMConfigurationDelegate> controller = (id<UTMConfigurationDelegate>)navController.topViewController;
        NSAssert([sender isKindOfClass:[UIButton class]], @"Sender is not a UIButton");
        id cell = ((UIButton *)sender).superview.superview;
        self.modifyingVM = [self vmForCell:cell];
        controller.configuration = self.modifyingVM.configuration;
    } else if ([segue.identifier isEqualToString:@"newVM"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[UINavigationController class]], @"Destination not a navigation view");
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        NSAssert([navController.topViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid segue destination");
        id<UTMConfigurationDelegate> controller = (id<UTMConfigurationDelegate>)navController.topViewController;
        controller.configuration = [[UTMConfiguration alloc] init];
        controller.configuration.name = [self createNewDefaultName];
    } else if ([segue.identifier isEqualToString:@"startVM"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMDisplayMetalViewController class]], @"Destination not a metal view");
        VMDisplayMetalViewController *metalView = (VMDisplayMetalViewController *)segue.destinationViewController;
        UTMVirtualMachine *vm = (UTMVirtualMachine*) sender;
        metalView.vm = vm;
        vm.delegate = metalView;
        [metalView virtualMachine:vm transitionToState:vm.state];
    } else if ([[segue identifier] isEqualToString:@"startVMConsole"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMDisplayTerminalViewController class]], @"Destination not a terminal view");
        VMDisplayTerminalViewController *terminalView = (VMDisplayTerminalViewController *)segue.destinationViewController;
        UTMVirtualMachine *vm = (UTMVirtualMachine*) sender;
        terminalView.vm = vm;
        vm.delegate = terminalView;
    }
}

#pragma mark Collection view delegates

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section");
    return self.vmList.count;
}

- (VMListViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    VMListViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"vmListCell" forIndexPath:indexPath];
    
    // Configure the cell
    UTMVirtualMachine *vm = self.vmList[indexPath.row];
    cell.nameLabel.text = self.vmList[indexPath.row].configuration.name;
    [cell changeState:vm.state image:vm.screenshot.image];
    
    return cell;
}

- (nonnull NSArray<UIDragItem *> *)collectionView:(nonnull UICollectionView *)collectionView itemsForBeginningDragSession:(nonnull id<UIDragSession>)session atIndexPath:(nonnull NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSItemProvider *provider = [[NSItemProvider alloc] initWithContentsOfURL:self.vmList[indexPath.row].path];
    UIDragItem *drag = [[UIDragItem alloc] initWithItemProvider:provider];
    return @[drag];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == NSSelectorFromString(@"deleteAction:") || action == NSSelectorFromString(@"cloneAction:")  || action == NSSelectorFromString(@"shareAction:")) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES; // show context menu
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSURL *source = self.vmList[indexPath.row].path;
    if (action == NSSelectorFromString(@"deleteAction:")) {
        [self deleteVM:source];
    } else if (action == NSSelectorFromString(@"cloneAction:")) {
        [self cloneVM:source];
    } else if (action == NSSelectorFromString(@"shareAction:")) {
        UICollectionViewLayoutAttributes * theAttributes = [collectionView layoutAttributesForItemAtIndexPath:indexPath];

        CGRect cellFrameInSuperview = [collectionView convertRect:theAttributes.frame toView:[collectionView superview]];
        [self shareVM:source rect:cellFrameInSuperview];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView canHandleDropSession:(id<UIDropSession>)session {
    return NO;
}

- (void)collectionView:(nonnull UICollectionView *)collectionView performDropWithCoordinator:(nonnull id<UICollectionViewDropCoordinator>)coordinator {
}

#pragma mark - Work status indicator

- (void)workStartedWhenVisible:(NSString *)message {
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_t waitUntilCompletion = dispatch_semaphore_create(0);
        dispatch_sync(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[message stringByAppendingString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            if (@available(iOS 13.0, *)) {
                spinner.color = [UIColor labelColor];
            }
            spinner.hidesWhenStopped = YES;
            spinner.translatesAutoresizingMaskIntoConstraints = NO;
            [alert.view addSubview:spinner];
            
            NSDictionary * views = @{
                @"alert": alert.view,
                @"spinner": spinner
            };
            NSArray *constraintsVertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[spinner]-(20)-|" options:0 metrics:nil views:views];
            NSArray *constraintsHorizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[spinner]|" options:0 metrics:nil views:views];
            NSArray *constraints = [constraintsVertical arrayByAddingObjectsFromArray:constraintsHorizontal];
            [alert.view addConstraints:constraints];
            [spinner setUserInteractionEnabled:NO];
            [spinner startAnimating];
            self.alert = alert;
            [self presentViewController:alert animated:YES completion:^{
                dispatch_semaphore_signal(waitUntilCompletion);
            }];
        });
        dispatch_semaphore_wait(waitUntilCompletion, DISPATCH_TIME_FOREVER);
    });
}

- (void)workCompletedWhenVisible:(NSString *)message {
    dispatch_async(self.viewVisibleQueue, ^{
        self.vmList = [self fetchVirtualMachines];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
            [self.alert dismissViewControllerAnimated:YES completion:^{
                if (message) {
                    [self showAlertSerialized:message isQuestion:NO completion:nil];
                }
            }];
        });
    });
}

- (void)startVm:(UTMVirtualMachine *)vm {
    if (vm.supportedDisplayType == UTMDisplayTypeFullGraphic) {
        [self performSegueWithIdentifier:@"startVM" sender:vm];
    } else if (vm.supportedDisplayType == UTMDisplayTypeConsole) {
        [self performSegueWithIdentifier: @"startVMConsole" sender:vm];
    }
}

#pragma mark - Actions

- (IBAction)unwindToMainFromConfiguration:(UIStoryboardSegue*)sender {
    NSAssert([sender.sourceViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid source for unwind");
    id<UTMConfigurationDelegate> source = (id<UTMConfigurationDelegate>)sender.sourceViewController;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err;
        [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Saving %@...", @"Save VM overlay"), source.configuration.name]];
        UTMVirtualMachine *vm;
        if (self.modifyingVM.configuration == source.configuration) {
            vm = self.modifyingVM;
        } else {
            vm = [[UTMVirtualMachine alloc] initWithConfiguration:source.configuration withDestinationURL:self.documentsPath];
        }
        [vm saveUTMWithError:&err];
        [self workCompletedWhenVisible:err.localizedDescription];
    });
}

- (IBAction)startVmFromButton:(UIButton *)sender {
    UICollectionViewCell* cell = (UICollectionViewCell*) sender.superview.superview.superview.superview.superview.superview;
    UTMVirtualMachine* vm = [self vmForCell: cell];
    [self startVm:vm];
}

- (IBAction)startVmFromScreen:(UIButton *)sender {
    UICollectionViewCell* cell = (UICollectionViewCell*) sender.superview.superview;
    UTMVirtualMachine* vm = [self vmForCell: cell];
    [self startVm:vm];
}

- (IBAction)exitUTM:(UIBarButtonItem *)sender {
    exit(0);
}

- (IBAction)showHelp:(UIBarButtonItem *)sender {
    SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"https://getutm.app/guide/"]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)refreshWithSender:(UIRefreshControl *)sender {
    [self reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sender endRefreshing];
    });
}

#pragma mark - Notifications

- (void)importUTM:(NSNotification *)notification {
    NSURL *url = [notification.object openURL];
    [notification.object setOpenURL:nil];
    NSURL *fileBasePath = [url URLByDeletingLastPathComponent];
    NSString *file = url.lastPathComponent;
    NSURL *dest = [self.documentsPath URLByAppendingPathComponent:file isDirectory:YES];
    if (file.length == 0) {
        [self showAlertSerialized:NSLocalizedString(@"Invalid UTM not imported.", @"VMListViewController") isQuestion:NO completion:nil];
    } else if ([[dest URLByResolvingSymlinksInPath] isEqual:[url URLByResolvingSymlinksInPath]]) {
        UTMVirtualMachine *found;
        for (UTMVirtualMachine *vm in self.vmList) {
            if ([vm.path.lastPathComponent isEqualToString:file]) {
                found = vm;
                break;
            }
        }
        if (!found) {
            [self showAlertSerialized:NSLocalizedString(@"Cannot find VM.", @"VMListViewController") isQuestion:NO completion:nil];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startVm:found];
            });
        }
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
        [self showAlertSerialized:NSLocalizedString(@"A VM already exists with this name.", @"VMListViewController") isQuestion:NO completion:nil];
    } else if ([[fileBasePath URLByResolvingSymlinksInPath] isEqual:[[self.documentsPath URLByAppendingPathComponent:@"Inbox" isDirectory:YES] URLByResolvingSymlinksInPath]]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Moving %@...", @"Save VM overlay"), file]];
            [[NSFileManager defaultManager] moveItemAtURL:url toURL:dest error:&err];
            [self workCompletedWhenVisible:err.localizedDescription];
            [self reloadData];
        });
    } else {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Importing %@...", @"Save VM overlay"), file]];
            [url startAccessingSecurityScopedResource];
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:dest error:&err];
            [url stopAccessingSecurityScopedResource];
            [self workCompletedWhenVisible:err.localizedDescription];
            [self reloadData];
        });
    }
}

@end
