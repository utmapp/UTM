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

#include "TargetConditionals.h"
#include "UTMConfigurable.h"
#include "UTMQemuConfiguration.h"
#include "UTMQemuConfiguration+Constants.h"
#include "UTMQemuConfiguration+Defaults.h"
#include "UTMQemuConfiguration+Display.h"
#include "UTMQemuConfiguration+Drives.h"
#include "UTMQemuConfiguration+Miscellaneous.h"
#include "UTMQemuConfiguration+Networking.h"
#include "UTMQemuConfiguration+Sharing.h"
#include "UTMQemuConfiguration+System.h"
#include "UTMQemuConfigurationPortForward.h"
#include "UTMDrive.h"
#include "UTMQcow2.h"
#include "UTMQemu.h"
#include "UTMQemuSystem.h"
#include "UTMJailbreak.h"
#include "UTMLogging.h"
#include "UTMViewState.h"
#include "UTMVirtualMachine.h"
#include "UTMVirtualMachine+IO.h"
#include "UTMQemuVirtualMachine.h"
#include "UTMQemuVirtualMachine+Drives.h"
#include "UTMQemuVirtualMachine+SPICE.h"
#include "UTMQemuVirtualMachine+Terminal.h"
#include "UTMRenderer.h"
#include "UTMScreenshot.h"
#include "UTMSpiceIO.h"
#include "UTMTerminal.h"
#include "UTMTerminalDelegate.h"
#include "CocoaSpice.h"
#if TARGET_OS_IPHONE
#include "AppDelegate.h"
#include "UIViewController+Extensions.h"
#include "UTMLocationManager.h"
#include "VMDisplayViewController.h"
#include "VMDisplayMetalViewController.h"
#include "VMDisplayMetalViewController+Keyboard.h"
#include "VMDisplayTerminalViewController.h"
#include "VMKeyboardButton.h"
#include "VMKeyboardView.h"
#endif
