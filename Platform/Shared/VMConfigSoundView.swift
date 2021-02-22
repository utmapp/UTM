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

@available(iOS 14, macOS 11, *)
struct VMConfigSoundView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware"), footer: EmptyView().padding(.bottom)) {
                    Toggle(isOn: $config.soundEnabled.animation(), label: {
                        Text("Enabled")
                    })
                    if config.soundEnabled {
                        VMConfigStringPicker(selection: $config.soundCard, label: Text("Emulated Audio Card"), rawValues: UTMConfiguration.supportedSoundCards(forArchitecture: config.systemArchitecture), displayValues: UTMConfiguration.supportedSoundCards(forArchitecturePretty: config.systemArchitecture))
                    }
                }.disabled(UTMConfiguration.supportedSoundCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigSoundView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigSoundView(config: config)
    }
}
