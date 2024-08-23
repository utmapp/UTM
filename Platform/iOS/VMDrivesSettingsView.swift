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

struct VMDrivesSettingsView: View {
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var isCreateDriveShown: Bool
    @Binding var isImportDriveShown: Bool
    @State private var attemptDelete: IndexSet?
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        ForEach($config.drives) { $drive in
            NavigationLink(
                destination: VMConfigDriveDetailsView(config: $drive, requestDriveDelete: .constant(nil)), label: {
                    Label(title: { labelTitle(for: drive) }, icon: { Image(systemName: "externaldrive") })
                })
        }.onDelete { offsets in
            attemptDelete = offsets
        }
        .onMove(perform: moveDrives)
        Button {
            isImportDriveShown.toggle()
        } label: {
            Text("Import Drive…")
        }
        Button {
            isCreateDriveShown.toggle()
        } label: {
            Text("New Drive…")
        }
        .nonbrokenSheet(isPresented: $isCreateDriveShown) {
            CreateDrive(newDrive: UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target), onDismiss: newDrive)
        }
        .globalFileImporter(isPresented: $isImportDriveShown, allowedContentTypes: [.item], onCompletion: importDrive)
        .actionSheet(item: $attemptDelete) { offsets in
            ActionSheet(title: Text("Confirm Delete"), message: Text("Are you sure you want to permanently delete this disk image?"), buttons: [.cancel(), .destructive(Text("Delete")) {
                deleteDrives(offsets: offsets)
            }])
        }
    }
    
    private func labelTitle(for drive: UTMQemuConfigurationDrive) -> Text {
        if drive.interface == .none && drive.imageName == QEMUPackageFileName.efiVariables.rawValue {
            return Text("EFI Variables", comment: "VMDrivesSettingsView")
        } else {
            return Text("\(drive.interface.prettyValue) Drive", comment: "VMDrivesSettingsView")
        }
    }
    
    private func newDrive(drive: UTMQemuConfigurationDrive) {
        config.drives.append(drive)
    }
    
    private func deleteDrives(offsets: IndexSet) {
        config.drives.remove(atOffsets: offsets)
    }
    
    private func moveDrives(source: IndexSet, destination: Int) {
        config.drives.move(fromOffsets: source, toOffset: destination)
    }
    
    private func importDrive(result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                await MainActor.run {
                    var drive = UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target, isExternal: false)
                    drive.imageURL = url
                    config.drives.append(drive)
                }
                break
            case .failure(let err):
                throw err
            }
        }
    }
}

// MARK: - Create Drive

private extension View {
    /// A sheet that isn't broken on older versions.
    ///
    /// On iOS 14 and older, .sheet() breaks the table layout for some reason.
    /// This workarounds it by putting the sheet inside an overlay which does
    /// not affect displaying the sheet at all.
    /// - Parameters:
    ///   - isPresented: same as .sheet()
    ///   - onDismiss: same as .sheet()
    ///   - content: same as .sheet()
    /// - Returns: same as .sheet()
    @ViewBuilder func nonbrokenSheet<Content>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View {
        if #available(iOS 15, macOS 12, *) {
            self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        } else {
            self.overlay(EmptyView().sheet(isPresented: isPresented, onDismiss: onDismiss, content: content))
        }
    }
}

private struct CreateDrive: View {
    @State var newDrive: UTMQemuConfigurationDrive
    let onDismiss: (UTMQemuConfigurationDrive) -> Void
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            VMConfigDriveCreateView(config: $newDrive)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                    }
                }
        }.navigationViewStyle(.stack)
    }
    
    private func cancel() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func done() {
        presentationMode.wrappedValue.dismiss()
        onDismiss(newDrive)
    }
}

// MARK: - Preview

struct VMConfigDrivesView_Previews: PreviewProvider {
    @StateObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        Group {
            VMDrivesSettingsView(config: config, isCreateDriveShown: .constant(false), isImportDriveShown: .constant(false))
            CreateDrive(newDrive: UTMQemuConfigurationDrive()) { _ in
                
            }
        }.onAppear {
            if config.drives.count == 0 {
                var drive = UTMQemuConfigurationDrive(forArchitecture: .x86_64, target: QEMUTarget_x86_64.pc)
                drive.imageName = "test.img"
                drive.imageType = .disk
                drive.interface = .ide
                config.drives.append(drive)
                drive = UTMQemuConfigurationDrive(forArchitecture: .x86_64, target: QEMUTarget_x86_64.pc)
                drive.imageName = "bios.bin"
                drive.imageType = .bios
                drive.interface = .none
                config.drives.append(drive)
            }
        }
    }
}
