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
#import "VMListViewCell.h"
#import "UTMConfigurationDelegate.h"
#import "UTMConfiguration.h"
#import "UTMVirtualMachine.h"
#import "VMDisplayMetalViewController.h"
#import "CSDisplayMetal.h"

@interface VMListViewController ()

@property (nonatomic, readonly) NSURL *documentsPath;
@property (nonatomic, strong) UTMVirtualMachine *activeVM;
@property (nonatomic, strong) UTMVirtualMachine *modifyingVM;
@property (nonatomic, strong) NSArray<NSURL *> *vmList;
@property (nonatomic, nullable, strong) UIAlertController *alert;
@property (nonatomic, strong) dispatch_semaphore_t viewVisibleSema;
@property (nonatomic, strong) dispatch_queue_t viewVisibleQueue;
@property (nonatomic, weak) VMListViewCell *activeCell;

- (NSArray<NSURL *> *)fetchVirtualMachines;
- (void)workStartedWhenVisible:(NSString *)message;
- (void)workCompletedWhenVisible:(NSString *)message;

@end

@implementation VMListViewController

@synthesize vmMessage;
@synthesize vmDisplay;
@synthesize vmInput;
@synthesize vmConfiguration;
@synthesize toolbarVisible;
@synthesize keyboardVisible;

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
    [[UIMenuController sharedMenuController] setMenuItems:@[deleteItem, duplicateItem]];
    
    self.viewVisibleSema = dispatch_semaphore_create(0);
    self.viewVisibleQueue = dispatch_queue_create("View Visible Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_wait(self.viewVisibleSema, DISPATCH_TIME_FOREVER);
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_wait(self.viewVisibleSema, DISPATCH_TIME_FOREVER);
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    dispatch_semaphore_signal(self.viewVisibleSema);
    
    // refresh list
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        [self reloadData];
    });
    
    // show any message
    [self showStartupMessage];
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

- (NSArray<NSURL *> *)fetchVirtualMachines {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.documentsPath includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray<NSURL *> *vmFiles = [[NSMutableArray alloc] initWithCapacity:files.count];
    for (NSURL *file in files) {
        if ([UTMVirtualMachine URLisVirtualMachine:file]) {
            [vmFiles addObject:file];
        }
    }
    return vmFiles;
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

- (void)showAlert:(NSString *)msg actions:(nullable NSArray<UIAlertAction *> *)actions completion:(nullable void (^)(void))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    if (!actions) {
        UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okay];
    } else {
        for (UIAlertAction *action in actions) {
            [alert addAction:action];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:completion];
    });
}

- (void)showStartupMessage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasShownStartupAlert"]) {
        [self showAlert:NSLocalizedString(@"Welcome to UTM! Due to a bug in iOS, if you force kill this app, the system will be unstable and you cannot launch UTM again until you reboot. The recommended way to terminate this app is the button on the top left.", @"Startup message") actions:nil completion:^{
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

- (void)deleteVM:(NSURL *)url {
    NSString *name = [UTMVirtualMachine virtualMachineName:url];
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes button") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Deleting %@...", @"Delete VM overlay"), name]];
            [[NSFileManager defaultManager] removeItemAtURL:url error:&err];
            [self workCompletedWhenVisible:err.localizedDescription];
            [self reloadData];
        });
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No button") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to delete this VM? Any drives associated will also be deleted.", @"Delete confirmation") actions:@[yes, no] completion:nil];
}

#pragma mark - Navigation

