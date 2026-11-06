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
    
    private var displayDeviceType: any QEMUDisplayDevice.Type {
        system.architecture.displayDeviceType
    }
    
    private var isGLEnabled: Bool {
        Self.isGLVariant(config.hardware.rawValue)
    }
    
    private var hasGLVariant: Bool {
        glVariant(of: baseModel(of: config.hardware.rawValue)) != nil
    }
    
    /// Models shown in the picker with the GL variants filtered out
    private var baseModels: [String] {
        displayDeviceType.allRawValues.filter { baseModel(of: $0) == $0 }
    }
    
    private var baseModelSelection: Binding<String> {
        Binding {
            baseModel(of: config.hardware.rawValue)
        } set: { newValue in
            guard newValue != baseModel(of: config.hardware.rawValue) else {
                return
            }
            // default to GPU acceleration when the new model supports it
            setHardware(glVariant(of: newValue) ?? newValue)
        }
    }
    
    private var glEnabledSelection: Binding<Bool> {
        Binding {
            isGLEnabled
        } set: { newValue in
            let base = baseModel(of: config.hardware.rawValue)
            if newValue, let gl = glVariant(of: base) {
                setHardware(gl)
            } else if !newValue {
                setHardware(base)
            }
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    Picker("Emulated Display Card", selection: baseModelSelection) {
                        ForEach(baseModels, id: \.self) { model in
                            Text(prettyValue(of: model)).tag(model)
                        }
                    }
                    
                    if hasGLVariant {
                        Toggle("GPU Acceleration", isOn: glEnabledSelection)
                    }
                    if isGLEnabled {
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
    
    private static func isGLVariant(_ rawValue: String) -> Bool {
        rawValue.contains("-gl-") || rawValue.hasSuffix("-gl")
    }
    
    private static func stripGL(_ rawValue: String) -> String {
        if rawValue.hasSuffix("-gl") {
            return String(rawValue.dropLast(3))
        } else {
            return rawValue.replacingOccurrences(of: "-gl-", with: "-")
        }
    }
    
    /// Returns the non-GL model for a GL variant, or the model itself if there is none
    private func baseModel(of rawValue: String) -> String {
        guard Self.isGLVariant(rawValue) else {
            return rawValue
        }
        let base = Self.stripGL(rawValue)
        return displayDeviceType.allRawValues.contains(base) ? base : rawValue
    }
    
    private func glVariant(of base: String) -> String? {
        displayDeviceType.allRawValues.first { rawValue in
            rawValue != base && Self.isGLVariant(rawValue) && Self.stripGL(rawValue) == base
        }
    }
    
    private func prettyValue(of rawValue: String) -> String {
        guard let index = displayDeviceType.allRawValues.firstIndex(of: rawValue) else {
            return rawValue
        }
        return displayDeviceType.allPrettyValues[index]
    }
    
    private func setHardware(_ rawValue: String) {
        config.hardware = displayDeviceType.init(rawValue: rawValue)!
    }
}

struct VMConfigDisplayView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationDisplay()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigDisplayView(config: $config, system: $system)
    }
}
