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

#include <os/proc.h>
#include "TargetConditionals.h"
#include "UTMLegacyQemuConfiguration.h"
#include "UTMLegacyQemuConfiguration+Constants.h"
#include "UTMLegacyQemuConfiguration+Display.h"
#include "UTMLegacyQemuConfiguration+Drives.h"
#include "UTMLegacyQemuConfiguration+Miscellaneous.h"
#include "UTMLegacyQemuConfiguration+Networking.h"
#include "UTMLegacyQemuConfiguration+Sharing.h"
#include "UTMLegacyQemuConfiguration+System.h"
#include "UTMLegacyQemuConfigurationPortForward.h"
#include "UTMQcow2.h"
#include "UTMQemu.h"
#include "UTMQemuMonitor.h"
#include "UTMQemuMonitor+BlockDevices.h"
#include "UTMQemuSystem.h"
#include "UTMJailbreak.h"
#include "UTMLogging.h"
#include "UTMLegacyViewState.h"
#include "UTMVirtualMachine.h"
#include "UTMVirtualMachine-Protected.h"
#include "UTMQemuVirtualMachine.h"
#include "UTMQemuVirtualMachine-Protected.h"
#include "UTMQemuVirtualMachine+SPICE.h"
#include "UTMSpiceIO.h"
#if TARGET_OS_IPHONE
#include "UTMLocationManager.h"
#include "VMDisplayViewController.h"
#include "VMDisplayMetalViewController.h"
#include "VMDisplayMetalViewController+Keyboard.h"
#include "VMKeyboardButton.h"
#include "VMKeyboardView.h"
#elif TARGET_OS_OSX
typedef uint32_t CGSConnectionID;
typedef CF_ENUM(uint32_t, CGSGlobalHotKeyOperatingMode) {
    kCGSGlobalHotKeyOperatingModeEnable = 0,
    kCGSGlobalHotKeyOperatingModeDisable = 1,
};
extern CGSConnectionID CGSMainConnectionID(void);
extern CGError CGSSetGlobalHotKeyOperatingMode(CGSConnectionID connection, CGSGlobalHotKeyOperatingMode mode);
#endif
