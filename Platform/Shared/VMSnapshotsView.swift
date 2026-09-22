//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

/// Timeline of the current state followed by every saved snapshot, newest first.
///
/// Designed to be placed inside a parent scroll view. `scrollTo` is called with the
/// identifier of a row that should be made visible.
struct VMSnapshotsView: View {
    @ObservedObject var vm: VMData
    var scrollTo: (UUID) -> Void = { _ in }

    var body: some View {
        SnapshotTimeline(vm: vm, list: VMSnapshotList.list(for: vm), scrollTo: scrollTo)
            .id(vm.id)
    }
}

// MARK: - Timeline

private struct SnapshotTimeline: View {
    @ObservedObject var vm: VMData
    @ObservedObject var list: VMSnapshotList
    let scrollTo: (UUID) -> Void
    @EnvironmentObject private var data: UTMData

    /// Focused snapshot, `nil` focuses the current state
    @State private var selectedID: UUID?
    @State private var renamingID: UUID?
    @State private var confirmation: Confirmation?
    /// Keyboard commands go to the selected snapshot while this is set
    @FocusState private var isTimelineFocused: Bool

    /// Asked before anything that cannot be taken back
    private enum Confirmation: Equatable {
        case delete(UUID)
        /// The current state is replaced by the snapshot
        case restore(UUID)
        /// The snapshot the current state is based on is replaced by the current state
        case overwriteBase
        case deleteSuspendState

        /// Snapshot it is about, `nil` if it is about the current state
        var id: UUID? {
            switch self {
            case .delete(let id), .restore(let id): return id
            case .overwriteBase, .deleteSuspendState: return nil
            }
        }
    }

    /// Snapshot the current state started out from, if it still exists
    private var baseSnapshot: VMSnapshot? {
        list.snapshot(for: list.currentParentID)
    }

    /// The suspended state can be deleted whether the VM is running or not, just not in between
    private var isReady: Bool {
        vm.state == .stopped || vm.state == .started || vm.state == .paused
    }

    /// Measured because a regular size class can still be narrow, such as next to the sidebar
    @State private var width: CGFloat?

    #if os(macOS)
    private let minimumRegularWidth: CGFloat = 520
    private let isCompactSizeClass: Bool = false
    #else
    private let minimumRegularWidth: CGFloat = 660
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?

    private var isCompactSizeClass: Bool {
        horizontalSizeClass == .compact
    }
    #endif

    /// Row actions move below the text when there is no room to keep them on the trailing edge
    private var isCompact: Bool {
        if let width = width {
            return width < minimumRegularWidth
        } else {
            return isCompactSizeClass
        }
    }

    /// How a row ties into the rail drawn along the leading edge.
    private struct Link {
        /// Parent is the next row so the rail continues into it
        var connectsDown: Bool = false
        /// Previous row is a child so the rail arrives from it
        var connectsUp: Bool = false
        /// Parent that is somewhere else in the list
        var distantParent: VMSnapshot?
        var isInLineage: Bool = false
        var isUpInLineage: Bool = false
    }

    /// Links for the current state (first) followed by each snapshot.
    private var links: [Link] {
        let snapshots = list.snapshots
        let lineage = list.lineage(from: selectedID ?? list.currentParentID)
        let parents = [list.currentParentID] + snapshots.map { $0.parentID }
        let ids = [nil] + snapshots.map { Optional($0.id) }
        var links = [Link](repeating: Link(), count: ids.count)
        for index in links.indices {
            if let id = ids[index] {
                links[index].isInLineage = lineage.contains(id)
            } else {
                links[index].isInLineage = selectedID == nil
            }
            guard let parentID = parents[index] else {
                continue
            }
            if index + 1 < ids.count && ids[index + 1] == parentID {
                links[index].connectsDown = true
                links[index + 1].connectsUp = true
                links[index + 1].isUpInLineage = links[index].isInLineage
            } else {
                links[index].distantParent = list.snapshot(for: parentID)
            }
        }
        return links
    }

