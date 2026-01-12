//
// Copyright © 2022 osy. All rights reserved.
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

import Combine
import SwiftUI

@available(macOS 13, *)
struct UTMMenuBarExtraScene: Scene {
    @ObservedObject var data: UTMData
    @StateObject private var updateManager = UTMUpdateManager.shared
    @AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
    @AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra(isInserted: $isMenuIconShown) {
            
            Button(NSLocalizedString("Show UTM", comment: "UTMMenuBarExtraScene")) {
                openWindow(id: "home")
            }.keyboardShortcut("0")
            
            .help(NSLocalizedString("Show the main window.", comment: "UTMMenuBarExtraScene"))
            
            if updateManager.isUpdateAvailable {
                
                Button(String.localizedStringWithFormat(NSLocalizedString("Update Available: %@", comment: "UTMMenuBarExtraScene"), updateManager.latestVersion)) {
                    openWindow(id: "settings")
                }
                .foregroundColor(.accentColor)
                Divider()
            }
            
            
            Button(NSLocalizedString("Check for Updates", comment: "UTMMenuBarExtraScene")) {
                Task {
                    await updateManager.checkForUpdates(force: true)
                }
            }
            .disabled(updateManager.isCheckingForUpdates)
            
            
            Toggle(NSLocalizedString("Hide dock icon on next launch", comment: "UTMMenuBarExtraScene"), isOn: $isDockIconHidden)
            
            .help(NSLocalizedString("Requires restarting UTM to take affect.", comment: "UTMMenuBarExtraScene"))
            Divider()
            if data.virtualMachines.isEmpty {
                
                Text(NSLocalizedString("No virtual machines found.", comment: "UTMMenuBarExtraScene"))
            } else {
                ForEach(data.virtualMachines) { vm in
                    VMMenuItem(vm: vm).environmentObject(data)
                }
            }
            Divider()
            
            Button(NSLocalizedString("Quit", comment: "UTMMenuBarExtraScene")) {
                NSApp.terminate(self)
            }.keyboardShortcut("Q")
            
            .help(NSLocalizedString("Terminate UTM and stop all running VMs.", comment: "UTMMenuBarExtraScene"))
        } label: {
            ZStack {
                Image("MenuBarExtra")
                
                // Update indicator
                if updateManager.isUpdateAvailable {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

private struct VMMenuItem: View {
    @ObservedObject var vm: VMData
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Menu(vm.detailsTitleLabel) {
            if vm.isStopped {
                
                Button(NSLocalizedString("Start", comment: "UTMMenuBarExtraScene")) {
                    data.run(vm: vm)
                }
            } else if !vm.isBusy {
                
                Button(NSLocalizedString("Stop", comment: "UTMMenuBarExtraScene")) {
                    data.stop(vm: vm)
                }
                
                Button(NSLocalizedString("Suspend", comment: "UTMMenuBarExtraScene")) {
                    let isSnapshot = (vm.wrapped as? UTMQemuVirtualMachine)?.isRunningAsDisposible ?? false
                    vm.wrapped!.requestVmPause(save: !isSnapshot)
                }
                
                Button(NSLocalizedString("Reset", comment: "UTMMenuBarExtraScene")) {
                    vm.wrapped!.requestVmReset()
                }
            } else {
                
                Text(NSLocalizedString("Busy…", comment: "UTMMenuBarExtraScene"))
            }
        }
    }
}
