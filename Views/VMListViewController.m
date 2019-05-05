//
// Copyright © 2019 Halts. All rights reserved.
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
@synthesize vmScreenshot;
@synthesize vmRendering;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Do any additional setup after loading the view.
    [self.collectionView setDragInteractionEnabled:YES];
    
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
        self.vmList = [self fetchVirtualMachines];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
        });
    });
}

#pragma mark - Properties

- (NSURL *)documentsPath {
    return [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
}

#pragma mark - Helpers

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
        metalView.vm = self.activeVM;
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
        [cell changeState:self.activeVM.state image:self.vmScreenshot];
    } else {
        [cell changeState:kVMStopped image:nil];
    }
    
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return YES;
}

- (nonnull NSArray<UIDragItem *> *)collectionView:(nonnull UICollectionView *)collectionView itemsForBeginningDragSession:(nonnull id<UIDragSession>)session atIndexPath:(nonnull NSIndexPath *)indexPath {
    NSAssert(indexPath.section == 0, @"Invalid section");
    NSItemProvider *provider = [[NSItemProvider alloc] initWithContentsOfURL:self.vmList[indexPath.row]];
    UIDragItem *drag = [[UIDragItem alloc] initWithItemProvider:provider];
    return @[drag];
}

- (void)collectionView:(nonnull UICollectionView *)collectionView performDropWithCoordinator:(nonnull id<UICollectionViewDropCoordinator>)coordinator {
    // TODO: implement this
}

#pragma mark - VM delegate

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activeCell changeState:state image:self.vmScreenshot];
        switch (state) {
            case kVMError: {
                NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"Alert message");
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okay];
                [self presentViewController:alert animated:YES completion:nil];
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
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okay];
                [self presentViewController:alert animated:YES completion:nil];
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
        [self workStartedWhenVisible:[NSString stringWithFormat:NSLocalizedString(@"Saving %@...", @"Save VM overlay"), source.configuration.changeName]];
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
    [self.activeCell changeState:self.activeVM.state image:nil];
}

- (IBAction)startVMFromButton:(UIButton *)sender {
    id cell = sender.superview.superview.superview.superview.superview.superview;
    NSAssert([cell isKindOfClass:[VMListViewCell class]], @"Invalid cell class");
    self.activeVM = [self cachedVMForCell:cell];
    self.activeCell = cell;
    self.activeVM.delegate = self;
    [self.activeVM startVM];
    [self virtualMachine:self.activeVM transitionToState:self.activeVM.state];
}

- (IBAction)startVMFromScreen:(UIButton *)sender {
    id cell = sender.superview.superview;
    NSAssert([cell isKindOfClass:[VMListViewCell class]], @"Invalid cell class");
    self.activeVM = [self cachedVMForCell:cell];
    self.activeCell = cell;
    self.activeVM.delegate = self;
    [self.activeVM startVM];
    [self virtualMachine:self.activeVM transitionToState:self.activeVM.state];
}

@end
