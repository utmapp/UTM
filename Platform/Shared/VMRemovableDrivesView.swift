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
import UniformTypeIdentifiers

struct VMRemovableDrivesView: View {
    @ObservedObject var vm: VMData
    @ObservedObject var config: UTMQemuConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var shareDirectoryFileImportPresented: Bool = false
    @State private var diskImageFileImportPresented: Bool = false
    /// Explanation see "SwiftUI FileImporter modal bug" in the `body`
    @State private var workaroundFileImporterBug: Bool = false
    @State private var currentDrive: UTMQemuConfigurationDrive?

    private static let shareDirectoryUTType = UTType.folder
    private static let diskImageUTType = UTType.data

    private var qemuVM: (any UTMSpiceVirtualMachine)! {
        vm.wrapped as? any UTMSpiceVirtualMachine
    }
    
    var fileManager: FileManager {
        FileManager.default
    }


    // Is a shared directory set?
    private var hasSharedDir: Bool { qemuVM.sharedDirectoryURL != nil }

    @ViewBuilder private var shareMenuActions: some View {
        Button(action: { shareDirectoryFileImportPresented.toggle() }) {
            Label("Browse…", systemImage: "doc.badge.plus")
        }
        if hasSharedDir {
            Button(action: clearShareDirectory) {
                Label("Clear", systemImage: "eject")
            }
        }
    }

    var body: some View {
        let title = Label {
            Text("Shared Directory")
        } icon: {
            Image(systemName: hasSharedDir ? "externaldrive.fill.badge.person.crop" : "externaldrive.badge.person.crop")
                .foregroundColor(.primary)
        }


        Group {
            let mode = config.sharing.directoryShareMode
            if mode != .none {
                HStack {
                    title
                    Spacer()
                    if hasSharedDir {
                        Menu {
                            shareMenuActions
                        } label: {
                            SharedPath(path: qemuVM.sharedDirectoryURL?.path)
                        }.fixedSize()
                    } else {
                        Button("Browse…", action: { shareDirectoryFileImportPresented.toggle() })
                    }
                }.fileImporter(isPresented: $shareDirectoryFileImportPresented, allowedContentTypes: [Self.shareDirectoryUTType], onCompletion: selectShareDirectory)
                    .disabled(mode == .virtfs && vm.state != .stopped)
                    .onDrop(of: [Self.shareDirectoryUTType], isTargeted: nil) { providers in
                        guard let item = providers.first, item.hasItemConformingToTypeIdentifier(Self.shareDirectoryUTType.identifier) else { return false }

                        item.loadItem(forTypeIdentifier: Self.shareDirectoryUTType.identifier) { url, error in
                            if let url = url as? URL {
                                selectShareDirectory(result: .success(url))
                            }
                            if let error = error {
                                selectShareDirectory(result: .failure(error))
                            }
                        }
                        return true
                    }
            }
            ForEach(config.drives.filter { $0.isExternal }) { drive in
                HStack {
                    #if !WITH_REMOTE // FIXME: implement remote feature
                    // Drive menu
                    Menu {
                        // Browse button
                        Button(action: {
                            currentDrive = drive
                            // MARK: SwiftUI FileImporter modal bug
                            /// At this point in the execution, `diskImageFileImportPresented` must be `false`.
                            /// However there is a SwiftUI FileImporter modal bug:
                            /// if the user taps outside the import modal to cancel instead of tapping the actual cancel button,
                            /// the `.fileImporter` doesn't actually set the isPresented Binding to `false`.
                            if (diskImageFileImportPresented) {
                                /// bug! Let's set the bool to false ourselves.
                                diskImageFileImportPresented = false
                                /// One more thing: we can't immediately set it to `true` again because then the state won't have changed.
                                /// So we have to use the workaround, which is caught in the `.onChange` below.
                                workaroundFileImporterBug = true
                            } else {
                                diskImageFileImportPresented = true
                            }
                        }, label: {
                            Label("Browse…", systemImage: "doc.badge.plus")
                        })
                        .onChange(of: workaroundFileImporterBug) { doWorkaround in
                            /// Explanation see "SwiftUI FileImporter modal bug" above
                            if doWorkaround {
                                DispatchQueue.main.async {
                                    workaroundFileImporterBug = false
                                    diskImageFileImportPresented = true
                                }
                            }
                        }
                        // Eject button
                        if qemuVM.externalImageURL(for: drive) != nil {
                            Button(action: { clearRemovableImage(forDrive: drive) }, label: {
                                Label("Clear", systemImage: "eject")
                            })
                        }
                    } label: {
                        DriveLabel(drive: drive, isInserted: qemuVM.externalImageURL(for: drive) != nil)
                    }.disabled(vm.hasSuspendState)
                    #else
                    DriveLabel(drive: drive, isInserted: qemuVM.externalImageURL(for: drive) != nil)
                    #endif
                    Spacer()
                    // Disk image path, or (empty)
                    Text(pathFor(drive))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }.fileImporter(isPresented: $diskImageFileImportPresented, allowedContentTypes: [Self.diskImageUTType]) { result in
                    if let currentDrive = self.currentDrive {
                        selectRemovableImage(forDrive: currentDrive, result: result)
                        self.currentDrive = nil
                    }
                }
                .onDrop(of: [Self.diskImageUTType], isTargeted: nil) { providers in
                    guard let item = providers.first, item.hasItemConformingToTypeIdentifier(Self.diskImageUTType.identifier) else { return false }

                    item.loadItem(forTypeIdentifier: Self.diskImageUTType.identifier) { url, error in
                        if let url = url as? URL{
                            selectRemovableImage(forDrive: drive, result: .success(url))
                        }
                        if let error {
                            selectRemovableImage(forDrive: drive, result: .failure(error))
                        }
                    }
                    return true
                }
            }
        }
    }
    