    var body: some View {
        let links = links
        VStack(alignment: .leading, spacing: 0) {
            SnapshotRow(isCompact: isCompact,
                        isFocused: selectedID == nil,
                        isSelected: false,
                        rail: rail(for: links[0], hasState: nil),
                        distantParent: links[0].distantParent,
                        onSelect: { select(nil) },
                        onSelectParent: selectParent) {
                SnapshotThumbnail(image: vm.screenshotImage, isCompact: isCompact)
            } title: {
                Text("Current State")
                    .font(.headline)
            } details: {
                Text(currentStatus)
            } actions: {
                currentActions
            }
            .confirmationDialog("Confirm", isPresented: isConfirming(nil), presenting: confirmation) { confirmation in
                Button("Cancel", role: .cancel) {}
                switch confirmation {
                case .overwriteBase:
                    Button("Overwrite", role: .destructive) {
                        overwriteBase()
                    }
                case .deleteSuspendState:
                    Button("Delete", role: .destructive) {
                        deleteSuspendState()
                    }
                case .delete(_), .restore(_):
                    EmptyView()
                }
            } message: { confirmation in
                switch confirmation {
                case .overwriteBase:
                    Text("Do you want to overwrite the snapshot “\(baseSnapshot?.title ?? "")” with the current state of the virtual machine? What it holds now will be lost.")
                case .deleteSuspendState:
                    Text("Do you want to delete the suspended state? The virtual machine will start up normally and all unsaved data will be lost.")
                case .delete(_), .restore(_):
                    EmptyView()
                }
            }
            if list.snapshots.isEmpty {
                emptyPlaceholder
            } else {
                // the rail is drawn by the rows so it is not interrupted by the separator
                Divider()
                    .padding(.leading, SnapshotRail.width)
                    .padding(.vertical, 6)
                    .background(alignment: .leading) {
                        if links[0].connectsDown {
                            SnapshotRail.Segment(style: links[0].isInLineage ? .lineage : .normal)
                                .frame(width: SnapshotRail.width)
                        }
                    }
            }
            ForEach(Array(zip(list.snapshots, links.dropFirst())), id: \.0.id) { snapshot, link in
                SnapshotRow(isCompact: isCompact,
                            isFocused: selectedID == snapshot.id,
                            isSelected: selectedID == snapshot.id,
                            rail: rail(for: link, hasState: snapshot.hasState),
                            distantParent: link.distantParent,
                            onSelect: { select(selectedID == snapshot.id ? nil : snapshot.id) },
                            onSelectParent: selectParent) {
                    SnapshotThumbnail(image: snapshot.screenshot, isCompact: isCompact)
                } title: {
                    HStack(alignment: .firstTextBaseline) {
                        SnapshotTitle(title: snapshot.title, isEditing: renamingID == snapshot.id) { title in
                            if let title = title {
                                perform {
                                    try await list.rename(snapshot, to: title)
                                }
                            }
                            renamingID = nil
                            isTimelineFocused = selectedID != nil
                        }
                        if isCompact && snapshot.size > 0 {
                            Spacer(minLength: 8)
                            SnapshotDetails.size(of: snapshot)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .layoutPriority(1)
                        }
                    }
                } details: {
                    if snapshot.isOrphaned {
                        Label("The data of this snapshot is missing.", systemImage: "exclamationmark.triangle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundColor(.orange)
                    } else if snapshot.isIncomplete {
                        Label("This snapshot does not cover every drive.", systemImage: "exclamationmark.triangle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundColor(.orange)
                    }
                    SnapshotDetails(snapshot: snapshot, isCompact: isCompact)
                } actions: {
                    actions(for: snapshot)
                }
                .contextMenu {
                    menuActions(for: snapshot)
                }
                .confirmationDialog("Confirm", isPresented: isConfirming(snapshot.id), presenting: confirmation) { confirmation in
                    Button("Cancel", role: .cancel) {}
                    switch confirmation {
                    case .delete(_):
                        Button("Delete", role: .destructive) {
                            delete(snapshot)
                        }
                    case .restore(_):
                        Button("Restore", role: .destructive) {
                            restore(snapshot)
                        }
                    case .overwriteBase, .deleteSuspendState:
                        EmptyView()
                    }
                } message: { confirmation in
                    switch confirmation {
                    case .delete(_):
                        Text("Do you want to delete the snapshot “\(snapshot.title)” and all its data?")
                    case .restore(_):
                        Text("Do you want to restore the snapshot “\(snapshot.title)”? The current state of the virtual machine will be overwritten and any changes that are not saved as a snapshot will be lost.")
                    case .overwriteBase, .deleteSuspendState:
                        EmptyView()
                    }
                }
                .id(snapshot.id)
            }
        }
        .background(GeometryReader { geometry in
            Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
        })
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            self.width = width
        }
        .task(id: vm.state) {
            // snapshots can only change while the VM does something
            try? await list.refresh()
        }
        #if os(macOS)
        .modifier(SnapshotKeyboardCommands(isFocused: $isTimelineFocused) {
            if let snapshot = list.snapshot(for: selectedID), snapshot.canDelete {
                confirmation = .delete(snapshot.id)
            }
        } onExit: {
            select(nil)
        })
        #endif
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 4) {
            Text("No Snapshots")
                .font(.headline)
            Text("Save the current state of the virtual machine as a snapshot to return to it later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }.foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var currentStatus: String {
        if !vm.isStopped || vm.state == .paused {
            return vm.stateLabel
        } else if vm.hasSuspendState {
            return NSLocalizedString("Suspended", comment: "VMSnapshotsView")
        } else {
            return NSLocalizedString("Not running", comment: "VMSnapshotsView")
        }
    }

    /// - Parameter hasState: Whether the snapshot holds the running machine, `nil` for the current state
    private func rail(for link: Link, hasState: Bool?) -> SnapshotRail {
        SnapshotRail(marker: hasState.map { SnapshotRail.Marker.snapshot(hasState: $0) } ?? .current,
                     isInLineage: link.isInLineage,
                     up: link.connectsUp ? (link.isUpInLineage ? .lineage : .normal) : nil,
                     down: link.connectsDown ? (link.isInLineage ? .lineage : .normal) : nil,
                     hasDistantParent: link.distantParent != nil)
    }

    // MARK: Actions

    /// The current state can be kept as a snapshot unless it already is one. Running the VM is
    /// left to the rest of the window.
    @ViewBuilder private var currentActions: some View {
        if vm.hasSuspendState {
            DestructiveButton {
                confirmation = .deleteSuspendState
            } label: {
                Label("Delete", systemImage: "trash")
            }.help("Delete the suspended state so the virtual machine starts up normally")
            .disabled(!isReady)
        }
        if !list.isCurrentStateSaved {
            if let baseSnapshot = baseSnapshot {
                Button {
                    confirmation = .overwriteBase
                } label: {
                    Label("Overwrite", systemImage: "square.and.arrow.down")
                }.help("Replace the snapshot “\(baseSnapshot.title)” with the current state")
                .disabled(!list.canOverwriteBase)
            }
            Button {
                createSnapshot()
            } label: {
                Label("New", systemImage: "plus")
            }.help("Save the current state as a new snapshot")
            .buttonStyle(.borderedProminent)
            .disabled(!list.canCreate)
        }
    }

    @ViewBuilder private func actions(for snapshot: VMSnapshot) -> some View {
        DestructiveButton {
            confirmation = .delete(snapshot.id)
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.iconOnly)
        }.help("Delete this snapshot")
        .disabled(!snapshot.canDelete)
        Button {
            renamingID = snapshot.id
        } label: {
            Label("Rename", systemImage: "pencil")
                .labelStyle(.iconOnly)
        }.help("Rename this snapshot")
        Button {
            confirmation = .restore(snapshot.id)
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward")
        }.help("Replace the current state with this snapshot")
        .buttonStyle(.borderedProminent)
        .disabled(!snapshot.canRestore)
    }

    @ViewBuilder private func menuActions(for snapshot: VMSnapshot) -> some View {
        Button {
            confirmation = .restore(snapshot.id)
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward")
        }.disabled(!snapshot.canRestore)
        Button {
            select(snapshot.id)
            renamingID = snapshot.id
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Divider()
        DestructiveButton {
            confirmation = .delete(snapshot.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }.disabled(!snapshot.canDelete)
    }

    /// - Parameter id: Snapshot the row is for, `nil` for the current state
    private func isConfirming(_ id: UUID?) -> Binding<Bool> {
        Binding {
            confirmation != nil && confirmation?.id == id
        } set: { isPresented in
            if !isPresented && confirmation?.id == id {
                confirmation = nil
            }
        }
    }

    /// Show that the VM is busy during `work` and show the error if it fails
    private func perform(_ work: @escaping @MainActor @Sendable () async throws -> Void) {
        data.busyWorkAsync {
            try await work()
        }
    }

    private func select(_ id: UUID?) {
        guard selectedID != id else {
            return
        }
        renamingID = nil
        isTimelineFocused = id != nil
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedID = id
        }
    }

    private func selectParent(_ parent: VMSnapshot) {
        select(parent.id)
        scrollTo(parent.id)
    }

    private func createSnapshot() {
        perform {
            let id = try await list.createSnapshot()
            // let the default title be replaced right away
            selectedID = id
            renamingID = id
        }
    }

    private func overwriteBase() {
        perform {
            try await list.overwriteBase()
        }
    }

    private func deleteSuspendState() {
        perform {
            try await list.deleteSuspendState()
        }
    }

    private func delete(_ snapshot: VMSnapshot) {
        perform {
            try await list.delete(snapshot)
            if selectedID == snapshot.id {
                selectedID = nil
            }
        }
    }

    /// Replace the current state with the snapshot. A VM that is off resumes from it once it is run.
    private func restore(_ snapshot: VMSnapshot) {
        perform {
            try await list.restore(snapshot)
            selectedID = nil
        }
    }
}

#if os(macOS)
/// Delete and Escape for the selected snapshot.
///
/// The commands only reach a view that has focus. One that is not a control shows a focus ring
/// around all of it which cannot be turned off before macOS 14, so older versions go without.
private struct SnapshotKeyboardCommands: ViewModifier {
    let isFocused: FocusState<Bool>.Binding
    let onDelete: () -> Void
    let onExit: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content
                .focusable()
                .focusEffectDisabled()
                .focused(isFocused)
                .onDeleteCommand(perform: onDelete)
                .onExitCommand(perform: onExit)
        } else {
            content
        }
    }
}
#endif

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

