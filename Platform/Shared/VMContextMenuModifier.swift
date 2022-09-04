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

import SwiftUI

struct VMContextMenuModifier: ViewModifier {
    @ObservedObject var vm: UTMVirtualMachine
    @EnvironmentObject private var data: UTMData
    @State private var showSharePopup = false
    @State private var confirmAction: ConfirmAction?
    @State private var shareItem: VMShareItemModifier.ShareItem?
    
    func body(content: Content) -> some View {
        content.contextMenu {
            #if os(macOS)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([vm.path])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }.help("Reveal where the VM is stored.")
            Divider()
            #endif
            Button {
                data.close(vm: vm) // close window
                data.edit(vm: vm)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }.disabled(vm.hasSaveState || vm.state != .vmStopped)
            .help("Modify settings for this VM.")
            if vm.hasSaveState || vm.state != .vmStopped {
                Button {
                    confirmAction = .confirmStopVM
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }.help("Stop the running VM.")
            } else {
                Divider()
                
                Button {
                    data.run(vm: vm)
                } label: {
                    Label("Run", systemImage: "play.fill")
                }.help("Run the VM in the foreground.")
                
                #if os(macOS) && arch(arm64)
                if #available(macOS 13, *), let appleConfig = vm.config.appleConfig, appleConfig.system.boot.operatingSystem == .macOS {
                    Button {
                        appleConfig.system.boot.startUpFromMacOSRecovery = true
                        data.run(vm: vm)
                    } label: {
                        Label("Run Recovery", systemImage: "play.fill")
                    }.help("Boot into recovery mode.")
                }
                #endif
                
                if !vm.config.isAppleVirtualization {
                    Button {
                        vm.isRunningAsSnapshot = true
                        data.run(vm: vm)
                    } label: {
                        Label("Run without saving changes", systemImage: "play")
                    }.help("Run the VM in the foreground, without saving data changes to disk.")
                }
                
                #if os(iOS)
                if let qemuVM = vm as? UTMQemuVirtualMachine {
                    Button {
                        qemuVM.isGuestToolsInstallRequested = true
                    } label: {
                        Label("Install Windows Guest Tools…", systemImage: "wrench.and.screwdriver")
                    }.help("Download and mount the guest tools for Windows.")
                    .disabled(qemuVM.isGuestToolsInstallRequested)
                }
                #endif
                
                Divider()
            }
            Button {
                shareItem = .utmCopy(vm)
                showSharePopup.toggle()
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }.help("Share a copy of this VM and all its data.")
            #if os(macOS)
            if !vm.isShortcut {
                Button {
                    confirmAction = .confirmMoveVM
                } label: {
                    Label("Move…", systemImage: "arrow.down.doc")
                }.disabled(vm.state != .vmStopped)
                .help("Move this VM from internal storage to elsewhere.")
            }
            #endif
            Button {
                confirmAction = .confirmCloneVM
            } label: {
                Label("Clone…", systemImage: "doc.on.doc")
            }.help("Duplicate this VM along with all its data.")
            Button {
                data.busyWorkAsync {
                    try await data.template(vm: vm)
                }
            } label: {
                Label("New from template…", systemImage: "doc.on.clipboard")
            }.help("Create a new VM with the same configuration as this one but without any data.")
            Divider()
            if vm.isShortcut {
                DestructiveButton {
                    confirmAction = .confirmDeleteShortcut
                } label: {
                    Label("Remove", systemImage: "trash")
                }.disabled(vm.state != .vmStopped)
                .help("Delete this shortcut. The underlying data will not be deleted.")
            } else {
                DestructiveButton {
                    confirmAction = .confirmDeleteVM
                } label: {
                    Label("Delete", systemImage: "trash")
                }.disabled(vm.state != .vmStopped)
                .help("Delete this VM and all its data.")
            }
        }
        .modifier(VMShareItemModifier(isPresented: $showSharePopup, shareItem: shareItem))
        .modifier(VMConfirmActionModifier(vm: vm, confirmAction: $confirmAction) {
            if confirmAction == .confirmMoveVM {
                shareItem = .utmMove(vm)
                showSharePopup.toggle()
            }
        })
        .onChange(of: (vm as? UTMQemuVirtualMachine)?.isGuestToolsInstallRequested) { newValue in
            if newValue == true {
                data.busyWorkAsync {
                    try await data.mountSupportTools(for: vm as! UTMQemuVirtualMachine)
                }
            }
        }
    }
}
