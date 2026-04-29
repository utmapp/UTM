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

import SwiftUI
import TipKit

struct VMNavigationListView: View {
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            CompatibleNavigationSplitView {
                List(selection: $data.selectedSidebarItem) {
                    listBody
                }.modifier(VMListModifier())
            } detail: {
                if let vm = data.selectedVM {
                    VMDetailsView(vm: vm)
                } else {
                    VMPlaceholderView()
                    #if os(visionOS)
                        .toolbar {
                            UTMPreferenceButtonToolbarContent()
                        }
                    #endif
                }
            }.navigationSplitViewStyle(.balanced)
        } else {
            NavigationView {
                List {
                    listBody
                }.modifier(VMListModifier())
                VMPlaceholderView()
            }
        }
    }
    
    @ViewBuilder private var listBody: some View {
        ForEach(data.sidebarItems, id: \.id) { item in
            switch item {
            case .vm(let vmID):
                if let vm = data.vm(for: vmID) {
                    vmRow(vm: vm)
                }
            case .group(let groupID):
                if let group = data.group(for: groupID) {
                    groupHeaderRow(group)
                    if group.isExpanded {
                        ForEach(data.virtualMachines(inGroup: group.id)) { vm in
                            vmRow(vm: vm)
                                .padding(.leading, 18)
                        }.onMove { fromOffsets, toOffset in
                            moveInGroup(groupID: group.id, fromOffsets: fromOffsets, toOffset: toOffset)
                        }
                    }
                }
            }
        }.onMove(perform: move)
        #if !WITH_REMOTE // FIXME: implement remote feature
        .onDelete(perform: delete)
        #endif

        if data.pendingVMs.count > 0 {
            Section(header: Text("Pending")) {
                ForEach(data.pendingVMs, id: \.name) { vm in
                    UTMPendingVMView(vm: vm)
                }.onDelete(perform: cancel)
            }.transition(.opacity)
        }
    }
    
    private func move(fromOffsets: IndexSet, toOffset: Int) {
        data.moveSidebarItems(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    private func moveInGroup(groupID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        data.moveVMs(inGroup: groupID, fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    private func delete(indexSet: IndexSet) {
        for index in indexSet {
            guard index < data.sidebarItems.count else {
                continue
            }
            switch data.sidebarItems[index] {
            case .vm(let vmID):
                guard let vm = data.vm(for: vmID) else {
                    continue
                }
                data.busyWorkAsync {
                    try await data.delete(vm: vm)
                }
            case .group(let groupID):
                data.deleteGroup(id: groupID)
            }
        }
    }
    
    private func cancel(indexSet: IndexSet) {
        let selected = data.pendingVMs[indexSet]
        for vm in selected {
            data.cancelDownload(for: vm)
        }
    }
    
    @ViewBuilder private func vmRow(vm: VMData) -> some View {
        if !vm.isLoaded {
            UTMUnavailableVMView(vm: vm)
        } else {
            if #available(iOS 16, macOS 13, visionOS 1, *) {
                VMCardView(vm: vm)
                    .modifier(VMContextMenuModifier(vm: vm))
                    .tag(VMSidebarSelection.vm(vm.id))
            } else {
                NavigationLink(
                    destination: VMDetailsView(vm: vm),
                    tag: VMSidebarSelection.vm(vm.id),
                    selection: $data.selectedSidebarItem,
                    label: { VMCardView(vm: vm) })
                .modifier(VMContextMenuModifier(vm: vm))
            }
        }
    }
    
    @ViewBuilder private func groupHeaderRow(_ group: VMGroup) -> some View {
        VMGroupRow(group: group) {
            data.toggleGroupExpanded(id: group.id)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(group.isExpanded ? "Collapse" : "Expand") {
                data.toggleGroupExpanded(id: group.id)
            }
            Button("Rename Group…") {
                data.requestRenameGroup(id: group.id)
            }
            DestructiveButton {
                data.deleteGroup(id: group.id)
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
private struct CompatibleNavigationSplitView<Sidebar, Detail> : View where Sidebar : View, Detail : View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    let sidebar: () -> Sidebar
    let detail: () -> Detail

    init(@ViewBuilder sidebar: @escaping () -> Sidebar, @ViewBuilder detail: @escaping () -> Detail) {
        self.sidebar = sidebar
        self.detail = detail
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, sidebar: sidebar, detail: detail)
    }
}

private struct VMListModifier: ViewModifier {
    @EnvironmentObject private var data: UTMData
    @State private var settingsPresented = false
    @State private var sheetPresented = false
    @State private var donatePresented = false

    private let _donateTip: Any?
    private let _createTip: Any?

    @available(iOS 17, macOS 14, *)
    private var donateTip: UTMTipDonate {
        _donateTip as! UTMTipDonate
    }

    @available(iOS 17, macOS 14, *)
    private var createTip: UTMTipCreateVM {
        _createTip as! UTMTipCreateVM
    }

    init() {
        if #available(iOS 17, macOS 14, *) {
            _donateTip = UTMTipDonate()
            _createTip = UTMTipCreateVM()
        } else {
            _donateTip = nil
            _createTip = nil
        }
    }

    func body(content: Content) -> some View {
        content
        #if os(macOS)
        .frame(minWidth: 250, idealWidth: 350)
        #endif
        .listStyle(.sidebar)
        .navigationTitle(productName)
        #if os(macOS)
        .navigationSubtitle(data.selectedVM?.detailsTitleLabel ?? "")
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                newButton
            }
            ToolbarItem(placement: .navigation) {
                createGroupButton
            }
            #else
            #if !WITH_REMOTE // FIXME: implement remote feature
            ToolbarItem(placement: .navigationBarLeading) {
                if #available(iOS 17, visionOS 99, *) {
                    Button {
                        createTip.invalidate(reason: .actionPerformed)
                        data.newVM()
                    } label: {
                        Image(systemName: "plus") // SwiftUI bug: tip won't show up if this is a label
                    }.help("Create a new VM")
                    .popoverTip(createTip, arrowEdge: .top)
                } else {
                    newButton
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                createGroupButton
            }
            #endif
            #if !WITH_REMOTE
            ToolbarItem(placement: .navigationBarLeading) {
                if #available(iOS 17, visionOS 99, *) {
                    Button {
                        donateTip.invalidate(reason: .actionPerformed)
                        donatePresented.toggle()
                    } label: {
                        Image(systemName: "heart.fill") // SwiftUI bug: tip won't show up if this is a label
                    }.popoverTip(donateTip, arrowEdge: .top) { action in
                        donateTip.invalidate(reason: .actionPerformed)
                        if action.id == "donate" {
                            donatePresented.toggle()
                        }
                    }
                } else {
                    Button {
                        donatePresented.toggle()
                    } label: {
                        Label("Donate", systemImage: "heart.fill")
                    }
                }
            }
            #endif
            #if !os(visionOS) && !WITH_REMOTE
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    settingsPresented.toggle()
                }
            }
            #endif
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
        #if os(macOS)
        .onMoveCommand(perform: handleMoveCommand)
        #endif
        #if os(iOS)
        // SwiftUI bug on iOS 14.4 and previous versions prevents multiple .sheet from working
        .sheet(isPresented: $sheetPresented) {
            if data.showNewVMSheet {
                VMWizardView()
            } else if data.showGroupEditorSheet {
                VMGroupEditorSheet()
            } else if settingsPresented {
                #if !WITH_REMOTE
                UTMSettingsView()
                #endif
            } else if donatePresented {
                #if !os(macOS) && !WITH_REMOTE
                UTMDonateView()
                #endif
            }
        }
        .onChange(of: data.showNewVMSheet) { newValue in
            if newValue {
                settingsPresented = false
                donatePresented = false
                sheetPresented = true
            }
        }
        .onChange(of: settingsPresented) { newValue in
            if newValue {
                data.showNewVMSheet = false
                data.showGroupEditorSheet = false
                donatePresented = false
                sheetPresented = true
            }
        }
        .onChange(of: data.showGroupEditorSheet) { newValue in
            if newValue && !supportsGroupEditorAlert {
                data.showNewVMSheet = false
                settingsPresented = false
                donatePresented = false
                sheetPresented = true
            }
        }
        .onChange(of: donatePresented) { newValue in
            if newValue {
                data.showNewVMSheet = false
                data.showGroupEditorSheet = false
                settingsPresented = false
                sheetPresented = true
            }
        }
        .onChange(of: sheetPresented) { newValue in
            if !newValue {
                settingsPresented = false
                donatePresented = false
                data.showNewVMSheet = false
                if !supportsGroupEditorAlert {
                    data.showGroupEditorSheet = false
                }
            }
        }
        .modifier(GroupEditorAlertCompatModifier(
            isPresented: groupEditorAlertBinding,
            title: isEditingGroup ? "Rename Group" : "New Group",
            text: $data.groupEditorTitle,
            onCancel: { data.cancelGroupEditorChanges() },
            onSave: { data.commitGroupEditorChanges() }
        ))
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            sheetPresented = false
        }
        #else
        .sheet(isPresented: $data.showNewVMSheet) {
            VMWizardView()
        }
        .sheet(isPresented: $data.showGroupEditorSheet) {
            VMGroupEditorSheet()
        }
        #if !os(macOS) && !WITH_REMOTE
        .sheet(isPresented: $donatePresented) {
            UTMDonateView()
        }
        #endif
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            data.showNewVMSheet = false
        }
        #endif
    }
    
    private var newButton: some View {
        Button(action: { data.newVM() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(.iconOnly)
        }).help("Create a new VM")
    }
    
    private var createGroupButton: some View {
        Button(action: { data.requestCreateGroup() }, label: {
            Label("New Group", systemImage: "folder.badge.plus").labelStyle(.iconOnly)
        }).help("Create a new group")
    }
    
    #if os(iOS)
    private var supportsGroupEditorAlert: Bool {
        if #available(iOS 15, *) {
            return true
        } else {
            return false
        }
    }
    
    private var isEditingGroup: Bool {
        data.editingGroupID != nil
    }
    
    private var groupEditorAlertBinding: Binding<Bool> {
        Binding {
            supportsGroupEditorAlert && data.showGroupEditorSheet
        } set: { newValue in
            if !newValue {
                data.cancelGroupEditorChanges()
            } else {
                data.showGroupEditorSheet = true
            }
        }
    }
    #endif
    
    #if os(macOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard case .group(let groupID) = data.selectedSidebarItem else {
            return
        }
        if direction == .left {
            data.collapseGroup(id: groupID)
        } else if direction == .right {
            data.expandGroup(id: groupID)
        }
    }
    #endif
}

