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

@interface VMListViewController ()

@end

@implementation VMListViewController

static NSString * const reuseIdentifier = @"vmListCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Do any additional setup after loading the view.
    [[self vmCollection] setDragInteractionEnabled:YES];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"editVMConfig"]){
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        id<UTMConfigurationDelegate> controller = (id<UTMConfigurationDelegate>)navController.topViewController;
        controller.configuration = [[UTMConfiguration alloc] initWithDefaults];
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
#warning Incomplete implementation, return the number of sections
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
#warning Incomplete implementation, return the number of items
    return 5;
}

VMListViewCell *test_cell;
VMState test_state;

- (VMListViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    VMListViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    [cell setName:@"Test VM"];
    [cell changeState:kStopped];
    test_state = kStopped;
    test_cell = cell;
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

/*
 // Uncomment this method to specify if the specified item should be highlighted during tracking
 - (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
 return YES;
 }
*/

/*
 // Uncomment this method to specify if the specified item should be selected
 - (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
 return YES;
 }
*/

/*
 // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
 - (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
 return NO;
 }
 
 - (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
 return NO;
 }
 
 - (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
 
 }
 */

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return YES;
}

#pragma mark <UICollectionViewDragDelegate>

- (nonnull NSArray<UIDragItem *> *)collectionView:(nonnull UICollectionView *)collectionView itemsForBeginningDragSession:(nonnull id<UIDragSession>)session atIndexPath:(nonnull NSIndexPath *)indexPath {
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    UIDragItem *drag = [[UIDragItem alloc] initWithItemProvider:provider];
    return @[drag];
}

#pragma mark <UICollectionViewDropDelegate>

- (void)collectionView:(nonnull UICollectionView *)collectionView performDropWithCoordinator:(nonnull id<UICollectionViewDropCoordinator>)coordinator {
}

@end
