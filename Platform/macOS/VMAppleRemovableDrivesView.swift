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

struct VMAppleRemovableDrivesView: View {
    private enum SelectType {
        case sharedDirectory
        case diskImage
    }
    
    @ObservedObject var vm: VMData
    @ObservedObject var config: UTMAppleConfiguration
    @ObservedObject var registryEntry: UTMRegistryEntry
    @EnvironmentObject private var data: UTMData
    @State private var fileImportPresented: Bool = false
    @State private var selectType: SelectType = .sharedDirectory
    @State private var selectedSharedDirectoryBinding: Binding<UTMRegistryEntry.File>?
    @State private var selectedDiskImage: UTMAppleConfigurationDrive?
    /// Explanation see "SwiftUI FileImporter modal bug" in `showFileImporter`
    @State private var workaroundFileImporterBug: Bool = false
    
    private var appleVM: UTMAppleVirtualMachine! {
        vm.wrapped as? UTMAppleVirtualMachine
    }
    
    private var hasSharingFeatures: Bool {
        if #available(macOS 13, *) {
            return true
        } else if #available(macOS 12, *), config.system.boot.operatingSystem == .linux {
            return true
        } else {
            return false
        }
    }

    private var hasLiveRemovableDrives: Bool {
        if #available(macOS 15, *) {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        Group {
            ForEach($registryEntry.sharedDirectories) { $sharedDirectory in
                HStack {
                    // Browse/Clear menu
                    Menu {
                        // Browse button
                        Button(action: {
                            selectType = .sharedDirectory
                            selectedSharedDirectoryBinding = $sharedDirectory
                            showFileImporter()
                        }, label: {
                            Label("Browse…", systemImage: "doc.badge.plus")
                        })
                        // Clear button
                        Button(action: {
                            deleteShareDirectory(sharedDirectory)
                        }, label: {
                            Label("Remove", systemImage: "eject")
                        })
                    } label: {
                        Label("Shared Directory", systemImage: "externaldrive.fill.badge.person.crop")
                    }
                    Spacer()
                    FilePath(url: sharedDirectory.url)
                }
            }
            ForEach($config.drives) { $diskImage in
                HStack {
                    if diskImage.isExternal {
                        // Drive menu
                        Menu {
                            // Browse button
                            Button(action: {
                                selectType = .diskImage
                                selectedDiskImage = diskImage
                                showFileImporter()
                            }, label: {
                                Label("Browse…", systemImage: "doc.badge.plus")
                            })
                            // Eject button
                            if diskImage.isExternal && diskImage.imageURL != nil {
                                Button(action: { clearRemovableImage(diskImage) }, label: {
                                    Label("Clear", systemImage: "eject")
                                })
                            }
                        } label: {
                            Label("External Drive", systemImage: "externaldrive")
                        }.disabled(vm.hasSuspendState || (vm.state != .stopped && !hasLiveRemovableDrives))
                    } else {
                        Label("\(diskImage.sizeString) Drive", systemImage: "internaldrive")
                    }
                    Spacer()
                    // Disk image path, or (empty)
                    FilePath(url: diskImage.imageURL)
                }
            }
            HStack {
                Spacer()
                if hasSharingFeatures {
                    Button("New Shared Directory…") {
                        selectType = .sharedDirectory
                        selectedSharedDirectoryBinding = nil
                        showFileImporter()
                    }
                }
            }.fileImporter(isPresented: $fileImportPresented, allowedContentTypes: selectType == .sharedDirectory ? [.folder] : [.data]) { result in
                if selectType == .sharedDirectory {
                    if let binding = selectedSharedDirectoryBinding {
                        selectShareDirectory(for: binding, result: result)
                        selectedSharedDirectoryBinding = nil
                    } else {
                        createShareDirectory(result)
                    }
                } else {
                    if let diskImage = selectedDiskImage {
                        selectRemovableImage(for: diskImage, result: result)
                        selectedDiskImage = nil
                    }
                }
            }.onChange(of: workaroundFileImporterBug) { doWorkaround in
                /// Explanation see "SwiftUI FileImporter modal bug" below
                if doWorkaround {
                    DispatchQueue.main.async {
                        workaroundFileImporterBug = false
                        fileImportPresented = true
                    }
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
    
    private func showFileImporter() {
        // MARK: SwiftUI FileImporter modal bug
        /// At this point in the execution, `diskImageFileImportPresented` must be `false`.
        /// However there is a SwiftUI FileImporter modal bug:
        /// if the user taps outside the import modal to cancel instead of tapping the actual cancel button,
        /// the `.fileImporter` doesn't actually set the isPresented Binding to `false`.
        if (fileImportPresented) {
            /// bug! Let's set the bool to false ourselves.
            fileImportPresented = false
            /// One more thing: we can't immediately set it to `true` again because then the state won't have changed.
            /// So we have to use the workaround, which is caught in the `.onChange` below.
            workaroundFileImporterBug = true
        } else {
            fileImportPresented = true
        }
    }
    
    private func selectShareDirectory(for binding: Binding<UTMRegistryEntry.File>, result: Result<URL, Error>) {
        data.busyWork {
            let url = try result.get()
            binding.wrappedValue.url = url
        }
    }
    
    private func createShareDirectory(_ result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            let sharedDirectory = try UTMRegistryEntry.File(url: url)
            await MainActor.run {
                registryEntry.sharedDirectories.append(sharedDirectory)
            }
        }
    }
    
    private func deleteShareDirectory(_ sharedDirectory: UTMRegistryEntry.File) {
        appleVM.registryEntry.sharedDirectories.removeAll(where: { $0.id == sharedDirectory.id })
    }
    
    private func selectRemovableImage(for diskImage: UTMAppleConfigurationDrive, result: Result<URL, Error>) {
        data.busyWorkAsync {
            let url = try result.get()
            if #available(macOS 15, *) {
                try await appleVM.changeMedium(diskImage, to: url)
            } else {
                let file = try UTMRegistryEntry.File(url: url)
                await registryEntry.setExternalDrive(file, forId: diskImage.id)
            }
        }
    }
    
    private func clearRemovableImage(_ diskImage: UTMAppleConfigurationDrive) {
        data.busyWorkAsync {
            if #available(macOS 15, *) {
                try await appleVM.eject(diskImage)
            } else {
                await registryEntry.removeExternalDrive(forId: diskImage.id)
            }
        }
    }
}

struct VMAppleRemovableDrivesView_Previews: PreviewProvider {
    @StateObject static var vm = VMData(from: .empty)
    @StateObject static var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMAppleRemovableDrivesView(vm: vm, config: config, registryEntry: vm.registryEntry!)
    }
}
