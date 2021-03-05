//
// Copyright © 2021 osy. All rights reserved.
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

#include "Bootstrap.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sys/event.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct {
    int (*qemu_init)(int, const char *[], const char *[]);
    void (*qemu_main_loop)(void);
    void (*qemu_cleanup)(void);
} qemu_main_t;

// http://mac-os-x.10953.n7.nabble.com/Ensure-NSTask-terminates-when-parent-application-does-td31477.html
static void *WatchForParentTermination(void *args) {
    pid_t ppid = getppid(); // get parent pid

    int kq = kqueue();
    if (kq != -1) {
        struct kevent procEvent; // wait for parent to exit
        EV_SET(&procEvent, // kevent
               ppid, // ident
               EVFILT_PROC, // filter
               EV_ADD, // flags
               NOTE_EXIT, // fflags
               0, // data
               0); // udata
        kevent(kq, &procEvent, 1, &procEvent, 1, NULL);
    }

    exit(0);
    return NULL;
}

static int loadQemu(const char *dylibPath, qemu_main_t *funcs) {
    void *dlctx;
    
    if ((dlctx = dlopen(dylibPath, RTLD_LOCAL | RTLD_LAZY | RTLD_FIRST)) == NULL) {
        fprintf(stderr, "Error loading %s: %s\n", dylibPath, dlerror());
        return -1;
    }
    funcs->qemu_init = dlsym(dlctx, "qemu_init");
    funcs->qemu_main_loop = dlsym(dlctx, "qemu_main_loop");
    funcs->qemu_cleanup = dlsym(dlctx, "qemu_cleanup");
    if (funcs->qemu_init == NULL || funcs->qemu_main_loop == NULL || funcs->qemu_cleanup == NULL) {
        fprintf(stderr, "Error resolving %s: %s\n", dylibPath, dlerror());
        return -1;
    }
    return 0;
}

static void __attribute__((noreturn)) runQemu(qemu_main_t *funcs, int argc, const char **argv) {
    const char *envp[] = { NULL };
    funcs->qemu_init(argc, argv, envp);
    pthread_t thread;
    pthread_create(&thread, NULL, WatchForParentTermination, NULL);
    pthread_detach(thread);
    funcs->qemu_main_loop();
    funcs->qemu_cleanup();
    exit(0);
}

pid_t startQemuFork(const char *dylibPath, int argc, const char **argv, int newStdout, int newStderr) {
    qemu_main_t funcs = {};
    int res = loadQemu(dylibPath, &funcs);
    if (res < 0) {
        return res;
    }
    pid_t pid = fork();
    if (pid != 0) { // parent or error
        return pid;
    }
    // set up console output
    dup2(newStdout, STDOUT_FILENO);
    dup2(newStderr, STDERR_FILENO);
    close(newStdout);
    close(newStderr);
    // set thread QoS
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    // launch qemu
    runQemu(&funcs, argc, argv);
}

int startQemuProcess(const char *dylibPath, int argc, const char **argv) {
    qemu_main_t funcs = {};
    int res = loadQemu(dylibPath, &funcs);
    if (res < 0) {
        return res;
    }
    // launch qemu
    runQemu(&funcs, argc, argv);
    return 0;
}
