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

#ifndef UTMJailbreak_h
#define UTMJailbreak_h

#include <stdbool.h>

bool jb_has_jit_entitlement(void);
bool jb_has_usb_entitlement(void);
bool jb_has_cs_disabled(void);
bool jb_has_cs_execseg_allow_unsigned(void);
bool jb_enable_ptrace_hack(void);

#endif /* UTMJailbreak_h */
