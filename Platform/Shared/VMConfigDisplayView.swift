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
    @ObservedObject var config: UTMQemuConfiguration
    
    #if os(macOS)
    let displayTypePickerStyle = RadioGroupPickerStyle()
    let horizontalPaddingAmount: CGFloat? = nil
    #else
    let displayTypePickerStyle = DefaultPickerStyle()
    let horizontalPaddingAmount: CGFloat? = 0
    #endif
    
    var body: some View {
        VStack {
            Form {
                DefaultPicker("Type", selection: $config.displayConsoleOnly.animation()) {
                    Text("Full Graphics").tag(false)
                    Text("Console Only").tag(true)
                }.pickerStyle(displayTypePickerStyle)
                .disabled(UTMQemuConfiguration.supportedDisplayCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
                .onChange(of: config.displayConsoleOnly) { newConsoleOnly in
                    if newConsoleOnly {
                        if config.shareClipboardEnabled {
                            config.shareClipboardEnabled = false
                        }
                        if config.shareDirectoryEnabled {
                            config.shareDirectoryEnabled = false
                        }
                    }
                }
                if config.displayConsoleOnly {
                    VMConfigDisplayConsoleView(config: config)
                } else {
                    Section(header: Text("Hardware")) {
                        VMConfigStringPicker("Emulated Display Card", selection: $config.displayCard, rawValues: UTMQemuConfiguration.supportedDisplayCards(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedDisplayCards(forArchitecturePretty: config.systemArchitecture))
                    }
                    
                    DetailedSection("Auto Resolution", description: "Requires SPICE guest agent tools to be installed.") {
                        Toggle(isOn: $config.shareClipboardEnabled, label: { // share with clipboard setting
                            #if os(macOS)
                            Text("Resize display to window size automatically")
                            #else
                            Text("Resize display to screen size and orientation automatically")
                            #endif
                        })
                    }
                    
                    Section(header: Text("Scaling")) {
                        VMConfigStringPicker("Upscaling", selection: $config.displayUpscaler, rawValues: UTMQemuConfiguration.supportedScalers(), displayValues: UTMQemuConfiguration.supportedScalersPretty())
                        VMConfigStringPicker("Downscaling", selection: $config.displayDownscaler, rawValues: UTMQemuConfiguration.supportedScalers(), displayValues: UTMQemuConfiguration.supportedScalersPretty())
                        Toggle(isOn: $config.displayRetina, label: {
                            Text("Retina Mode")
                        })
                    }
                }
            }
        }.disableAutocorrection(true)
        .padding(.horizontal, horizontalPaddingAmount)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigDisplayView(config: config)
    }
}
