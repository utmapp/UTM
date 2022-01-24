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
    
    var body: some View {
        let fontSizeObserver = Binding<Int> {
            Int(truncating: config.consoleFontSize ?? 1)
        } set: {
            config.consoleFontSize = NSNumber(value: $0)
        }
        Section(header: Text("Style"), footer: EmptyView().padding(.bottom)) {
            VMConfigStringPicker(selection: $config.consoleTheme, label: Text("Theme"), rawValues: UTMQemuConfiguration.supportedConsoleThemes(), displayValues: UTMQemuConfiguration.supportedConsoleThemes())
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
