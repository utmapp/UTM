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
                Picker(selection: $config.displayConsoleOnly.animation(), label: Text("Type")) {
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
                    Section(header: Text("Hardware"), footer: EmptyView().padding(.bottom)) {
                        VMConfigStringPicker(selection: $config.displayCard, label: Text("Emulated Display Card"), rawValues: UTMQemuConfiguration.supportedDisplayCards(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedDisplayCards(forArchitecturePretty: config.systemArchitecture))
                    }
                    
                    // https://stackoverflow.com/a/59277022/15603854
                    #if !os(macOS)
                    Section(header: Text("Auto Resolution"), footer: Text("Requires SPICE guest agent tools to be installed.").fixedSize(horizontal: false, vertical: true).padding(.bottom)) {
                        Toggle(isOn: $config.displayFitScreen, label: {
                            Text("Resize display to screen size automatically")
                        })
                    }
                    #endif
                    
                    Section(header: Text("Scaling"), footer: EmptyView().padding(.bottom)) {
                        VMConfigStringPicker(selection: $config.displayUpscaler, label: Text("Upscaling"), rawValues: UTMQemuConfiguration.supportedScalers(), displayValues: UTMQemuConfiguration.supportedScalersPretty())
                        VMConfigStringPicker(selection: $config.displayDownscaler, label: Text("Downscaling"), rawValues: UTMQemuConfiguration.supportedScalers(), displayValues: UTMQemuConfiguration.supportedScalersPretty())
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
