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

struct VMConfigDisplayConsoleView: View {
    @Binding var config: UTMConfigurationTerminal
    
    private var textColor: Binding<Color> {
        Binding<Color> {
            if let consoleTextColor = config.foregroundColor,
               let color = Color(hexString: consoleTextColor) {
                return color
            } else {
                return Color.white
            }
        } set: { newValue in
            config.foregroundColor = newValue.cgColor!.hexString
        }
    }
    private var backgroundColor: Binding<Color> {
        Binding<Color> {
            if let consoleBackgroundColor = config.backgroundColor,
               let color = Color(hexString: consoleBackgroundColor) {
                return color
            } else {
                return Color.black
            }
        } set: { newValue in
            config.backgroundColor = newValue.cgColor!.hexString
        }
    }
        
    var body: some View {
        Section(header: Text("Style")) {
            VMConfigConstantPicker("Theme", selection: $config.theme.bound)
            ColorPicker("Text Color", selection: textColor)
            ColorPicker("Background Color", selection: backgroundColor)
            VMConfigConstantPicker("Font", selection: $config.font)
            HStack {
                Stepper(value: $config.fontSize, in: 1...72) {
                        Text("Font Size")
                }
                NumberTextField("", number: $config.fontSize, prompt: "12")
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
            }
            Toggle("Blinking cursor?", isOn: $config.hasCursorBlink)
        }
        
        DetailedSection("Resize Console Command", description: "Command to send when resizing the console. Placeholder $COLS is the number of columns and $ROWS is the number of rows.") {
            DefaultTextField("", text: $config.resizeCommand.bound, prompt: "stty cols $COLS rows $ROWS\n")
        }
    }
}

struct VMConfigDisplayConsoleView_Previews: PreviewProvider {
    @State static private var config = UTMConfigurationTerminal()
    
    static var previews: some View {
        VMConfigDisplayConsoleView(config: $config)
    }
}
