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

// Parts taken from iSH: https://github.com/ish-app/ish/blob/master/app/AppGroup.m
//  Created by Theodore Dubois on 2/28/20.
//  Licensed under GNU General Public License 3.0

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach-o/getsect.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <TargetConditionals.h>
#include <unistd.h>
#include "UTMJailbreak.h"

struct cs_blob_index {
    uint32_t type;
    uint32_t offset;
};

struct cs_superblob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
    struct cs_blob_index index[];
};

struct cs_entitlements {
    uint32_t magic;
    uint32_t length;
    char entitlements[];
};

#if !TARGET_OS_OSX && !defined(WITH_QEMU_TCI)
extern int csops(pid_t pid, unsigned int ops, void * useraddr, size_t usersize);
extern boolean_t exc_server(mach_msg_header_t *, mach_msg_header_t *);
extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

#define    CS_OPS_STATUS        0    /* return status */
#define CS_KILL     0x00000200  /* kill process if it becomes invalid */
#define CS_DEBUGGED 0x10000000  /* process is currently or has previously been debugged and allowed to run with invalid pages */
#define PT_TRACE_ME     0       /* child declares it's being traced */
#define PT_SIGEXC       12      /* signals as exceptions for current_proc */

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

static bool jb_has_debugger_attached(void) {
    int flags;
    return !csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) && flags & CS_DEBUGGED;
}
#endif

bool jb_has_cs_disabled(void) {
#if TARGET_OS_OSX || defined(WITH_QEMU_TCI)
    return false;
#else
    int flags;
    return !csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) && (flags & ~CS_KILL) == flags;
#endif
}

static NSDictionary *parse_entitlements(const void *entitlements, size_t length) {
    char *copy = malloc(length);
    memcpy(copy, entitlements, length);
    
    // strip out psychic paper entitlement hiding
    if (@available(iOS 13.5, *)) {
    } else {
        static const char *needle = "<!---><!-->";
        char *found = strnstr(copy, needle, length);
        if (found) {
            memset(found, ' ', strlen(needle));
        }
    }
    NSData *data = [NSData dataWithBytes:copy length:length];
    free(copy);
    
    return [NSPropertyListSerialization propertyListWithData:data
                                                     options:NSPropertyListImmutable
                                                      format:nil
                                                       error:nil];
}

static NSDictionary *app_entitlements(void) {
    // Inspired by codesign.c in Darwin sources for Security.framework
    
    // Find our mach-o header
    Dl_info dl_info;
    if (dladdr(app_entitlements, &dl_info) == 0)
        return nil;
    if (dl_info.dli_fbase == NULL)
        return nil;
    char *base = dl_info.dli_fbase;
    struct mach_header_64 *header = dl_info.dli_fbase;
    if (header->magic != MH_MAGIC_64)
        return nil;
    
    // Simulator executables have fake entitlements in the code signature. The real entitlements can be found in an __entitlements section.
    size_t entitlements_size;
    uint8_t *entitlements_data = getsectiondata(header, "__TEXT", "__entitlements", &entitlements_size);
    if (entitlements_data != NULL) {
        NSData *data = [NSData dataWithBytesNoCopy:entitlements_data
                                            length:entitlements_size
                                      freeWhenDone:NO];
        return [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:nil
                                                           error:nil];
    }
    
    // Find the LC_CODE_SIGNATURE
    struct load_command *lc = (void *) (base + sizeof(*header));
    struct linkedit_data_command *cs_lc = NULL;
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_CODE_SIGNATURE) {
            cs_lc = (void *) lc;
            break;
        }
        lc = (void *) ((char *) lc + lc->cmdsize);
    }
    if (cs_lc == NULL)
        return nil;

    // Read the code signature off disk, as it's apparently not loaded into memory
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:NSBundle.mainBundle.executableURL error:nil];
    if (fileHandle == nil)
        return nil;
    [fileHandle seekToFileOffset:cs_lc->dataoff];
    NSData *csData = [fileHandle readDataOfLength:cs_lc->datasize];
    [fileHandle closeFile];
    const struct cs_superblob *cs = csData.bytes;
    if (ntohl(cs->magic) != 0xfade0cc0)
        return nil;
    
    // Find the entitlements in the code signature
    for (uint32_t i = 0; i < ntohl(cs->count); i++) {
        struct cs_entitlements *ents = (void *) ((char *) cs + ntohl(cs->index[i].offset));
        if (ntohl(ents->magic) == 0xfade7171) {
            return parse_entitlements(ents->entitlements, ntohl(ents->length) - offsetof(struct cs_entitlements, entitlements));
        }
    }
    return nil;
}

