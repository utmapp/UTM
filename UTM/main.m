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
#import "AppDelegate.h"

extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

int main(int argc, char * argv[]) {
    // Thanks to this comment: https://news.ycombinator.com/item?id=18431524
    // We use this hack to allow mmap with PROT_EXEC which requires
    // dynamic_codesign entitlement and the process to be tricked into thinking
    // that Xcode is debugging it. We abuse the fact that JIT is needed to
    // debug the process.
    ptrace(0, 0, NULL, 0);
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
