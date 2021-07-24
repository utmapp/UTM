//
// Copyright © 2021 osy. All rights reserved.
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

@available(macOS 12, *)
struct VMAppleRemovableDrivesView: View {
    @ObservedObject var vm: UTMAppleVirtualMachine
    @ObservedObject var config: UTMAppleConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var selectedSharedDirectoryBinding: Binding<SharedDirectory>?
    @State private var shareDirectoryFileImportPresented: Bool = false
    @State private var selectedDiskImageBinding: Binding<DiskImage>?
    @State private var diskImageFileImportPresented: Bool = false
    /// Explanation see "SwiftUI FileImporter modal bug" in the `body`
    @State private var workaroundFileImporterBug: Bool = false
    
    var body: some View {
        Group {
            ForEach($config.sharedDirectories) { $sharedDirectory in
                HStack {
                    // Is a shared directory set?
                    let hasSharedDir = sharedDirectory.directoryURL != nil
                    // Browse/Clear menu
                    Menu {
                        // Browse button
                        Button(action: {
                            selectedSharedDirectoryBinding = $sharedDirectory
                            shareDirectoryFileImportPresented.toggle()
                        }, label: {
                            Label("Browse", systemImage: "doc.badge.plus")
                        })
                        if hasSharedDir {
                            // Clear button
                            Button(action: {
                                deleteShareDirectory(sharedDirectory)
                            }, label: {
                                Label("Remove", systemImage: "eject")
                            })
                        }
                    } label: {
                        Label { Text("Shared Directory") } icon: {
                            Image(systemName: hasSharedDir ? "externaldrive.fill.badge.person.crop" : "externaldrive.badge.person.crop") }
                    }.disabled(vm.viewState.suspended)
                    Spacer()
                    FilePath(url: sharedDirectory.directoryURL)
                }
            }.fileImporter(isPresented: $shareDirectoryFileImportPresented, allowedContentTypes: [.folder]) { result in
                if let binding = selectedSharedDirectoryBinding {
                    selectShareDirectory(for: binding, result: result)
                    selectedSharedDirectoryBinding = nil
                } else {
                    createShareDirectory(result)
                }
            }
            ForEach($config.diskImages) { $diskImage in
                HStack {
                    if diskImage.isExternal {
                        // Drive menu
                        Menu {
                            // Browse button
                            Button(action: {
                                selectedDiskImageBinding = $diskImage
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
                                Label("Browse", systemImage: "doc.badge.plus")
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
                            if diskImage.isExternal && diskImage.imageURL != nil {
                                Button(action: { deleteRemovableImage(diskImage) }, label: {
                                    Label("Remove", systemImage: "eject")
                                })
                            }
                        } label: {
                            Label("Removable Drive", systemImage: "externaldrive")
                        }.disabled(vm.viewState.suspended)
                    } else {
                        Label("\(diskImage.sizeString) Drive", systemImage: "internaldrive")
                    }
                    Spacer()
                    // Disk image path, or (empty)
                    FilePath(url: diskImage.imageURL)
                }
            }.fileImporter(isPresented: $diskImageFileImportPresented, allowedContentTypes: [.data]) { result in
                if let binding = selectedDiskImageBinding {
                    selectRemovableImage(for: binding, result: result)
                    selectedDiskImageBinding = nil
                } else {
                    createRemovableImage(result)
                }
            }
            HStack {
                Spacer()
                Button("New Shared Directory...") {
                    selectedSharedDirectoryBinding = nil
                    shareDirectoryFileImportPresented.toggle()
                }
                Button("New External Drive...") {
                    selectedDiskImageBinding = nil
                    diskImageFileImportPresented.toggle()
                }
            }
        }
    }
    
    private struct FilePath: View {
        let url: URL?

        var body: some View {
            if let url = url {
                Text(url.lastPathComponent)
                    .truncationMode(.head)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            } else {
                Text("(empty)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func selectShareDirectory(for binding: Binding<SharedDirectory>, result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            binding.wrappedValue.directoryURL = url
            try vm.saveUTM()
        }
    }
    
    private func createShareDirectory(_ result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            let sharedDirectory = SharedDirectory(directoryURL: url)
            config.sharedDirectories.append(sharedDirectory)
            try vm.saveUTM()
        }
    }
    
    private func deleteShareDirectory(_ sharedDirectory: SharedDirectory) {
        data.busyWorkAsync {
            config.sharedDirectories.removeAll { existing in
                existing == sharedDirectory
            }
            try vm.saveUTM()
        }
    }
    
    private func selectRemovableImage(for binding: Binding<DiskImage>, result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            binding.wrappedValue.imageURL = url
            try vm.saveUTM()
        }
    }
    
    private func createRemovableImage(_ result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            let diskImage = DiskImage(importImage: url, isReadOnly: false, isExternal: true)
            config.diskImages.append(diskImage)
            try vm.saveUTM()
        }
    }
    
    private func deleteRemovableImage(_ diskImage: DiskImage) {
        data.busyWorkAsync {
            config.diskImages.removeAll { existing in
                existing == diskImage
            }
            try vm.saveUTM()
        }
    }
}

@available(macOS 12, *)
struct VMAppleRemovableDrivesView_Previews: PreviewProvider {
    @StateObject static var vm = UTMAppleVirtualMachine()
    @StateObject static var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMAppleRemovableDrivesView(vm: vm, config: config)
    }
}
