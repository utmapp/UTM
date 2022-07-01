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

struct VMConfigNewDriveButton<Drive: UTMConfigurationDrive>: View {
    @Binding var drives: [Drive]
    let template: Drive
    @State var newDrive: Drive
    @EnvironmentObject private var data: UTMData
    @State private var newDrivePopover: Bool = false
    @State private var importDrivePresented: Bool = false
    
    init(drives: Binding<[Drive]>, template: Drive) {
        self._drives = drives
        self._newDrive = State<Drive>(initialValue: template)
        self.template = template
    }

    var body: some View {
        Button {
            newDrivePopover.toggle()
        } label: {
            Label("New Drive", systemImage: "externaldrive.badge.plus")
        }
        .buttonStyle(.link)
        .help("Add a new drive.")
        .fileImporter(isPresented: $importDrivePresented, allowedContentTypes: [.item], onCompletion: importDrive)
        .onChange(of: newDrivePopover, perform: { showPopover in
            if showPopover {
                newDrive = template.clone()
            }
        })
        .popover(isPresented: $newDrivePopover, arrowEdge: .top) {
            VStack {
                // Ugly hack to coerce generic type to one of two binding types
                if newDrive is UTMQemuConfigurationDrive {
                    VMConfigDriveCreateView(config: $newDrive as Any as! Binding<UTMQemuConfigurationDrive>)
                } else if newDrive is UTMAppleConfigurationDrive {
                    VMConfigAppleDriveCreateView(config: $newDrive as Any as! Binding<UTMAppleConfigurationDrive>)
                } else {
                    fatalError("Unsupported drive type")
                }
                HStack {
                    Spacer()
                    Button(action: { importDrivePresented.toggle() }, label: {
                        if newDrive is UTMQemuConfigurationDrive && newDrive.isExternal {
                            Text("Browse…")
                        } else {
                            Text("Import…")
                        }
                    }).help("Select an existing disk image.")
                    Button(action: { addNewDrive(newDrive) }, label: {
                        Text("Create")
                    }).help("Create an empty drive.")
                }
            }.padding()
        }
    }

    private func importDrive(result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                let name = url.lastPathComponent
                if await drives.contains(where: { image in
                    image.imageURL?.lastPathComponent == name
                }) {
                    throw NSLocalizedString("An image already exists with that name.", comment: "VMConfigDrivesButton")
                }
                DispatchQueue.main.async {
                    newDrive.imageURL = url
                    drives.append(newDrive)
                }
                break
            case .failure(let err):
                throw err
            }
        }
    }

    private func addNewDrive(_ newDrive: Drive) {
        newDrivePopover = false // hide popover
        data.busyWorkAsync {
            DispatchQueue.main.async {
                drives.append(newDrive)
            }
        }
    }
}


struct VMConfigDrivesMoveButtons: View {
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var selectedDriveIndex: Int?
    
    var countDrives: Int {
        if true { //FIXME: need to merge with apple config
            return config.drives.count
        } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
            return appleConfig.diskImages.count
        } else {
            return 0
        }
    }
    
    var body: some View {
        Group {
            if #available(macOS 12, *) {
                if let index = selectedDriveIndex {
                    if index != 0 {
                        Button {
                            moveDriveUp(fromIndex: index)
                        } label: {
                            Label("Move Up", systemImage: "chevron.up")
                        }.help("Make boot order priority higher.")
                    }
                    if index != countDrives - 1 {
                        Button {
                            moveDriveDown(fromIndex: index)
                        } label: {
                            Label("Move Down", systemImage: "chevron.down")
                        }.help("Make boot order priority lower.")
                    }
                }
            } else { // SwiftUI BUG: macOS 11 doesn't support the conditional views above
                Button {
                    moveDriveUp(fromIndex: selectedDriveIndex!)
                } label: {
                    Label("Move Up", systemImage: "chevron.up")
                }.help("Make boot order priority higher.")
                .disabled(selectedDriveIndex == nil || selectedDriveIndex == 0)
                Button {
                    moveDriveDown(fromIndex: selectedDriveIndex!)
                } label: {
                    Label("Move Down", systemImage: "chevron.down")
                }.help("Make boot order priority lower.")
                .disabled(selectedDriveIndex == nil || selectedDriveIndex == countDrives - 1)
            }
        }.labelStyle(.titleOnly)
    }
    
    func moveDriveUp(fromIndex index: Int) {
        withAnimation {
            if true {  //FIXME: need to merge with apple config
                config.drives.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
                appleConfig.diskImages.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            }
            selectedDriveIndex = index - 1
        }
    }
    
    func moveDriveDown(fromIndex index: Int) {
        withAnimation {
            if true { //FIXME: need to merge with apple config
                config.drives.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
                appleConfig.diskImages.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            }
            selectedDriveIndex = index + 1
        }
    }
}
