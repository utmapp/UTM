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

#import "UIViewController+Extensions.h"

@implementation UIViewController (Extensions)

- (void)onDelay:(float)delay action:(void (^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*0.1), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), block);
}

- (BOOL)boolForSetting:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (NSInteger)integerForSetting:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

- (void)showAlert:(NSString *)msg actions:(nullable NSArray<UIAlertAction *> *)actions completion:(nullable void (^)(UIAlertAction *action))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    if (!actions) {
        UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK Button") style:UIAlertActionStyleDefault handler:completion];
        [alert addAction:okay];
    } else {
        for (UIAlertAction *action in actions) {
            [alert addAction:action];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end

