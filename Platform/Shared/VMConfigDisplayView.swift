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
struct VMConfigDisplayView: View {
    @Binding var config: UTMQemuConfigurationDisplay
    @Binding var system: UTMQemuConfigurationSystem
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    VMConfigConstantPicker("Emulated Display Card", selection: $config.hardware, type: system.architecture.displayDeviceType)
                }
                
                DetailedSection("Auto Resolution", description: "Requires SPICE guest agent tools to be installed.") {
                    Toggle(isOn: $config.isDynamicResolution, label: {
                        #if os(macOS)
                        Text("Resize display to window size automatically")
                        #else
                        Text("Resize display to screen size and orientation automatically")
                        #endif
                    })
                }
                
                Section(header: Text("Scaling")) {
                    VMConfigConstantPicker("Upscaling", selection: $config.upscalingFilter)
                    VMConfigConstantPicker("Downscaling", selection: $config.downscalingFilter)
                    Toggle(isOn: $config.isNativeResolution, label: {
                        Text("Retina Mode")
                    })
                }
            }
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationDisplay()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigDisplayView(config: $config, system: $system)
    }
}
