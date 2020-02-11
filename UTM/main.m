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

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

#define PTRACE_TRACEME 0
#define PT_DENY_ATTACH 31

int main(int argc, char * argv[]) {
    @autoreleasepool {
        @try {
            // Thanks to this comment: https://news.ycombinator.com/item?id=18431524
            // We use this hack to allow mmap with PROT_EXEC which requires
            // dynamic_codesign entitlement and the process to be tricked into thinking
            // that Xcode is debugging it. We abuse the fact that JIT is needed to
            // debug the process.
            ptrace(PTRACE_TRACEME, 0, NULL, 0);
            return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        }
        @finally {
            // New in iOS 13: due to some kernel/system bug, if we leave a process
            // with PT_TRACE_ME, it will not get terminated properly and will refuse
            // to launch again.
            ptrace(PT_DENY_ATTACH, 0, NULL, 0);
            // for debugging uncaught exception crashes, set a breakpoint on exceptions
            // and then use `po $arg1` to dump the exception string.
        }
    }
}
