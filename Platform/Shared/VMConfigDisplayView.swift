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

struct VMConfigDisplayView: View {
    @Binding var config: UTMQemuConfigurationDisplay
    @Binding var system: UTMQemuConfigurationSystem
    
    var isGLSupported: Bool {
        config.hardware.rawValue.contains("-gl-") || config.hardware.rawValue.hasSuffix("-gl")
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    if system.target.hasBuiltinFramebuffer {
                        HStack {
                            Text("Emulated Display Card")
                            Spacer()
                            Text("Built-in Framebuffer")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VMConfigConstantPicker("Emulated Display Card", selection: $config.hardware, type: system.architecture.displayDeviceType)
                    }
                    
                    Toggle("GPU Acceleration Supported", isOn: .constant(isGLSupported)).disabled(true)
                    if isGLSupported {
                        Text("Guest drivers are required for 3D acceleration.")
                            .font(.footnote)
                    }
                    
                    if config.hardware.rawValue.contains("-vga") ||
                        config.hardware.rawValue == "VGA" ||
                        config.hardware.rawValue == "vmware-svga" {
                        NumberTextField("VGA Device RAM (MB)", number: $config.vgaRamMib.bound, prompt: "16")
                    }
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

struct VMConfigDisplayView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationDisplay()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigDisplayView(config: $config, system: $system)
    }
}
