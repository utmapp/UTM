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

// MARK: - Drives list

@available(iOS 14, *)
struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMQemuConfiguration
    @State private var createDriveVisible: Bool = false
    @State private var attemptDelete: IndexSet?
    @State private var importDrivePresented: Bool = false
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        let bootOrder = Text("Note: Boot order is as listed.")
        Group {
            if config.countDrives == 0 {
                Text("No drives added.").font(.headline)
            } else {
                let form = Form {
                    List {
                        ForEach(0..<config.countDrives, id: \.self) { index in
                            let fileName = config.driveImagePath(for: index) ?? ""
                            let displayName = config.driveRemovable(for: index) ? NSLocalizedString("Removable Drive", comment: "VMConfigDrivesView") : fileName
                            let imageType = config.driveImageType(for: index)
                            let interfaceType = config.driveInterfaceType(for: index) ?? ""
                            NavigationLink(
                                destination: VMConfigDriveDetailsView(config: config, index: index, onDelete: nil), label: {
                                    VStack(alignment: .leading) {
                                        Text(displayName)
                                            .lineLimit(1)
                                        HStack {
                                            Text(imageType.description).font(.caption)
                                            if imageType == .disk || imageType == .CD {
                                                Text("-")
                                                Text(interfaceType).font(.caption)
                                            }
                                        }
                                    }
                                })
                        }.onDelete { offsets in
                            attemptDelete = offsets
                        }
                        .onMove(perform: moveDrives)
                    }
                }

                #if os(iOS)
                form.toolbar {
                    ToolbarItem(placement: .status) {
                        bootOrder
                    }
                }
                #else
                bootOrder
                form
                #endif
            }
        }
        .navigationBarItems(trailing:
            HStack {
                EditButton().padding(.trailing, 10)
                Button(action: { importDrivePresented.toggle() }, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(.iconOnly)
                }).padding(.trailing, 10)
                Button(action: { createDriveVisible.toggle() }, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(.iconOnly)
                })
            }
        )
        .fileImporter(isPresented: $importDrivePresented, allowedContentTypes: [.item], onCompletion: importDrive)
        .sheet(isPresented: $createDriveVisible) {
            CreateDrive(target: config.systemTarget, architecture: config.systemArchitecture, onDismiss: newDrive)
        }
        .actionSheet(item: $attemptDelete) { offsets in
            ActionSheet(title: Text("Confirm Delete"), message: Text("Are you sure you want to permanently delete this disk image?"), buttons: [.cancel(), .destructive(Text("Delete")) {
                deleteDrives(offsets: offsets)
            }])
        }
    }
    
    private func importDrive(result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                try await data.importDrive(url, for: config)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func newDrive(driveImage: VMDriveImage) {
        data.busyWorkAsync {
            try await data.createDrive(driveImage, for: config)
        }
    }
    
    private func deleteDrives(offsets: IndexSet) {
        data.busyWorkAsync {
            for offset in offsets {
                try await data.removeDrive(at: offset, for: config)
            }
        }
    }
    
    private func moveDrives(source: IndexSet, destination: Int) {
        for offset in source {
            let realDestination: Int
            if offset < destination {
                realDestination = destination - 1
            } else {
                realDestination = destination
            }
            config.moveDrive(offset, to: realDestination)
        }
    }
}

// MARK: - Create Drive

@available(iOS 14, *)
private struct CreateDrive: View {
    let target: String?
    let architecture: String?
    let onDismiss: (VMDriveImage) -> Void
    @StateObject private var driveImage = VMDriveImage()
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(target: String?, architecture: String?, onDismiss: @escaping (VMDriveImage) -> Void) {
        self.target = target
        self.architecture = architecture
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VMConfigDriveCreateView(target: target, architecture: architecture, driveImage: driveImage)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                    }
                }
        }.navigationViewStyle(.stack)
        .onAppear {
            driveImage.reset(forSystemTarget: target, architecture: architecture, removable: false)
        }
    }
    
    private func cancel() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func done() {
        presentationMode.wrappedValue.dismiss()
        onDismiss(driveImage)
    }
}

// MARK: - Preview

@available(iOS 14, *)
struct VMConfigDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        Group {
            VMConfigDrivesView(config: config)
            CreateDrive(target: nil, architecture: nil) { _ in
                
            }
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("", path: "test.img", type: .disk, interface: "ide")
                config.newDrive("", path: "bios.bin", type: .BIOS, interface: "none")
            }
        }
    }
}
