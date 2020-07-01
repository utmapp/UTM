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
    @State private var settingsPresented: Bool = false
    var screenshot: UIImage? = nil
    
    var body: some View {
        VStack {
            Screenshot(image: screenshot)
            Form {
                List {
                    VMRemovableDrivesView(config: config)
                }
            }
        }.navigationTitle(config.name)
        .toolbar {
            VMToolbar {
                settingsPresented.toggle()
            }
        }.sheet(isPresented: $settingsPresented) {
            NavigationView {
                VMSettingsView(config: config)
            }
        }
    }
}

struct Screenshot: View {
    var image: UIImage?
    
    var body: some View {
        Group {
            if image == nil {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 400)
            } else {
                Image(uiImage: image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 400)
            }
        }
    }
}

struct VMDetailsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMDetailsView(config: config)
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
