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
struct VMToolbarModifier: ViewModifier {
    @ObservedObject var vm: VMData
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
        toolbar(content)
        .modifier(VMShareItemModifier(isPresented: $showSharePopup, shareItem: shareItem))
        .modifier(VMConfirmActionModifier(confirmAction: $confirmAction) { action in
            if case .confirmMoveVM(let vm) = action {
                shareItem = .utmMove(vm)
                showSharePopup.toggle()
            }
        })
    }
}

// MARK: - Layouts

private extension VMToolbarModifier {
    /// Toolbar content cannot branch on availability before iOS 16, so the view does.
    @ViewBuilder
    func toolbar(_ content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27, *) {
            content.toolbar {
                prioritizedToolbarContent
            }
        } else {
            content.toolbar {
                groupedToolbarContent
            }
        }
        #else
        content.toolbar {
            #if os(visionOS)
            UTMPreferenceButtonToolbarContent()
            #endif
            groupedToolbarContent
        }
        #endif
    }

    /// One group with manual spacing, which is laid out as a single unit.
    var groupedToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: buttonPlacement) {
            #if !WITH_REMOTE // FIXME: implement remote feature
            deleteButton
                .padding(.leading, padding)
            groupSpacer
            cloneButton
                .padding(.leading, padding)
            groupSpacer
            #if os(macOS)
            if !vm.isShortcut {
                moveButton
                    .padding(.leading, padding)
            }
            #endif
            shareButton
                .padding(.leading, padding)
            groupSpacer
            #endif
            runStopButton
                .padding(.leading, padding)
            #if !WITH_REMOTE // FIXME: implement remote feature
            groupSpacer
            editButton
                .padding(.leading, padding)
            #endif
        }
    }

    @ViewBuilder
    var groupSpacer: some View {
        #if !os(macOS)
        if bottom {
            Spacer()
        }
        #endif
    }

    #if os(iOS)
    /// Separate items so that a bar too short for all of them drops the least important ones first.
    ///
    /// A vertical bar on the closed iPhone Duo overflows from the bottom, where Run and Stop sit.
    @available(iOS 27, *)
    @ToolbarContentBuilder
    var prioritizedToolbarContent: some ToolbarContent {
        #if !WITH_REMOTE // FIXME: implement remote feature
        ToolbarItem(placement: buttonPlacement) {
            deleteButton
        }
        if bottom {
            ToolbarSpacer(.flexible, placement: buttonPlacement)
        }
        ToolbarItem(placement: buttonPlacement) {
            cloneButton
        }.visibilityPriority(.low)
        if bottom {
            ToolbarSpacer(.flexible, placement: buttonPlacement)
        }
        ToolbarItem(placement: buttonPlacement) {
            shareButton
        }
        if bottom {
            ToolbarSpacer(.flexible, placement: buttonPlacement)
        }
        #endif
        ToolbarItem(placement: buttonPlacement) {
            runStopButton
        }.visibilityPriority(.high)
        #if !WITH_REMOTE // FIXME: implement remote feature
        if bottom {
            ToolbarSpacer(.flexible, placement: buttonPlacement)
        }
        ToolbarItem(placement: buttonPlacement) {
            editButton
        }
        #endif
    }
    #endif
}

// MARK: - Buttons

private extension VMToolbarModifier {
    #if !WITH_REMOTE
    @ViewBuilder
    var deleteButton: some View {
        if vm.isShortcut {
            DestructiveButton {
                confirmAction = .confirmDeleteVM(vm: vm)
            } label: {
                Label("Remove", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }.help("Remove selected shortcut")
            .disabled(!vm.isModifyAllowed)
        } else {
            DestructiveButton {
                confirmAction = .confirmDeleteVM(vm: vm)
            } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }.help("Delete selected VM")
            .disabled(!vm.isModifyAllowed)
        }
    }

    var cloneButton: some View {
        Button {
            confirmAction = .confirmCloneVM(vm: vm)
        } label: {
            Label("Clone", systemImage: "doc.on.doc")
                .labelStyle(.iconOnly)
        }.help("Clone selected VM")
    }

    #if os(macOS)
    var moveButton: some View {
        Button {
            confirmAction = .confirmMoveVM(vm: vm)
        } label: {
            Label("Move", systemImage: "arrow.down.doc")
                .labelStyle(.iconOnly)
        }.help("Move selected VM")
        .disabled(!vm.isModifyAllowed)
    }
    #endif

    var shareButton: some View {
        Button {
            shareItem = .utmCopy(vm)
            showSharePopup.toggle()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .labelStyle(.iconOnly)
        }.help("Share selected VM")
    }

    var editButton: some View {
        Button {
            data.close(vm: vm) // close window
            data.edit(vm: vm)
        } label: {
            Label("Edit", systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
        }.help("Edit selected VM")
        .disabled(vm.hasSuspendState || !vm.isModifyAllowed)
    }
    #endif

    @ViewBuilder
    var runStopButton: some View {
        if vm.hasSuspendState || !vm.isStopped {
            Button {
                confirmAction = .confirmStopVM(vm: vm)
            } label: {
                Label("Stop", systemImage: "stop")
                    .labelStyle(.iconOnly)
            }.help("Stop selected VM")
        } else {
            Button {
                data.run(vm: data.selectedVM!)
            } label: {
                Label("Run", systemImage: "play")
                    .labelStyle(.iconOnly)
            }.help("Run selected VM")
        }
    }
}

#if os(visionOS)
struct UTMPreferenceButtonToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            } label: {
                Label("Preferences", systemImage: "gear")
                    .labelStyle(.iconOnly)
            }.help("Show UTM preferences")
        }
    }
}
#endif
