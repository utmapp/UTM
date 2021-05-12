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
struct VMRemovableDrivesView: View {
    let vm: UTMVirtualMachine
    @EnvironmentObject private var data: UTMData
    @ObservedObject private var config: UTMConfiguration
    @ObservedObject private var sessionConfig: UTMViewState
    @State private var shareDirectoryFileImportPresented: Bool = false
    @State private var diskImageFileImportPresented: Bool = false
    /// Explanation see "SwiftUI FileImporter modal bug" in the `body`
    @State private var workaroundFileImporterBug: Bool = false
    @State private var currentDrive: UTMDrive?
    
    var fileManager: FileManager {
        FileManager.default
    }
    
    init(vm: UTMVirtualMachine) {
        self.vm = vm
        self.config = vm.configuration
        self.sessionConfig = vm.viewState
    }
    
    var body: some View {
        Group {
            if config.shareDirectoryEnabled {
                HStack {
                    // Is a shared directory set?
                    let hasSharedDir = sessionConfig.sharedDirectoryPath != nil
                    // Browse/Clear menu
                    Menu {
                        // Browse button
                        Button(action: { shareDirectoryFileImportPresented.toggle() }, label: {
                            Label("Browse", systemImage: "doc.badge.plus")
                        })
                        if hasSharedDir {
                            // Clear button
                            Button(action: clearShareDirectory, label: {
                                Label("Clear", systemImage: "eject")
                            })
                        }
                    } label: {
                        Label { Text("Shared Directory") } icon: {
                            Image(systemName: hasSharedDir ? "externaldrive.fill.badge.person.crop" : "externaldrive.badge.person.crop") }
                    }.disabled(sessionConfig.suspended)
                    Spacer()
                    SharedPath(path: sessionConfig.sharedDirectoryPath)
                }.fileImporter(isPresented: $shareDirectoryFileImportPresented, allowedContentTypes: [.folder], onCompletion: selectShareDirectory)
            }
            ForEach(vm.drives.filter { $0.status != .fixed }) { drive in
                HStack {
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
                        if drive.status != .ejected {
                            Button(action: { clearRemovableImage(forDrive: drive) }, label: {
                                Label("Clear", systemImage: "eject")
                            })
                        }
                    } label: {
                        DriveLabel(drive: drive)
                    }.disabled(sessionConfig.suspended)
                    Spacer()
                    // Disk image path, or (empty)
                    Text(pathFor(drive))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }
            }.fileImporter(isPresented: $diskImageFileImportPresented, allowedContentTypes: [.data]) { result in
                if let currentDrive = self.currentDrive {
                    selectRemovableImage(forDrive: currentDrive, result: result)
                    self.currentDrive = nil
                }
            }
        }
    }
    
    private struct SharedPath: View {
        let path: String?

        var body: some View {
            if let path = path {
                let url = URL(fileURLWithPath: path)
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
    
    private func pathFor(_ drive: UTMDrive) -> String {
        let path = sessionConfig.path(forRemovableDrive: drive.name ?? "") ?? ""
        if path.count > 0 {
            let url = URL(fileURLWithPath: path)
            return url.lastPathComponent
        } else {
            return NSLocalizedString("(empty)", comment: "A removable drive that has no image file inserted.")
        }
    }
    
    private struct DriveLabel: View {
        let drive: UTMDrive

        var body: some View {
            if drive.imageType == .CD {
                return Label("CD/DVD", systemImage: drive.status == .ejected ? "opticaldiscdrive" : "opticaldiscdrive.fill")
            } else {
                return Label("Removable", systemImage: "externaldrive")
            }
        }
    }
    
    private func selectShareDirectory(result: Result<URL, Error>) {
        data.busyWork {
            switch result {
            case .success(let url):
                try vm.changeSharedDirectory(url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearShareDirectory() {
        vm.clearSharedDirectory()
    }
    
    private func selectRemovableImage(forDrive drive: UTMDrive, result: Result<URL, Error>) {
        data.busyWork {
            switch result {
            case .success(let url):
                try vm.changeMedium(for: drive, url: url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearRemovableImage(forDrive drive: UTMDrive) {
        data.busyWork {
            try vm.ejectDrive(drive, force: true)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMRemovableDrivesView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMRemovableDrivesView(vm: UTMVirtualMachine(configuration: config, withDestinationURL: URL(fileURLWithPath: "")))
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", path: "", type: .disk, interface: "ide")
            config.newDrive("", path: "", type: .disk, interface: "sata")
            config.newDrive("", path: "", type: .CD, interface: "ide")
        }
    }
}