// MARK: - Row

/// Shared layout of the current state and of a snapshot.
///
/// Only the focused row shows its actions to keep the rest of the list quiet. They sit on the
/// trailing edge where there is room and move below the text on narrow screens.
private struct SnapshotRow<Thumbnail: View, Title: View, Details: View, Actions: View>: View {
    let isCompact: Bool
    let isFocused: Bool
    let isSelected: Bool
    let rail: SnapshotRail
    let distantParent: VMSnapshot?
    let onSelect: () -> Void
    let onSelectParent: (VMSnapshot) -> Void
    @ViewBuilder let thumbnail: () -> Thumbnail
    @ViewBuilder let title: () -> Title
    @ViewBuilder let details: () -> Details
    @ViewBuilder let actions: () -> Actions

    @State private var isHovered: Bool = false

    private static var verticalPadding: CGFloat { 8 }

    private var thumbnailHeight: CGFloat {
        SnapshotThumbnail.height(isCompact: isCompact)
    }

    private var showsActions: Bool {
        isFocused || isHovered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail()
                VStack(alignment: .leading, spacing: 2) {
                    title()
                    details()
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let parent = distantParent {
                        parentLink(to: parent)
                    }
                }.lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !isCompact {
                    // always laid out so that focusing a row does not reflow its text
                    actionBar
                        .frame(height: thumbnailHeight)
                        .opacity(showsActions ? 1 : 0)
                        .disabled(!showsActions)
                        .accessibilityHidden(!showsActions)
                }
            }
            if isCompact && isFocused {
                actionBar
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }
        }.padding(.vertical, Self.verticalPadding)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(highlight))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .padding(.leading, SnapshotRail.width)
        .background(alignment: .leading) {
            rail.markerCenter(Self.verticalPadding + thumbnailHeight / 2)
                .frame(width: SnapshotRail.width)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            actions()
        }.labelStyle(.titleAndIcon)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
    }

    private var highlight: Color {
        if isSelected {
            return .accentColor.opacity(0.15)
        } else if isHovered {
            return .primary.opacity(0.05)
        } else {
            return .clear
        }
    }

    /// Names the parent when the rail cannot lead to it because other snapshots are in between.
    private func parentLink(to parent: VMSnapshot) -> some View {
        Button {
            onSelectParent(parent)
        } label: {
            Label {
                Text("From “\(parent.title)”")
            } icon: {
                Image(systemName: "arrow.triangle.branch")
            }.labelStyle(.titleAndIcon)
            .font(.caption)
        }.buttonStyle(.plain)
        .foregroundColor(.accentColor)
        .padding(.top, 2)
        .help("Show the snapshot this one was created from")
    }
}

