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

struct VMConfigDrivesButtons<Config: ObservableObject & UTMConfigurable>: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: Config
    @Binding var selectedDriveIndex: Int?
    
    @EnvironmentObject private var data: UTMData
    @State private var newDrivePopover: Bool = false
    @StateObject private var newQemuDrive: VMDriveImage = VMDriveImage()
    @State private var newAppleDriveSize: Int = 0
    @State private var importDrivePresented: Bool = false
    
    var countDrives: Int {
        if let qemuConfig = config as? UTMQemuConfiguration {
            return qemuConfig.countDrives
        } else if let appleConfig = config as? UTMAppleConfiguration {
            return appleConfig.storageAttachments.count
        } else {
            return 0
        }
    }
    
    var body: some View {
        Group {
            Button {
                newDrivePopover.toggle()
            } label: {
                Label("New Drive", systemImage: "externaldrive.badge.plus")
            }.help("Add a new drive.")
            .fileImporter(isPresented: $importDrivePresented, allowedContentTypes: [.item], onCompletion: importDrive)
            .onChange(of: newDrivePopover, perform: { showPopover in
                if showPopover {
                    if let qemuConfig = config as? UTMQemuConfiguration {
                    newQemuDrive.reset(forSystemTarget: qemuConfig.systemTarget, removable: false)
                    } else if let _ = config as? UTMAppleConfiguration {
                        newAppleDriveSize = 10240
                    }
                }
            })
            .popover(isPresented: $newDrivePopover, arrowEdge: .top) {
                VStack {
                    if let qemuConfig = config as? UTMQemuConfiguration {
                        VMConfigDriveCreateView(target: qemuConfig.systemTarget, driveImage: newQemuDrive)
                    } else if #available(macOS 12, *), let _ = config as? UTMAppleConfiguration {
                        VMConfigAppleDriveCreateView(driveSize: $newAppleDriveSize)
                    }
                    HStack {
                        Spacer()
                        Button(action: { importDrivePresented.toggle() }, label: {
                            if let _ = config as? UTMQemuConfiguration {
                                if newQemuDrive.removable {
                                    Text("Browse")
                                } else {
                                    Text("Import")
                                }
                            } else {
                                Text("Import")
                            }
                        }).help("Select an existing disk image.")
                        Button(action: { addNewDrive(newQemuDrive) }, label: {
                            Text("Create")
                        }).help("Create an empty drive.")
                    }
                }.padding()
            }
            if let index = selectedDriveIndex, index != 0 {
                Button {
                    deleteDrive(atIndex: index)
                } label: {
                    Label("Delete Drive", systemImage: "externaldrive.badge.plus")
                }.help("Delete this drive.")
                Button {
                    moveDriveUp(fromIndex: index)
                } label: {
                    Label("Move Up", systemImage: "chevron.up")
                }.help("Make boot order priority higher.")
                if index != countDrives - 1 {
                    Button {
                        moveDriveDown(fromIndex: index)
                    } label: {
                        Label("Move Down", systemImage: "chevron.down")
                    }.help("Make boot order priority lower.")
                }
            }
        }.labelStyle(TitleOnlyLabelStyle())
    }
    
    func deleteDrive(atIndex index: Int) {
        data.busyWork {
            if let qemuConfig = config as? UTMQemuConfiguration {
                try data.removeDrive(at: index, for: qemuConfig)
            } else if let appleConfig = config as? UTMAppleConfiguration {
                let drive = appleConfig.storageAttachments.remove(at: index)
                appleConfig.storageAttachmentsToDelete.insert(drive)
            }
        }
    }
    
    func moveDriveUp(fromIndex index: Int) {
        withAnimation {
            if let qemuConfig = config as? UTMQemuConfiguration {
                qemuConfig.moveDrive(index, to: index - 1)
            } else if let appleConfig = config as? UTMAppleConfiguration {
                appleConfig.storageAttachments.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            }
            selectedDriveIndex = index - 1
        }
    }
    
    func moveDriveDown(fromIndex index: Int) {
        withAnimation {
            if let qemuConfig = config as? UTMQemuConfiguration {
                qemuConfig.moveDrive(index, to: index + 1)
            } else if let appleConfig = config as? UTMAppleConfiguration {
                appleConfig.storageAttachments.move(fromOffsets: IndexSet(integer: index), toOffset: index + 1)
            }
            selectedDriveIndex = index + 1
        }
    }
    
    private func importDrive(result: Result<URL, Error>) {
        data.busyWork {
            switch result {
            case .success(let url):
                if let qemuConfig = config as? UTMQemuConfiguration {
                    if newQemuDrive.removable {
                        try data.createDrive(newQemuDrive, for: qemuConfig, with: url)
                    } else {
                        try data.importDrive(url, for: qemuConfig, imageType: newQemuDrive.imageType, on: newQemuDrive.interface!, copy: true)
                    }
                } else if let appleConfig = config as? UTMAppleConfiguration {
                    // TODO: import drive
                }
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func browseImage(result: Result<URL, Error>) {
        let qemuConfig = config as! UTMQemuConfiguration
        data.busyWork {
            switch result {
            case .success(let url):
                try data.importDrive(url, for: qemuConfig, imageType: newQemuDrive.imageType, on: newQemuDrive.interface!, copy: true)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func addNewDrive(_ newDrive: VMDriveImage) {
        newDrivePopover = false // hide popover
        data.busyWork {
            if let qemuConfig = config as? UTMQemuConfiguration {
                try data.createDrive(newDrive, for: qemuConfig)
            } else if let appleConfig = config as? UTMAppleConfiguration {
                // TODO: create drive
            }
        }
    }
}
