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

struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var modal: DriveConfigModal? = nil
    @State private var attemptDelete: IndexSet?
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Group {
            if config.countDrives == 0 {
                Text("No drives added.").font(.headline)
            } else {
                Form {
                    List {
                        ForEach(0..<config.countDrives, id: \.self) { index in
                            let fileName = config.driveImagePath(for: index) ?? ""
                            let imageType = config.driveImageType(for: index)
                            let interfaceType = config.driveInterfaceType(for: index) ?? ""
                            NavigationLink(
                                destination: VMConfigDriveDetailsView(config: config, index: index), label: {
                                    VStack(alignment: .leading) {
                                        Text(fileName)
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
            }
        }
        .navigationBarItems(trailing:
            HStack {
                EditButton().padding(.trailing, 10)
                Button(action: { modal = .importFile }, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(IconOnlyLabelStyle())
                }).padding(.trailing, 10)
                Button(action: { modal = .newFile }, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
                })
            }
        )
        .modifier(NewDriveModifier(config: config, modal: $modal))
        .actionSheet(item: $attemptDelete) { offsets in
            ActionSheet(title: Text("Confirm Delete"), message: Text("Are you sure you want to permanently delete this disk image?"), buttons: [.cancel(), .destructive(Text("Delete")) {
                deleteDrives(offsets: offsets)
            }])
        }
    }
    
    private func deleteDrives(offsets: IndexSet) {
        data.busyWork {
            for offset in offsets {
                try data.removeDrive(at: offset, forConfig: config)
            }
        }
    }
    
    private func moveDrives(source: IndexSet, destination: Int) {
        for offset in source {
            config.moveDrive(offset, to: destination)
        }
    }
}

// MARK: - New Drive

enum DriveConfigModal: Identifiable {
    var id: DriveConfigModal { self }
    
    case newFile
    case importFile
}

private struct NewDriveModifier: ViewModifier {
    @ObservedObject var config: UTMConfiguration
    @Binding var modal: DriveConfigModal?
    @EnvironmentObject private var data: UTMData
    
    func body(content: Content) -> some View {
        content.sheet(item: $modal) { select in
            switch select {
            case .importFile:
                FilePicker(forOpeningContentTypes: [.item], asCopy: true) { urls in
                    if !urls.isEmpty {
                        importFile(forURL: urls.first!)
                    }
                }
            case .newFile:
                CreateDrive(onDismiss: newFile)
            }
        }
    }
    
    private func importFile(forURL: URL) {
        data.busyWork {
            try data.importDrive(forURL, forConfig: config)
        }
    }
    
    private func newFile(driveImage: VMDriveImage) {
        data.busyWork {
            try data.createDrive(driveImage, forConfig: config)
        }
    }
}

// MARK: - Create Drive

private struct CreateDrive: View {
    let onDismiss: (VMDriveImage) -> Void
    @StateObject private var driveImage = VMDriveImage()
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(onDismiss: @escaping (VMDriveImage) -> Void) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VMConfigDriveCreateView(driveImage: driveImage)
                .navigationBarItems(leading: Button(action: cancel, label: {
                    Text("Cancel")
                }), trailing: Button(action: done, label: {
                    Text("Done")
                }))
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

struct VMConfigDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMConfigDrivesView(config: config)
            CreateDrive { _ in
                
            }
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("test.img", type: .disk, interface: "ide")
                config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
            }
        }
    }
}
