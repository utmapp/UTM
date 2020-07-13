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

struct VMConfigDriveDetailsView: View {
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

struct VMConfigDriveDetailsView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            if config.countDrives > 0 {
                VMConfigDriveDetailsView(config: config, index: 0)
            }
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("test.img", type: .disk, interface: "ide")
                config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
            }
        }
    }
}
