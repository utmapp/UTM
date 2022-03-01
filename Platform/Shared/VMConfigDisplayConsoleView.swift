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

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayConsoleView<Config: ObservableObject & UTMConfigurable>: View {
    @ObservedObject var config: Config
    
    private var textColor: Binding<Color> {
        Binding<Color> {
            if let consoleTextColor = config.consoleTextColor,
               let color = Color(hexString: consoleTextColor) {
                return color
            } else {
                return Color.white
            }
        } set: { newValue in
            config.consoleTextColor = newValue.cgColor!.hexString
        }
    }
    private var backgroundColor: Binding<Color> {
        Binding<Color> {
            if let consoleBackgroundColor = config.consoleBackgroundColor,
               let color = Color(hexString: consoleBackgroundColor) {
                return color
            } else {
                return Color.black
            }
        } set: { newValue in
            config.consoleBackgroundColor = newValue.cgColor!.hexString
        }
    }
        
    var body: some View {
        let fontSizeObserver = Binding<Int> {
            Int(truncating: config.consoleFontSize ?? 1)
        } set: {
            config.consoleFontSize = NSNumber(value: $0)
        }
        Section(header: Text("Style")) {
            VMConfigStringPicker("Theme", selection: $config.consoleTheme, rawValues: UTMQemuConfiguration.supportedConsoleThemes(), displayValues: UTMQemuConfiguration.supportedConsoleThemes())
            ColorPicker("Text Color", selection: textColor)
            ColorPicker("Background Color", selection: backgroundColor)
            VMConfigStringPicker("Font", selection: $config.consoleFont, rawValues: UTMQemuConfiguration.supportedConsoleFonts(), displayValues: UTMQemuConfiguration.supportedConsoleFontsPretty())
            HStack {
                Stepper(value: fontSizeObserver, in: 1...72) {
                        Text("Font Size")
                }
                NumberTextField("", number: $config.consoleFontSize, prompt: "12")
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
            }
            Toggle(isOn: $config.consoleCursorBlink, label: {
                Text("Blinking Cursor")
            })
        }
        
        DetailedSection("Resize Console Command", description: "Command to send when resizing the console. Placeholder $COLS is the number of columns and $ROWS is the number of rows.") {
            DefaultTextField("", text: $config.consoleResizeCommand.bound, prompt: "stty cols $COLS rows $ROWS\n")
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayConsoleView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigDisplayConsoleView(config: config)
    }
}
