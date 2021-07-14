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
    @ObservedObject var config: UTMAppleConfiguration
    @State private var isConsoleMode: Bool = false
    @State private var resolution = Display.Resolution(width: 1920, height: 1200)
    @State private var isHidpi: Bool = false
    
    var body: some View {
        Form {
            Picker("Display Mode", selection: $isConsoleMode) {
                Text("Console Mode")
                    .tag(true)
                Text("Full Graphics")
                    .tag(false)
            }
            if isConsoleMode {
                VMConfigDisplayConsoleView(config: config)
            } else {
                Picker("Resolution", selection: $resolution) {
                    Text("1920x1200")
                        .tag(Display.Resolution(width: 1920, height: 1200))
                }
                Toggle("HiDPI (Retina)", isOn: $isHidpi)
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
