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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VMState) {
    kStopped,
    kStarting,
    kStarted,
    kPausing,
    kPaused,
    kResuming,
    kResumed,
    kStopping
};

@interface VMListViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *screenBlurEffect;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *screenButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *statusIndicator;
@property (weak, nonatomic) IBOutlet UIButton *editButton;

- (void)changeState:(VMState)state withScreen:(nullable UIImage *)image;
- (void)changeState:(VMState)state;
- (void)setName:(NSString *)name;
- (IBAction)playButtonAction:(id)sender;
- (IBAction)screenButtonAction:(id)sender;
- (IBAction)editAction:(id)sender;

@end

NS_ASSUME_NONNULL_END