static NSDictionary *cached_app_entitlements(void) {
    static NSDictionary *entitlements = nil;
    if (!entitlements) {
        entitlements = app_entitlements();
    }
    return entitlements;
}

#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#define _COMM_PAGE_START_ADDRESS        (0x0000000FFFFFC000ULL) /* In TTBR0 */
#define _COMM_PAGE_APRR_SUPPORT         (_COMM_PAGE_START_ADDRESS+0x10C)

// this is kinda hacky heuristic to figure out if we are running >= A12
// not sure why 14.2 JIT doesn't work below A12 yet but oh well
static bool is_device_A12_or_newer(void) {
    // devices without APRR are definitely < A12
    char aprr_support = *(volatile char *)_COMM_PAGE_APRR_SUPPORT;
    if (aprr_support == 0) {
        return false;
    }
    // we still have A11 devices that support APRR
    struct utsname systemInfo;
    if (uname(&systemInfo) != 0) {
        return false;
    }
    // iPhone 8, 8 Plus, and iPhone X
    if (strncmp("iPhone10,", systemInfo.machine, 9) == 0) {
        return false;
    } else {
        return true;
    }
}

#else

static bool is_device_A12_or_newer(void) {
    return false;
}

#endif

bool jb_has_jit_entitlement(void) {
#if TARGET_OS_OSX
    return true;
#elif defined(WITH_QEMU_TCI)
    return false;
#else
    NSDictionary *entitlements = cached_app_entitlements();
    return [entitlements[@"dynamic-codesigning"] boolValue];
#endif
}

#if TARGET_OS_OSX
@import Security;

bool jb_has_usb_entitlement(void) {
    SecTaskRef task;
    CFTypeRef value;
    static bool cached = false;
    static bool entitled = false;
    
    if (cached) {
        return entitled;
    }

    task = SecTaskCreateFromSelf (kCFAllocatorDefault);
    if (task == NULL) {
      return false;
    }
    value = SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.security.device.usb"), NULL);
    CFRelease (task);
    entitled = value && (CFGetTypeID (value) == CFBooleanGetTypeID ()) && CFBooleanGetValue (value);
    cached = true;
    if (value) {
      CFRelease (value);
    }
    return entitled;
}
#else
bool jb_has_usb_entitlement(void) {
    NSDictionary *entitlements = cached_app_entitlements();
    return entitlements[@"com.apple.security.exception.iokit-user-client-class"] != nil;
}
#endif

bool jb_has_cs_execseg_allow_unsigned(void) {
    NSDictionary *entitlements = cached_app_entitlements();
    if (@available(iOS 14.2, *)) {
        if (@available(iOS 14.4, *)) {
            return false; // iOS 14.4 broke it again
        }
        // technically we need to check the Code Directory and make sure
        // CS_EXECSEG_ALLOW_UNSIGNED is set but we assume that it is properly
        // signed, which should reflect the get-task-allow entitlement
        return is_device_A12_or_newer() && [entitlements[@"get-task-allow"] boolValue];
    } else {
        return false;
    }
}

bool jb_enable_ptrace_hack(void) {
#if TARGET_OS_OSX || defined(WITH_QEMU_TCI)
    return false;
#else
    bool debugged = jb_has_debugger_attached();
    
    // Thanks to this comment: https://news.ycombinator.com/item?id=18431524
    // We use this hack to allow mmap with PROT_EXEC (which usually requires the
    // dynamic-codesigning entitlement) by tricking the process into thinking
    // that Xcode is debugging it. We abuse the fact that JIT is needed to
    // debug the process.
    if (ptrace(PT_TRACE_ME, 0, NULL, 0) < 0) {
        return false;
    }
    
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
    
    return true;
#endif
}