// MARK: - Rail

/// Vertical line with a marker for each row. Rows that follow their parent are joined into one
/// uninterrupted line so that a lineage without branches reads as a plain timeline.
private struct SnapshotRail: View {
    static let width: CGFloat = 20
    static let lineWidth: CGFloat = 2

    enum Marker {
        case current
        /// Solid when the snapshot holds the running machine, hollow when it holds only the disks
        case snapshot(hasState: Bool)
    }

    enum Style {
        case normal
        case lineage

        var color: Color {
            switch self {
            case .normal: return .secondary.opacity(0.35)
            case .lineage: return .accentColor
            }
        }
    }

    struct Segment: View {
        let style: Style

        var body: some View {
            Rectangle()
                .fill(style.color)
                .frame(width: SnapshotRail.lineWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static let markerSize: CGFloat = 14

    let marker: Marker
    let isInLineage: Bool
    let up: Style?
    let down: Style?
    let hasDistantParent: Bool
    /// Distance from the top of the row to the center of the marker
    var markerCenter: CGFloat = 0

    private var style: Style {
        isInLineage ? .lineage : .normal
    }

    private var markerColor: Color {
        style == .lineage ? .accentColor : .secondary.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 0) {
            segment(up)
                .frame(height: max(0, markerCenter - Self.markerSize / 2))
            markerView
                .frame(width: Self.markerSize, height: Self.markerSize)
            if hasDistantParent {
                // loose end hinting that the lineage carries on further down
                VStack(spacing: 0) {
                    Line()
                        .stroke(style.color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, dash: [1, 4]))
                        .frame(width: Self.lineWidth, height: 12)
                    Spacer(minLength: 0)
                }.frame(maxHeight: .infinity)
            } else {
                segment(down)
            }
        }.accessibilityHidden(true)
    }

