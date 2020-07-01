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

struct VMDetailsView: View {
    @ObservedObject var config: UTMConfiguration
    @Binding var editMode: Bool
    var screenshot: NSImage? = nil
    
    var body: some View {
        VStack {
            HStack {
                if editMode {
                    Label("Edit Icon", systemImage: "pencil")
                        .labelStyle(IconOnlyLabelStyle())
                        .font(.largeTitle)
                    TextField("Name", text: $config.name)
                        .font(.largeTitle)
                } else {
                    Text(config.name)
                        .font(.largeTitle)
                }
            }
            HStack(alignment: .top) {
                Screenshot(image: screenshot)
                VStack {
                    VMRemovableDrivesView(config: config)
                }
                Spacer()
            }
            Divider()
            VMSettingsView(config: config, editMode: $editMode)
        }
        .padding()
    }
}

struct Screenshot: View {
    var image: NSImage?
    
    var body: some View {
        Group {
            if image == nil {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            } else {
                Image(nsImage: image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            }
        }
    }
}

struct VMDetailsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMDetailsView(config: config, editMode: .constant(true))
        }.onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
