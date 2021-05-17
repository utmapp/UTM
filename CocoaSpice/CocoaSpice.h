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

#ifndef CocoaSpice_h
#define CocoaSpice_h

#include "CSConnection.h"
#include "CSDisplayMetal.h"
#include "CSInput.h"
#include "CSMain.h"
#include "CSSession.h"
#include "CSSession+Sharing.h"
#include "CSUSBDevice.h"
#include "CSUSBManager.h"

#define GLIB_OBJC_RETAIN(x) (__bridge_retained void *)(x)
#define GLIB_OBJC_RELEASE(x) (__bridge void *)(__bridge_transfer NSObject *)(__bridge void *)(x)

#define DISPLAY_DEBUG(display, fmt, ...) \
    SPICE_DEBUG(fmt, \
        ## __VA_ARGS__)

#endif /* CocoaSpice_h */