    func markerCenter(_ markerCenter: CGFloat) -> SnapshotRail {
        var rail = self
        rail.markerCenter = markerCenter
        return rail
    }

    @ViewBuilder private func segment(_ style: Style?) -> some View {
        if let style = style {
            Segment(style: style)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var markerView: some View {
        switch marker {
        case .current:
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: Self.lineWidth)
                .background(Circle().fill(Color.accentColor).padding(4))
        case .snapshot(let hasState):
            Group {
                if hasState {
                    Circle().fill(markerColor)
                } else {
                    Circle().strokeBorder(markerColor, lineWidth: 1.5)
                }
            }.frame(width: 9, height: 9)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }
}

// MARK: - Row content

private struct SnapshotThumbnail: View {
    let image: PlatformImage?
    let isCompact: Bool

    static func height(isCompact: Bool) -> CGFloat {
        (isCompact ? 80 : 96) * 9 / 16
    }

    private var width: CGFloat {
        Self.height(isCompact: isCompact) * 16 / 9
    }

    var body: some View {
        ZStack {
            if let image = image {
                Color.black
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                Color.secondary.opacity(0.15)
                Image(systemName: "display")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }.frame(width: width, height: Self.height(isCompact: isCompact))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
        .accessibilityHidden(true)
    }
}

private struct SnapshotTitle: View {
    let title: String
    let isEditing: Bool
    /// Called with the new title or `nil` if editing was cancelled
    let onCommit: (String?) -> Void

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField("Name", text: $draft)
                .font(.headline)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    onCommit(draft)
                }
                #if os(macOS)
                .onExitCommand {
                    onCommit(nil)
                }
                #endif
                .onChange(of: isFocused) { isFocused in
                    if !isFocused {
                        onCommit(draft)
                    }
                }
                .onAppear {
                    draft = title
                    // focus is not accepted until the field has settled in the hierarchy,
                    // which takes a moment on older systems
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isFocused = true
                    }
                }
        } else {
            Text(title)
                .font(.headline)
        }
    }
}

