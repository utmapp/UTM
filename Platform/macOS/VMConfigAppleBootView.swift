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
struct VMConfigAppleBootView: View {
    @ObservedObject var config: UTMAppleConfiguration
    @State private var operatingSystem: Bootloader.OperatingSystem?
    
    var body: some View {
        Form {
            Picker("Operating System", selection: $operatingSystem) {
                Text("None")
                    .tag(nil as Bootloader.OperatingSystem?)
                ForEach(Bootloader.OperatingSystem.allCases) { os in
                    Text(os.rawValue)
                        .tag(os as Bootloader.OperatingSystem?)
                }
            }
            if operatingSystem == .Linux {
                Section(header: Text("Linux Settings")) {
                    HStack {
                        TextField("Kernel Image", text: .constant("(none)"))
                        Button("Browse") {
                            
                        }
                    }
                    HStack {
                        TextField("Ramdisk (optional)", text: .constant("(none)"))
                        Button("Clear") {
                            
                        }
                        Button("Browse") {
                            
                        }
                    }
                    TextField("Boot arguments", text: .constant(""))
                }
            } else if operatingSystem == .macOS {
                Section(header: Text("macOS Settings")) {
                    HStack {
                        TextField("IPSW Image", text: .constant("(none)"))
                        Button("Browse") {
                            
                        }
                    }
                }
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleBootView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMConfigAppleSystemView(config: config)
    }
}
