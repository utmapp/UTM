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

#include <errno.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <TargetConditionals.h>
#include <unistd.h>
#include "UTMJailbreak.h"

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
    fprintf(stderr, "Caught exception %d (this should be EXC_SOFTWARE), with code 0x%x (this should be EXC_SOFT_SIGNAL) and subcode %d. Forcing suicide.", exception, *code, code[1]);
    // _exit doesn't seem to work, but this does. ¯\_(ツ)_/¯
    return KERN_FAILURE;
}

static void *exception_handler(void *argument) {
    mach_port_t port = *(mach_port_t *)argument;
    mach_msg_server(exc_server, 2048, port, 0);
    return NULL;
}

static bool am_i_being_debugged() {
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info = {};
    size_t size = sizeof(info);
    return !sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0) && !!(info.kp_proc.p_flag & P_TRACED);
}


bool jb_has_jit_entitlement(void) {
#if TARGET_OS_SIMULATOR
    return false; // simulator allows MAP_JIT so we pretend it doesn't for testing
#else
    void *addr = mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE | MAP_JIT, -1, 0);
    if (addr != NULL) {
        munmap(addr, PAGE_SIZE);
        return true;
    } else {
        return false;
    }
#endif
}

bool jb_has_ptrace_hack(void) {
    int res = ptrace(-1, -1, NULL, 0);
    if (res < 0 && errno == EINVAL) {
        return true;
    } else {
        return false;
    }
}

void jb_enable_ptrace_hack(void) {
    bool debugged = am_i_being_debugged();
    
    // Thanks to this comment: https://news.ycombinator.com/item?id=18431524
    // We use this hack to allow mmap with PROT_EXEC (which usually requires the
    // dynamic-codesigning entitlement) by tricking the process into thinking
    // that Xcode is debugging it. We abuse the fact that JIT is needed to
    // debug the process.
    ptrace(PT_TRACE_ME, 0, NULL, 0);
    
    // ptracing ourselves confuses the kernel and will cause bad things to
    // happen to the system (hangs…) if an exception or signal occurs. Setup
    // some "safety nets" so we can cause the process to exit in a somewhat sane
    // state. We only need to do this if the debugger isn't attached. (It'll do
    // this itself, and if we do it we'll interfere with its normal operation
    // anyways.)
    if (!debugged) {
        // First, ensure that signals are delivered as Mach software exceptions…
        ptrace(PT_SIGEXC, 0, NULL, 0);
        
        // …then ensure that this exception goes through our exception handler.
        // I think it's OK to just watch for EXC_SOFTWARE because the other
        // exceptions (e.g. EXC_BAD_ACCESS, EXC_BAD_INSTRUCTION, and friends)
        // will end up being delivered as signals anyways, and we can get them
        // once they're resent as a software exception.
        mach_port_t port = MACH_PORT_NULL;
        mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
        mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
        task_set_exception_ports(mach_task_self(), EXC_MASK_SOFTWARE, port, EXCEPTION_DEFAULT, THREAD_STATE_NONE);
        pthread_t thread;
        pthread_create(&thread, NULL, exception_handler, (void *)&port);
    }
}