private struct SnapshotDetails: View {
    let snapshot: VMSnapshot
    /// The size is shown next to the title when there is no room for it here
    let isCompact: Bool

    static func size(of snapshot: VMSnapshot) -> Text {
        Text(ByteCountFormatter.string(fromByteCount: snapshot.size, countStyle: .binary))
    }

    /// Not every backend knows how much the disks of a snapshot occupy
    private var size: Text? {
        snapshot.size > 0 ? Self.size(of: snapshot) : nil
    }

    /// Note for a snapshot that the VM starts up from instead of resuming
    private var kind: Text? {
        snapshot.hasState ? nil : Text("Disks Only")
    }

    private func joined(_ parts: Text?...) -> Text {
        let parts = parts.compactMap { $0 }
        guard let first = parts.first else {
            return Text(verbatim: "")
        }
        return parts.dropFirst().reduce(first) { $0 + separator + $1 }
    }

    private func created(_ style: Date.FormatStyle.DateStyle) -> Text {
        Text("Created \(format(snapshot.dateCreated, style))")
    }

    private func modified(_ style: Date.FormatStyle.DateStyle) -> Text {
        Text("Modified \(format(snapshot.dateModified, style))")
    }

    /// The year is only worth its space when it is not the current one.
    private func format(_ date: Date, _ style: Date.FormatStyle.DateStyle) -> String {
        if style == .abbreviated && Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        } else {
            return date.formatted(date: style, time: .shortened)
        }
    }

    private var separator: Text {
        Text(verbatim: " · ")
    }

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 2) {
                created(.abbreviated)
                modified(.abbreviated)
                if let kind = kind {
                    kind
                }
            }
        } else if #available(iOS 16, macOS 13, *) {
            ViewThatFits(in: .horizontal) {
                joined(created(.abbreviated), modified(.abbreviated), size, kind)
                stacked
            }
        } else {
            stacked
        }
    }

    /// Both lines end up about as long as each other
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 2) {
            joined(created(.abbreviated), kind)
            joined(modified(.abbreviated), size)
        }
    }
}
