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
#import <mach/mach.h>
#import <pthread.h>
#import "AppDelegate.h"

extern boolean_t exc_server(mach_msg_header_t *, mach_msg_header_t *);
extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

#define PT_TRACE_ME 0
#define PT_SIGEXC 12

kern_return_t catch_exception_raise(mach_port_t exception_port,
                                    mach_port_t thread,
                                    mach_port_t task,
                                    exception_type_t exception,
                                    exception_data_t code,
                                    mach_msg_type_number_t code_count) {
    NSLog(@"Caught exception %d (this should be EXC_SOFTWARE), with code 0x%x (this should be EXC_SOFT_SIGNAL) and subcode %d. Forcing suicide.", exception, *code, code[1]);
    // _exit doesn't seem to work, but this does. ¯\_(ツ)_/¯
    return KERN_FAILURE;
}

void *exception_handler(void *argument) {
    mach_port_t port = *(mach_port_t *)argument;
    mach_msg_server(exc_server, 2048, port, 0);
    return NULL;
}

int main(int argc, char * argv[]) {
    // Thanks to this comment: https://news.ycombinator.com/item?id=18431524
    // We use this hack to allow mmap with PROT_EXEC (which usually requires the
    // dynamic-codesigning entitlement) by tricking the process into thinking
    // that Xcode is debugging it. We abuse the fact that JIT is needed to
    // debug the process.
    ptrace(PT_TRACE_ME, 0, NULL, 0);
    
    // ptracing ourselves confuses the kernel and will cause bad things to
    // happen to the system (hangs…) if an exception or signal occurs. Setup
    // some "safety nets" so we can cause the process to exit in a somewhat sane
    // state.
    
    // First, ensure that signals are delivered as a Mach software exception…
    ptrace(PT_SIGEXC, 0, NULL, 0);
    
    // …then ensure that this exception goes through our exception handler. I
    // think it's OK to just watch for EXC_SOFTWARE because the other exceptions
    // (e.g. EXC_BAD_ACCESS, EXC_BAD_INSTRUCTION, and friends) will end up being
    // delivered as signals anyways, and we can get them once they're resent as
    // a software exception.
    mach_port_t port = MACH_PORT_NULL;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    task_set_exception_ports(mach_task_self(), EXC_MASK_SOFTWARE, port, EXCEPTION_DEFAULT, THREAD_STATE_NONE);
    pthread_t thread;
    pthread_create(&thread, NULL, exception_handler, (void *)&port);
    
    // Continue with normal application launch.
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
