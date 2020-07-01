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

struct VMRemovableDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        Group {
            HStack {
                Label("VM Total Size", systemImage: "internaldrive")
                Spacer()
                Text("12.6 GB") //FIXME: Replace with real size
            }
            if config.shareDirectoryEnabled {
                HStack {
                    Label("Shared Directory", systemImage: "externaldrive.badge.person.crop")
                    Spacer()
                    Text("/path/to/share").truncationMode(.head)
                    Button(action: clearShareDirectory, label: {
                        Text("Clear")
                    })
                    Button(action: selectShareDirectory, label: {
                        Text("Browse")
                    })
                }
            }
            ForEach(0..<config.countDrives, id: \.self) { index in
                let fileName = config.driveImagePath(for: index) ?? ""
                let imageType = config.driveImageType(for: index)
                let interface = config.driveInterfaceType(for: index) ?? ""
                if fileName == "" && (imageType == .CD || imageType == .disk) { // FIXME: new boolean setting
                    HStack {
                        Label("Interface: \(interface)", systemImage: imageType == .CD ? "opticaldiscdrive" : "externaldrive")
                        Spacer()
                        Text("/path/to/share").truncationMode(.head)
                        Button(action: { clearRemovableImage(index: index) }, label: {
                            Text("Clear")
                        })
                        Button(action: { selectRemovableImage(index: index) }, label: {
                            Text("Browse")
                        })
                    }
                }
            }
        }
    }
    
    private func selectShareDirectory() {
        // FIXME: implement
    }
    
    private func clearShareDirectory() {
        // FIXME: implement
    }
    
    private func selectRemovableImage(index: Int) {
        // FIXME: implement
    }
    
    private func clearRemovableImage(index: Int) {
        // FIXME: implement
    }
}

struct VMRemovableDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VStack {
            VMRemovableDrivesView(config: config)
        }.onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
