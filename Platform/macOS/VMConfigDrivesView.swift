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

struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var newDrivePopover: Bool = false
    @StateObject private var newDrive: VMDriveImage = VMDriveImage()
    @EnvironmentObject private var data: UTMData
    @Environment(\.importFiles) private var importFiles: ImportFilesAction
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: importDrive, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(TitleOnlyLabelStyle())
                })
                Button(action: { newDrivePopover.toggle() }, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(TitleOnlyLabelStyle())
                })
                .popover(isPresented: $newDrivePopover, arrowEdge: .bottom) {
                    VStack {
                        VMConfigDriveCreateView(driveImage: newDrive)
                        HStack {
                            Spacer()
                            Button(action: { addNewDrive(newDrive) }, label: {
                                Text("Create")
                            })
                        }
                    }.padding()
                }
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
    
    private func importDrive() {
        importFiles(singleOfType: [.item]) { ret in
            data.busyWork {
                switch ret {
                case .success(let url):
                    try data.importDrive(url, forConfig: config)
                    break
                case .failure(let err):
                    throw err
                case .none:
                    break
                }
            }
        }
    }
    
    private func addNewDrive(_ newDrive: VMDriveImage) {
        newDrivePopover = false // hide popover
        data.busyWork {
            try data.createDrive(newDrive, forConfig: config)
        }
    }
}

struct DriveCard: View {
    @ObservedObject var config: UTMConfiguration
    @State var index: Int
    
    var body: some View {
        GroupBox {
            VStack {
                VMConfigDriveDetailsView(config: config, index: index)
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

struct VMConfigDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMConfigDrivesView(config: config)
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("test.img", type: .disk, interface: "ide")
                config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
            }
        }
    }
}
