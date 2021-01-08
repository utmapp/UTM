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
#include <stdio.h>
#include <stdlib.h>

static int launchQemu(const char *dylibPath, int argc, const char **argv) {
    void *dlctx;
    int (*qemu_init)(int, const char *[], const char *[]);
    void (*qemu_main_loop)(void);
    void (*qemu_cleanup)(void);
    
    if ((dlctx = dlopen(dylibPath, RTLD_LAZY | RTLD_FIRST)) == NULL) {
        fprintf(stderr, "Error loading %s: %s\n", dylibPath, dlerror());
        return -1;
    }
    qemu_init = dlsym(dlctx, "qemu_init");
    qemu_main_loop = dlsym(dlctx, "qemu_main_loop");
    qemu_cleanup = dlsym(dlctx, "qemu_cleanup");
    if (qemu_init == NULL || qemu_main_loop == NULL || qemu_cleanup == NULL) {
        fprintf(stderr, "Error resolving %s: %s\n", dylibPath, dlerror());
        return -1;
    }
    const char *envp[] = { NULL };
    qemu_init(argc, argv, envp);
    qemu_main_loop();
    qemu_cleanup();
    return 0;
}

pid_t startQemu(const char *dylibPath, int argc, const char **argv, int newStdout, int newStderr) {
    pid_t pid = fork();
    if (pid != 0) { // parent or error
        return pid;
    }
    // set up console output
    dup2(newStdout, STDOUT_FILENO);
    dup2(newStderr, STDERR_FILENO);
    close(newStdout);
    close(newStderr);
    int res = launchQemu(dylibPath, argc, argv);
    exit(res);
}
