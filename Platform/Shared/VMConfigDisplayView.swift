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
    @ObservedObject var config: UTMConfiguration
    
    #if os(macOS)
    let displayTypePickerStyle = RadioGroupPickerStyle()
    #else
    let displayTypePickerStyle = DefaultPickerStyle()
    #endif
    
    var body: some View {
        VStack {
            Form {
                Picker(selection: $config.displayConsoleOnly.animation(), label: Text("Type")) {
                    Text("Full Graphics").tag(false)
                    Text("Console Only").tag(true)
                }.pickerStyle(displayTypePickerStyle)
                .disabled(UTMConfiguration.supportedDisplayCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
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
                    let fontSizeObserver = Binding<Int> {
                        Int(truncating: config.consoleFontSize ?? 1)
                    } set: {
                        config.consoleFontSize = NSNumber(value: $0)
                    }

                    Section(header: Text("Style"), footer: EmptyView().padding(.bottom)) {
                        VMConfigStringPicker(selection: $config.consoleTheme, label: Text("Theme"), rawValues: UTMConfiguration.supportedConsoleThemes(), displayValues: UTMConfiguration.supportedConsoleThemes())
                        VMConfigStringPicker(selection: $config.consoleFont, label: Text("Font"), rawValues: UTMConfiguration.supportedConsoleFonts(), displayValues: UTMConfiguration.supportedConsoleFonts())
                        HStack {
                            Stepper(value: fontSizeObserver, in: 1...72) {
                                    Text("Font Size")
                            }
                            NumberTextField("", number: $config.consoleFontSize)
                                .frame(width: 50)
                                .multilineTextAlignment(.trailing)
                        }
                        Toggle(isOn: $config.consoleCursorBlink, label: {
                            Text("Blinking Cursor")
                        })
                    }
                    
                    Section(header: Text("Resize Console Command"), footer: Text("Command to send when resizing the console. Placeholder $COLS is the number of columns and $ROWS is the number of rows.")) {
                        TextField("stty cols $COLS rows $ROWS\n", text: $config.consoleResizeCommand.bound)
                    }
                } else {
                    Section(header: Text("Hardware"), footer: EmptyView().padding(.bottom)) {
                        VMConfigStringPicker(selection: $config.displayCard, label: Text("Emulated Display Card"), rawValues: UTMConfiguration.supportedDisplayCards(forArchitecture: config.systemArchitecture), displayValues: UTMConfiguration.supportedDisplayCards(forArchitecturePretty: config.systemArchitecture))
                    }
                    
                    Section(header: Text("Resolution"), footer: Text("Requires SPICE guest agent tools to be installed. Retina Mode is recommended only if the guest OS supports HiDPI.").padding(.bottom)) {
                        Toggle(isOn: $config.displayFitScreen, label: {
                            Text("Fit To Screen")
                        })
                        Toggle(isOn: $config.displayRetina, label: {
                            Text("Retina Mode")
                        })
                    }
                    
                    Section(header: Text("Scaling"), footer: EmptyView().padding(.bottom)) {
                        VMConfigStringPicker(selection: $config.displayUpscaler, label: Text("Upscaling"), rawValues: UTMConfiguration.supportedScalers(), displayValues: UTMConfiguration.supportedScalersPretty())
                        VMConfigStringPicker(selection: $config.displayDownscaler, label: Text("Downscaling"), rawValues: UTMConfiguration.supportedScalers(), displayValues: UTMConfiguration.supportedScalersPretty())
                    }
                }
            }
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigDisplayView(config: config)
    }
}
