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

#ifndef ptrace_h
#define ptrace_h

int ptrace(int request, pid_t pid, caddr_t addr, int data);

#ifndef PTRACE_TRACEME
#define PTRACE_TRACEME 0
#endif

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

#endif /* ptrace_h */
