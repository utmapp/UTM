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
    private enum BootloaderSelection: Int, Identifiable {
        var id: Int {
            self.rawValue
        }
        case kernel
        case ipsw
    }
    
    @ObservedObject var config: UTMAppleConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var operatingSystem: Bootloader.OperatingSystem?
    @State private var selectedOperatingSystem: Bootloader.OperatingSystem?
    @State private var alertBootloaderSelection: BootloaderSelection?
    @State private var importFileShown: Bool = false
    
    private var currentOperatingSystem: Bootloader.OperatingSystem? {
        config.bootLoader?.operatingSystem
    }
    
    var body: some View {
        Form {
            Picker("Operating System", selection: $operatingSystem) {
                Text("None")
                    .tag(nil as Bootloader.OperatingSystem?)
                ForEach(Bootloader.OperatingSystem.allCases) { os in
                    Text(os.rawValue)
                        .tag(os as Bootloader.OperatingSystem?)
                }
            }.onChange(of: operatingSystem) { newValue in
                guard newValue != currentOperatingSystem else {
                    return
                }
                if newValue == .Linux {
                    alertBootloaderSelection = .kernel
                } else if newValue == .macOS {
                    alertBootloaderSelection = .ipsw
                }
                // don't change display until AFTER file selected
                selectedOperatingSystem = operatingSystem
                operatingSystem = currentOperatingSystem
            }.alert(item: $alertBootloaderSelection) { selection in
                let okay = Alert.Button.default(Text("OK")) {
                    importFileShown = true
                }
                switch selection {
                case .kernel:
                    return Alert(title: Text("Please select an uncompressed Linux kernel image."), dismissButton: okay)
                case .ipsw:
                    return Alert(title: Text("Please select a macOS recovery IPSW."), dismissButton: okay)
                }
            }.fileImporter(isPresented: $importFileShown, allowedContentTypes: [.data], onCompletion: selectImportedFile)
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
        }.onAppear {
            operatingSystem = currentOperatingSystem
        }
    }
    
    private func selectImportedFile(result: Result<URL, Error>) {
        // reset operating system to old value
        guard let selectedOperatingSystem = selectedOperatingSystem else {
            return
        }
        data.busyWork {
            let url = try result.get()
            DispatchQueue.main.async {
                config.bootLoader = Bootloader(for: selectedOperatingSystem)
                operatingSystem = currentOperatingSystem
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
