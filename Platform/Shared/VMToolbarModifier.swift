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

// Lots of dirty hacks to work around SwiftUI bugs introduced in Beta 2
@available(iOS 14, macOS 11, *)
struct VMToolbarModifier: ViewModifier {
    @ObservedObject var vm: UTMVirtualMachine
    let bottom: Bool
    @State private var showSharePopup = false
    @State private var confirmAction: ConfirmAction?
    @EnvironmentObject private var data: UTMData
    @State private var shareItem: VMShareItemModifier.ShareItem?
    
    #if os(macOS)
    let buttonPlacement: ToolbarItemPlacement = .automatic
    let padding: CGFloat = 0
    #else
    var buttonPlacement: ToolbarItemPlacement {
        if bottom {
            return .bottomBar
        } else {
            return .navigationBarTrailing
        }
    }
    var padding: CGFloat {
        if bottom {
            return 0
        } else {
            return 10
        }
    }
    #endif
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: buttonPlacement) {
                if vm.isShortcut {
                    DestructiveButton {
                        confirmAction = .confirmDeleteShortcut
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }.help("Remove selected shortcut")
                    .disabled(vm.state != .vmStopped)
                    .padding(.leading, padding)
                } else {
                    DestructiveButton {
                        confirmAction = .confirmDeleteVM
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }.help("Delete selected VM")
                    .disabled(vm.state != .vmStopped)
                    .padding(.leading, padding)
                }
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                Button {
                    confirmAction = .confirmCloneVM
                } label: {
                    Label("Clone", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }.help("Clone selected VM")
                .padding(.leading, padding)
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                #if os(macOS)
                if !vm.isShortcut {
                    Button {
                        confirmAction = .confirmMoveVM
                    } label: {
                        Label("Move", systemImage: "arrow.down.doc")
                            .labelStyle(.iconOnly)
                    }.help("Move selected VM")
                    .disabled(vm.state != .vmStopped)
                    .padding(.leading, padding)
                }
                #endif
                Button {
                    shareItem = .utmCopy(vm)
                    showSharePopup.toggle()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }.help("Share selected VM")
                .padding(.leading, padding)
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                if vm.viewState.hasSaveState || vm.state != .vmStopped {
                    Button {
                        confirmAction = .confirmStopVM
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.iconOnly)
                    }.help("Stop selected VM")
                    .padding(.leading, padding)
                } else {
                    Button {
                        data.run(vm: data.selectedVM!)
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    }.help("Run selected VM")
                    .padding(.leading, padding)
                }
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                Button {
                    data.close(vm: vm) // close window
                    data.edit(vm: vm)
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }.help("Edit selected VM")
                .disabled(vm.viewState.hasSaveState || vm.state != .vmStopped)
                .padding(.leading, padding)
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
