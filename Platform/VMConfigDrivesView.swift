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

#if os(macOS)
struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: importDrive, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(TitleOnlyLabelStyle())
                })
                Button(action: addNewDrive, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(TitleOnlyLabelStyle())
                })
            }
            if config.countDrives == 0 {
                Text("No drives added.").font(.headline)
            } else {
                ForEach(0..<config.countDrives, id: \.self) { index in
                    DriveCard(config: config, index: index)
                }
            }
        }.onDrop(of: [String(kUTTypeData)], isTargeted: nil, perform: handleDrop)
    }
    
    func handleDrop(fromProviders providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            //TODO: implement drag & drop
        }
        return false
    }
}

struct DriveCard: View {
    @ObservedObject var config: UTMConfiguration
    @State var index: Int
    
    var body: some View {
        GroupBox {
            VStack {
                Drive(config: config, index: index)
                HStack {
                    Button(action: deleteDrive, label: {
                        Label("Delete", systemImage: "trash").labelStyle(IconOnlyLabelStyle()).foregroundColor(.red)
                    })
                    Spacer()
                    if index != 0 {
                        Button(action: moveDriveUp, label: {
                            Label("Move Up", systemImage: "arrow.up").labelStyle(IconOnlyLabelStyle())
                        })
                    }
                    if index != config.countDrives - 1 {
                        Button(action: moveDriveDown, label: {
                            Label("Move Down", systemImage: "arrow.down").labelStyle(IconOnlyLabelStyle())
                        })
                    }
                }
            }
        }
    }
    
    func deleteDrive() {
        
    }
    
    func moveDriveUp() {
        withAnimation {
            config.moveDrive(index, to: index - 1)
        }
    }
    
    func moveDriveDown() {
        withAnimation {
            config.moveDrive(index, to: index + 1)
        }
    }
}
#else // iOS
struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    
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
                                destination: Drive(config: config, index: index).navigationTitle("Drive"), label: {
                                    VStack(alignment: .leading) {
                                        Text(fileName)
                                        HStack {
                                            Text(imageType.description).font(.caption)
                                            if imageType == .disk || imageType == .CD {
                                                Text("-")
                                                Text(interfaceType).font(.caption)
                                            }
                                        }
                                    }
                                })
                        }.onDelete(perform: deleteDrives)
                        .onMove(perform: moveDrives)
                    }
                }
            }
        }
        .navigationBarItems(trailing:
            HStack {
                EditButton()
                Divider()
                Button(action: importDrive, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(IconOnlyLabelStyle())
                })
                Divider()
                Button(action: addNewDrive, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
                })
            }
        )
    }
    
    private func deleteDrives(offsets: IndexSet) {
        for offset in offsets {
            config.removeDrive(at: offset)
        }
    }
    
    private func moveDrives(source: IndexSet, destination: Int) {
        for offset in source {
            config.moveDrive(offset, to: destination)
        }
    }
}
#endif

extension VMConfigDrivesView {
    private func addNewDrive() {
        withAnimation {
            //FIXME: implement this
            config.newDrive("test.img", type: .disk, interface: "ide")
            config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
        }
    }
    
    private func importDrive() {
        //FIXME: implement this
    }
}

private struct Drive: View {
    @ObservedObject var config: UTMConfiguration
    @State var index: Int
    @State private var removable = false //FIXME: implement this
    
    var body: some View {
        let fileName = config.driveImagePath(for: index) ?? ""
        let imageType = config.driveImageType(for: index)
        let imageTypeObserver = Binding<String?> {
            config.driveImageType(for: index).description
        } set: {
            config.setDrive(UTMDiskImageType.enumFromString($0), for: index)
        }
        let interfaceTypeObserver = Binding<String?> {
            config.driveInterfaceType(for: index)
        } set: {
            config.setDriveInterfaceType($0 ?? UTMConfiguration.defaultDriveInterface(), for: index)
        }
        return Form {
            Toggle(isOn: $removable, label: {
                Text("Removable")
            }).disabled(true)
            if !removable {
                Text(fileName)
            }
            VMConfigStringPicker(selection: imageTypeObserver, label: Text("Image Type"), rawValues: UTMConfiguration.supportedImageTypes(), displayValues: UTMConfiguration.supportedImageTypesPretty())
            if imageType == .disk || imageType == .CD {
                VMConfigStringPicker(selection: interfaceTypeObserver, label: Text("Interface"), rawValues: UTMConfiguration.supportedDriveInterfaces(), displayValues: UTMConfiguration.supportedDriveInterfaces())
            }
        }
    }
}

struct VMConfigDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMConfigDrivesView(config: config)
            #if !os(macOS)
            if config.countDrives > 0 {
                Drive(config: config, index: 0)
            }
            #endif
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("test.img", type: .disk, interface: "ide")
                config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
            }
        }
    }
}