- (nonnull UTMVirtualMachine *)cachedVMForCell:(id)cell {
    NSIndexPath *index = [self.collectionView indexPathForCell:cell];
    NSAssert(index, @"Cannot find index for selected VM");
    NSAssert(index.section == 0, @"Invalid section");
    NSString *name = [UTMVirtualMachine virtualMachineName:self.vmList[index.row]];
    if ([self.activeVM.configuration.name isEqualToString:name]) {
        return self.activeVM;
    } else if ([self.modifyingVM.configuration.name isEqualToString:name]) {
        return self.modifyingVM;
    } else {
        return [[UTMVirtualMachine alloc] initWithURL:self.vmList[index.row]];
    }
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
        self.modifyingVM = [self cachedVMForCell:cell];
        controller.configuration = self.modifyingVM.configuration;
    } else if ([segue.identifier isEqualToString:@"newVM"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[UINavigationController class]], @"Destination not a navigation view");
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        NSAssert([navController.topViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid segue destination");
        id<UTMConfigurationDelegate> controller = (id<UTMConfigurationDelegate>)navController.topViewController;
        self.modifyingVM = [[UTMVirtualMachine alloc] initDefaults:[self createNewDefaultName] withDestinationURL:self.documentsPath];
        controller.configuration = self.modifyingVM.configuration;
    } else if ([segue.identifier isEqualToString:@"startVM"]) {
        NSAssert([segue.destinationViewController isKindOfClass:[VMDisplayMetalViewController class]], @"Destination not a metal view");
        VMDisplayMetalViewController *metalView = (VMDisplayMetalViewController *)segue.destinationViewController;
        [metalView changeVM:self.activeVM];
        self.activeVM.delegate = metalView;
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
    NSString *name = [UTMVirtualMachine virtualMachineName:self.vmList[indexPath.row]];
    [cell setName:name];
    if ([self.activeVM.configuration.name isEqualToString:name]) {
        [cell changeState:self.activeVM.state image:self.activeVM.primaryDisplay.screenshot];
    } else {
        [cell changeState:kVMStopped image:nil];
    }
    
    return cell;
}

- (nonnull NSArray<UIDragItem *> *)collectionView:(nonnull UICollectionView *)collectionView itemsForBeginningDragSession:(nonnull id<UIDragSession>)session atIndexPath:(nonnull NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSItemProvider *provider = [[NSItemProvider alloc] initWithContentsOfURL:self.vmList[indexPath.row]];
    UIDragItem *drag = [[UIDragItem alloc] initWithItemProvider:provider];
    return @[drag];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == NSSelectorFromString(@"deleteAction:") || action == NSSelectorFromString(@"cloneAction:")) {
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
    NSURL *source = self.vmList[indexPath.row];
    if (action == NSSelectorFromString(@"deleteAction:")) {
        [self deleteVM:source];
    } else if (action == NSSelectorFromString(@"cloneAction:")) {
        [self cloneVM:source];
    }
}

/*
- (BOOL)collectionView:(UICollectionView *)collectionView canHandleDropSession:(id<UIDropSession>)session {
    // TODO: implement this
}

- (void)collectionView:(nonnull UICollectionView *)collectionView performDropWithCoordinator:(nonnull id<UICollectionViewDropCoordinator>)coordinator {
    // TODO: implement this
}
*/

#pragma mark - VM delegate

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activeCell changeState:state image:vm.screenshot];
        switch (state) {
            case kVMError: {
                NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"Alert message");
                [self showAlert:msg actions:nil completion:nil];
                break;
            }
            case kVMStarted:
            case kVMResumed: {
                [self performSegueWithIdentifier:@"startVM" sender:self];
                break;
            }
            default: {
                break;
            }
        }
    });
}

#pragma mark - Work status indicator

- (void)workStartedWhenVisible:(NSString *)message {
    dispatch_async(self.viewVisibleQueue, ^{
        dispatch_semaphore_t waitUntilCompletion = dispatch_semaphore_create(0);
        dispatch_sync(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(10, 5, 50, 50)];
            spinner.hidesWhenStopped = YES;
            spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
            [spinner startAnimating];
            [alert.view addSubview:spinner];
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
            [self.alert dismissViewControllerAnimated:YES completion:nil];
            if (message) {
                [self showAlert:message actions:nil completion:nil];
            }
        });
    });
}

#pragma mark - Actions

- (IBAction)unwindToMainFromConfiguration:(UIStoryboardSegue*)sender {
    NSAssert([sender.sourceViewController conformsToProtocol:@protocol(UTMConfigurationDelegate)], @"Invalid source for unwind");
    id<UTMConfigurationDelegate> source = (id<UTMConfigurationDelegate>)sender.sourceViewController;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err;
        [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Saving %@...", @"Save VM overlay"), source.configuration.name]];
        if (source.configuration == self.modifyingVM.configuration) {
            [self.modifyingVM saveUTMWithError:&err];
            self.modifyingVM = nil; // must do this BEFORE work complete, or user might press another button
            [self workCompletedWhenVisible:err.localizedDescription];
        } else {
            NSLog(@"Trying to save configuration for a VM that is not being edited!\n");
            [self workCompletedWhenVisible:NSLocalizedString(@"An internal error has occured!", @"Alert message")];
        }
    });
}

- (IBAction)unwindToMainFromVM:(UIStoryboardSegue*)sender {
    self.activeVM.delegate = self;
}

- (void)startVM:(id)cell {
    NSAssert([cell isKindOfClass:[VMListViewCell class]], @"Invalid cell class");
    // TODO: Fix the need for this
    if (self.activeVM != nil) {
        UTMVirtualMachine *newActive = [self cachedVMForCell:cell];
        if (self.activeVM != newActive) {
            [self showAlert:NSLocalizedString(@"Launching another VM is not implemented. Please close UTM with the top left button and re-launch it.", nil) actions:nil completion:nil];
            return;
        }
    }
    self.activeVM = [self cachedVMForCell:cell];
    self.activeCell = cell;
    self.activeVM.delegate = self;
    [self.activeVM startVM];
    [self virtualMachine:self.activeVM transitionToState:self.activeVM.state];
}

- (IBAction)startVMFromButton:(UIButton *)sender {
    [self startVM:sender.superview.superview.superview.superview.superview.superview];
}

- (IBAction)startVMFromScreen:(UIButton *)sender {
    [self startVM:sender.superview.superview];
}

- (IBAction)exitUTM:(UIBarButtonItem *)sender {
    UIAlertAction *yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes button") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        exit(0);
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No button") style:UIAlertActionStyleCancel handler:nil];
    [self showAlert:NSLocalizedString(@"Are you sure you want to exit UTM? Any running VM will be killed.", @"Exit confirmation") actions:@[yes, no] completion:nil];
}

@end
