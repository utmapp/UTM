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
    var vm: UTMVirtualMachine
    @State private var settingsPresented: Bool = false
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack {
            Screenshot(image: vm.screenshot.image)
            Form {
                List {
                    VMRemovableDrivesView(config: vm.configuration)
                }
            }
        }.navigationTitle(vm.configuration.name)
        .toolbar {
            VMToolbar {
                settingsPresented.toggle()
            }
        }.sheet(isPresented: $settingsPresented) {
            NavigationView {
                VMSettingsView(config: vm.configuration) { _ in
                    data.busyWork() { try data.save(vm: vm) }
                }
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
        VMDetailsView(vm: UTMVirtualMachine(configuration: config, withDestinationURL: URL(fileURLWithPath: "")))
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
