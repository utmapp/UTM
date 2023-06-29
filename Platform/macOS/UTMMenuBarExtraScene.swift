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
    @AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
    @AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra(isInserted: $isMenuIconShown) {
            Button("Show UTM") {
                openWindow(id: "home")
            }.keyboardShortcut("0")
            .help("Show the main window.")
            Toggle("Hide dock icon on next launch", isOn: $isDockIconHidden)
            .help("Requires restarting UTM to take affect.")
            Divider()
            if data.virtualMachines.isEmpty {
                Text("No virtual machines found.")
            } else {
                ForEach(data.virtualMachines) { vm in
                    VMMenuItem(vm: vm).environmentObject(data)
                }
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(self)
            }.keyboardShortcut("Q")
            .help("Terminate UTM and stop all running VMs.")
        } label: {
            Image("MenuBarExtra")
        }
    }
}

private struct VMMenuItem: View {
    @ObservedObject var vm: VMData
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Menu(vm.detailsTitleLabel) {
            if vm.isStopped {
                Button("Start") {
                    data.run(vm: vm)
                }
            } else if !vm.isBusy {
                Button("Stop") {
                    data.stop(vm: vm)
                }
                Button("Suspend") {
                    let isSnapshot = (vm.wrapped as? UTMQemuVirtualMachine)?.isRunningAsDisposible ?? false
                    vm.wrapped!.requestVmPause(save: !isSnapshot)
                }
                Button("Reset") {
                    vm.wrapped!.requestVmReset()
                }
            } else {
                Text("Busy…")
            }
        }
    }
}
