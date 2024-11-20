//
// Copyright © 2022 osy. All rights reserved.
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

struct VMConfigAppleVirtualizationView: View {
    @Binding var config: UTMAppleConfigurationVirtualization
    let operatingSystem: UTMAppleConfigurationBoot.OperatingSystem
    
    var body: some View {
        Form {
            if operatingSystem == .linux {
                Toggle("Enable Balloon Device", isOn: $config.hasBalloon)
            }
            Toggle("Enable Entropy Device", isOn: $config.hasEntropy)
            if #available(macOS 12, *) {
                Toggle("Enable Sound", isOn: $config.hasAudio)
                VMConfigConstantPicker("Keyboard", selection: $config.keyboard)
                VMConfigConstantPicker("Pointer", selection: $config.pointer)
            }
            if #available(macOS 13, *), operatingSystem == .linux {
                #if arch(arm64)
                Toggle("Enable Rosetta on Linux (x86_64 Emulation)", isOn: $config.hasRosetta.bound)
                    .help("If enabled, a virtiofs share tagged 'rosetta' will be available on the Linux guest for installing Rosetta for emulating x86_64 on ARM64.")
                #endif
            }
            if #available(macOS 13, *) {
                Toggle("Enable Clipboard Sharing", isOn: $config.hasClipboardSharing)
                    .help("Requires SPICE guest agent tools to be installed.")
            }
        }
    }
}

struct VMConfigAppleDevicesView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationVirtualization()
    static var previews: some View {
        VMConfigAppleVirtualizationView(config: $config, operatingSystem: .linux)
    }
}
