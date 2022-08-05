//
// Copyright © 2022 osy. All rights reserved.
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

struct VMConfigAppleSerialView: View {
    @Binding var config: UTMAppleConfigurationSerial
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Connection")) {
                    VMConfigConstantPicker("Mode", selection: $config.mode)
                        .onChange(of: config.mode) { newValue in
                            if newValue == .builtin && config.terminal == nil {
                                config.terminal = .init()
                            }
                        }
                }
                
                if config.mode == .builtin {
                    VMConfigDisplayConsoleView(config: $config.terminal.bound)
                }
            }
        }.disableAutocorrection(true)
        #if !os(macOS)
        .padding(.horizontal, 0)
        #endif
    }
}

struct VMConfigAppleSerialView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationSerial()
    
    static var previews: some View {
        VMConfigAppleSerialView(config: $config)
    }
}
