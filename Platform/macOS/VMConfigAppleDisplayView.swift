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

@available(macOS 12, *)
struct VMConfigAppleDisplayView: View {
    private let defaultResolution = Display.Resolution(width: 1920, height: 1200)
    
    @ObservedObject var config: UTMAppleConfiguration
    
    private var displayResolution: Binding<Display.Resolution> {
        Binding<Display.Resolution> {
            if let display = config.displays.first {
                return Display.Resolution(width: display.widthInPixels, height: display.heightInPixels)
            } else {
                return defaultResolution
            }
        } set: { newValue in
            var newDisplay: Display
            if config.displays.isEmpty {
                newDisplay = Display(for: newValue, isHidpi: false)
            } else {
                newDisplay = config.displays.first!
                newDisplay.widthInPixels = newValue.width
                newDisplay.heightInPixels = newValue.height
            }
            config.displays = [newDisplay]
        }
    }
    
    private var isHidpi: Binding<Bool> {
        Binding<Bool> {
            if let display = config.displays.first {
                return display.pixelsPerInch >= 226
            } else {
                return false
            }
        } set: { newValue in
            var newDisplay: Display
            if config.displays.isEmpty {
                newDisplay = Display(for: defaultResolution, isHidpi: newValue)
            } else {
                newDisplay = config.displays.first!
                newDisplay.pixelsPerInch = newValue ? 226 : 80
            }
            config.displays = [newDisplay]
        }
    }
    
    var body: some View {
        Form {
            Picker("Display Mode", selection: $config.isSerialEnabled) {
                Text("Console Mode")
                    .tag(true)
                Text("Full Graphics")
                    .tag(false)
            }
            if config.isSerialEnabled {
                VMConfigDisplayConsoleView(config: config)
            } else {
                Picker("Resolution", selection: displayResolution) {
                    Text("1920x1200")
                        .tag(defaultResolution)
                    Text("1680x1050")
                        .tag(Display.Resolution(width: 1680, height: 1050))
                    Text("1280x800")
                        .tag(Display.Resolution(width: 1280, height: 800))
                    Text("1024x640")
                        .tag(Display.Resolution(width: 1024, height: 640))
                }
                Toggle("HiDPI (Retina)", isOn: isHidpi)
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleDisplayView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMConfigAppleDisplayView(config: config)
    }
}
