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

@available(iOS 14, macOS 11, *)
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
                NSWorkspace.shared.activateFileViewerSelecting([vm.path!])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            Divider()
            #endif
            Button {
                data.edit(vm: vm)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }.disabled(vm.viewState.hasSaveState || vm.state != .vmStopped)
            if vm.viewState.hasSaveState || vm.state != .vmStopped {
                Button {
                    confirmAction = .confirmStopVM
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    data.run(vm: vm)
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
            }
            Button {
                shareItem = .utmCopy(vm)
                showSharePopup.toggle()
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
            #if os(macOS)
            if !vm.isShortcut {
                Button {
                    confirmAction = .confirmMoveVM
                } label: {
                    Label("Move…", systemImage: "arrow.down.doc")
                }.disabled(vm.state != .vmStopped)
            }
            #endif
            Button {
                confirmAction = .confirmCloneVM
            } label: {
                Label("Clone…", systemImage: "doc.on.doc")
            }
            Divider()
            if vm.isShortcut {
                DestructiveButton {
                    confirmAction = .confirmDeleteShortcut
                } label: {
                    Label("Remove", systemImage: "trash")
                }.disabled(vm.state != .vmStopped)
            } else {
                DestructiveButton {
                    confirmAction = .confirmDeleteVM
                } label: {
                    Label("Delete", systemImage: "trash")
                }.disabled(vm.state != .vmStopped)
            }
        }
        .modifier(VMShareItemModifier(isPresented: $showSharePopup, shareItem: shareItem))
        .modifier(VMConfirmActionModifier(vm: vm, confirmAction: $confirmAction) {
            if confirmAction == .confirmMoveVM {
                shareItem = .utmMove(vm)
                showSharePopup.toggle()
            }
        })
    }
}
