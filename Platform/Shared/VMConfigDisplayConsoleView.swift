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
    
    #if os(macOS)
    typealias PlatformColor = NSColor
    #else
    typealias PlatformColor = UIColor
    #endif
    
    private var textColor: Binding<Color> {
        Binding<Color> {
            if let consoleTextColor = config.consoleTextColor,
               let color = Color(hexString: consoleTextColor) {
                return color
            } else {
                return Color.white
            }
        } set: { newValue in
            config.consoleTextColor = PlatformColor(newValue).hexString
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
            config.consoleBackgroundColor = PlatformColor(newValue).hexString
        }
    }
        
    var body: some View {
        let fontSizeObserver = Binding<Int> {
            Int(truncating: config.consoleFontSize ?? 1)
        } set: {
            config.consoleFontSize = NSNumber(value: $0)
        }
        Section(header: Text("Style"), footer: EmptyView().padding(.bottom)) {
            VMConfigStringPicker(selection: $config.consoleTheme, label: Text("Theme"), rawValues: UTMQemuConfiguration.supportedConsoleThemes(), displayValues: UTMQemuConfiguration.supportedConsoleThemes())
            ColorPicker("Text Color", selection: textColor)
            ColorPicker("Background Color", selection: backgroundColor)
            VMConfigStringPicker(selection: $config.consoleFont, label: Text("Font"), rawValues: UTMQemuConfiguration.supportedConsoleFonts(), displayValues: UTMQemuConfiguration.supportedConsoleFonts())
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
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDisplayConsoleView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigDisplayConsoleView(config: config)
    }
}