    private struct SharedPath: View {
        let path: String?

        var body: some View {
            if let path = path {
                let url = URL(fileURLWithPath: path)
                HStack {
                    Text(url.lastPathComponent)
                        .truncationMode(.head)
                        .lineLimit(1)
                    #if os(iOS) || os(visionOS)
                    Image(systemName: "chevron.down")
                    #endif
                }
            } else {
                Text("(empty)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func pathFor(_ drive: UTMQemuConfigurationDrive) -> String {
        if let url = qemuVM.externalImageURL(for: drive) {
            return url.lastPathComponent
        } else {
            return NSLocalizedString("(empty)", comment: "A removable drive that has no image file inserted.")
        }
    }
    
    private struct DriveLabel: View {
        let drive: UTMQemuConfigurationDrive
        let isInserted: Bool

        var body: some View {
            if drive.imageType == .cd {
                return Label("CD/DVD", systemImage: !isInserted ? "opticaldiscdrive" : "opticaldiscdrive.fill")
            } else {
                return Label(String.localizedStringWithFormat(NSLocalizedString("%@ %@", comment: "VMRemovableDrivesView"),
                                                              NSLocalizedString("Removable", comment: "VMRemovableDrivesView"),
                                                              drive.interface.prettyValue),
                             systemImage: "externaldrive")
            }
        }
    }
    
    private func selectShareDirectory(result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                try await qemuVM.changeSharedDirectory(to: url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearShareDirectory() {
        data.busyWorkAsync {
            await qemuVM.clearSharedDirectory()
        }
    }
    
    private func selectRemovableImage(forDrive drive: UTMQemuConfigurationDrive, result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                try await qemuVM.changeMedium(drive, to: url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearRemovableImage(forDrive drive: UTMQemuConfigurationDrive) {
        data.busyWorkAsync {
            try await qemuVM.eject(drive)
        }
    }
}

struct VMRemovableDrivesView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMDetailsView(vm: VMData(from: .empty))
        .onAppear {
            config.sharing.directoryShareMode = .webdav
            var drive = UTMQemuConfigurationDrive()
            drive.imageType = .disk
            drive.interface = .ide
            config.drives.append(drive)
            drive.interface = .scsi
            config.drives.append(drive)
            drive.imageType = .cd
            config.drives.append(drive)
        }
    }
}