#if os(iOS)
private struct GroupEditorAlertCompatModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void
    
    func body(content: Content) -> some View {
        if #available(iOS 15, *) {
            content.alert(title, isPresented: $isPresented) {
                TextField("Group Name", text: $text)
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a group name.")
            }
        } else {
            content
        }
    }
}
#endif

private struct VMGroupRow: View {
    let group: VMGroup
    let toggleExpand: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleExpand) {
                Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.trailing, 2)
            Text(group.title)
                .font(.headline)
            Spacer()
        }
        .padding([.top, .bottom], 10)
        .accessibilityLabel(group.title)
        .accessibilityValue(group.isExpanded ? Text("Expanded") : Text("Collapsed"))
    }
}

private struct VMGroupEditorSheet: View {
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode
    
    private var isEditing: Bool {
        data.editingGroupID != nil
    }
    
    private var isSaveDisabled: Bool {
        data.groupEditorTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "Rename Group" : "New Group")
                .font(.headline)
            TextField("Group Name", text: $data.groupEditorTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    data.cancelGroupEditorChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Save") {
                    data.commitGroupEditorChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 460)
        #elseif os(iOS)
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "Rename Group" : "New Group")
                .font(.headline)
            TextField("Group Name", text: $data.groupEditorTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    data.cancelGroupEditorChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Save") {
                    data.commitGroupEditorChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        #else
        NavigationView {
            Form {
                Section {
                    TextField("Group Name", text: $data.groupEditorTitle)
                }
            }
            .navigationTitle(isEditing ? "Rename Group" : "New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        data.cancelGroupEditorChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        data.commitGroupEditorChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        #endif
    }
}
