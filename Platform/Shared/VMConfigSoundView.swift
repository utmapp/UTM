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

struct VMConfigSoundView: View {
    @Binding var config: UTMQemuConfigurationSound
    @Binding var system: UTMQemuConfigurationSystem
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    VMConfigConstantPicker("Emulated Audio Card", selection: $config.hardware, type: system.architecture.soundDeviceType)
                    #if !os(macOS)
                    if config.hardware.rawValue == "screamer" || config.hardware.rawValue == "pcspk" {
                        Text("This audio card is not supported.")
                            .foregroundColor(.red)
                    }
                    #endif
                }
            }
        }
    }
}

struct VMConfigSoundView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationSound()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigSoundView(config: $config, system: $system)
    }
}
