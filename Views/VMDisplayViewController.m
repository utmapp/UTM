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

#import "VMDisplayViewController.h"

@interface VMDisplayViewController ()

@end

@implementation VMDisplayViewController

- (void)loadMainViewFromNib {
    UINib *nib = [UINib nibWithNibName:@"VMDisplayView" bundle:nil];
    NSArray *arr = [nib instantiateWithOwner:self options:nil];
    NSAssert(arr != nil, @"Failed to load VMDisplayView nib");
    NSAssert(self.mainView != nil, @"Failed to load main view from VMDisplayView nib");
    NSAssert(self.inputAccessoryView != nil, @"Failed to load input view from VMDisplayView nib");
    self.mainView.frame = self.view.bounds;
    self.mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self moveSubviewsTo:self.controlView];
    [self.view addSubview:self.mainView];
}

- (void)moveSubviewsTo:(UIView *)destView {
    NSArray<UIView *> *subviews = self.view.subviews;
    for (UIView *subview in subviews) {
        NSArray<NSLayoutConstraint *> *constraints = self.view.constraints;
        [subview removeFromSuperview];
        [destView addSubview:subview];
        [self moveConstraints:constraints subview:subview to:destView];
    }
}

- (void)moveConstraints:(NSArray<NSLayoutConstraint *> *)constraints subview:(UIView *)subview to:(UIView *)destView {
    for (NSLayoutConstraint *constraint in constraints) {
        if (constraint.firstItem == subview && constraint.secondItem == self.view) {
            NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:constraint.firstItem
                                                                             attribute:constraint.firstAttribute
                                                                             relatedBy:constraint.relation
                                                                                toItem:destView
                                                                             attribute:constraint.secondAttribute
                                                                            multiplier:constraint.multiplier
                                                                              constant:constraint.constant];
            newConstraint.active = constraint.active;
            newConstraint.priority = constraint.priority;
            newConstraint.shouldBeArchived = constraint.shouldBeArchived;
            [destView addConstraint:newConstraint];
        } else if (constraint.firstItem == self.view && constraint.secondItem == subview) {
            NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:destView
                                                                             attribute:constraint.firstAttribute
                                                                             relatedBy:constraint.relation
                                                                                toItem:constraint.secondItem
                                                                             attribute:constraint.secondAttribute
                                                                            multiplier:constraint.multiplier
                                                                              constant:constraint.constant];
            newConstraint.active = constraint.active;
            newConstraint.priority = constraint.priority;
            newConstraint.shouldBeArchived = constraint.shouldBeArchived;
            [destView addConstraint:newConstraint];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadMainViewFromNib];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    [self loadMainViewFromNib];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

@end
