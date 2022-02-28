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

struct VMAppleSettingsView: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMAppleConfiguration
    @Binding var selectedDriveIndex: Int?
    
    @State private var infoActive: Bool = true
    
    var body: some View {
        NavigationLink(destination: VMConfigInfoView(config: config).scrollable(), isActive: $infoActive) {
            Label("Information", systemImage: "info.circle")
        }
        NavigationLink(destination: VMConfigAppleSystemView(config: config).scrollable()) {
            Label("System", systemImage: "cpu")
        }
        NavigationLink(destination: VMConfigAppleBootView(config: config).scrollable()) {
            Label("Boot", systemImage: "power")
        }
        if #available(macOS 12, *) {
            NavigationLink(destination: VMConfigAppleDisplayView(config: config).scrollable()) {
                Label("Display", systemImage: "rectangle.on.rectangle")
            }
        } else {
            NavigationLink(destination: Form { VMConfigDisplayConsoleView(config: config) }.scrollable()) {
                Label("Display", systemImage: "rectangle.on.rectangle")
            }
        }
        NavigationLink(destination: VMConfigAppleNetworkingView(config: config).scrollable()) {
            Label("Network", systemImage: "network")
        }
        if #available(macOS 12, *), config.bootLoader?.operatingSystem == .Linux {
            NavigationLink(destination: VMConfigAppleSharingView(config: config).scrollable()) {
                Label("Sharing", systemImage: "person.crop.circle.fill")
            }
        }
        Section(header: Text("Drives")) {
            ForEach($config.diskImages) { $diskImage in
                NavigationLink(destination: VMConfigAppleDriveDetailsView(diskImage: $diskImage).scrollable(), tag: config.diskImages.firstIndex(of: diskImage)!, selection: $selectedDriveIndex) {
                    Label("\(diskImage.sizeString) Image", systemImage: "externaldrive")
                }
            }.onMove { indicies, dest in
                config.diskImages.move(fromOffsets: indicies, toOffset: dest)
            }
            VMConfigNewDriveButton(vm: vm, config: config)
                .buttonStyle(.link)
        }
    }
}

struct VMAppleSettingsView_Previews: PreviewProvider {
    @StateObject static var config = UTMAppleConfiguration()
    static var previews: some View {
        VMAppleSettingsView(vm: nil, config: config, selectedDriveIndex: .constant(nil))
    }
}
