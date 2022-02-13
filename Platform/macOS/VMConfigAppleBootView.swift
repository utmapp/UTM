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

import Virtualization
import SwiftUI

@available(macOS 11, *)
struct VMConfigAppleBootView: View {
    private enum BootloaderSelection: Int, Identifiable {
        var id: Int {
            self.rawValue
        }
        case kernel
        case ramdisk
        case ipsw
        case unsupported
    }
    
    @ObservedObject var config: UTMAppleConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var operatingSystem: Bootloader.OperatingSystem?
    @State private var alertBootloaderSelection: BootloaderSelection?
    @State private var importBootloaderSelection: BootloaderSelection?
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
                guard newValue != nil else {
                    config.bootLoader = nil
                    if #available(macOS 12, *) {
                        config.macRecoveryIpswURL = nil
                        #if arch(arm64)
                        config.macPlatform = nil
                        #endif
                    }
                    return
                }
                if newValue == .Linux {
                    alertBootloaderSelection = .kernel
                } else if newValue == .macOS {
                    if #available(macOS 12, *) {
                        alertBootloaderSelection = .ipsw
                    } else {
                        alertBootloaderSelection = .unsupported
                    }
                }
                // don't change display until AFTER file selected
                importBootloaderSelection = nil
                operatingSystem = currentOperatingSystem
            }.alert(item: $alertBootloaderSelection) { selection in
                let okay = Alert.Button.default(Text("OK")) {
                    importBootloaderSelection = selection
                    importFileShown = true
                }
                switch selection {
                case .kernel:
                    return Alert(title: Text("Please select an uncompressed Linux kernel image."), dismissButton: okay)
                case .ipsw:
                    return Alert(title: Text("Please select a macOS recovery IPSW."), primaryButton: okay, secondaryButton: .cancel())
                case .unsupported:
                    return Alert(title: Text("This operating system is unsupported on your machine."))
                default:
                    return Alert(title: Text("Select a file."), dismissButton: okay)
                }
            }.fileImporter(isPresented: $importFileShown, allowedContentTypes: [.data], onCompletion: selectImportedFile)
            if operatingSystem == .Linux {
                Section(header: Text("Linux Settings")) {
                    HStack {
                        TextField("Kernel Image", text: .constant(config.bootLoader?.linuxKernelURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Browse") {
                            importBootloaderSelection = .kernel
                            importFileShown = true
                        }
                    }
                    HStack {
                        TextField("Ramdisk (optional)", text: .constant(config.bootLoader?.linuxInitialRamdiskURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Clear") {
                            config.bootLoader?.linuxInitialRamdiskURL = nil
                        }
                        Button("Browse") {
                            importBootloaderSelection = .ramdisk
                            importFileShown = true
                        }
                    }
                    TextField("Boot arguments", text: $config.linuxCommandLine)
                }
            } else if #available(macOS 12, *), operatingSystem == .macOS {
                #if arch(arm64)
                Section(header: Text("macOS Settings")) {
                    HStack {
                        TextField("IPSW Install Image", text: .constant(config.macRecoveryIpswURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Clear") {
                            config.macRecoveryIpswURL = nil
                        }
                        Button("Browse") {
                            importBootloaderSelection = .ipsw
                            importFileShown = true
                        }
                    }
                }
                #endif
            }
        }.onAppear {
            operatingSystem = currentOperatingSystem
        }
    }
    
    private func selectImportedFile(result: Result<URL, Error>) {
        // reset operating system to old value
        guard let selection = importBootloaderSelection else {
            return
        }
        data.busyWorkAsync {
            let url = try result.get()
            try await Task { @MainActor in
                switch selection {
                case .ipsw:
                    if #available(macOS 12, *) {
                        #if arch(arm64)
                        let image = try await VZMacOSRestoreImage.image(from: url)
                        guard let model = image.mostFeaturefulSupportedConfiguration?.hardwareModel else {
                            throw NSLocalizedString("Your machine does not support running this IPSW.", comment: "VMConfigAppleBootView")
                        }
                        config.macPlatform = MacPlatform(newHardware: model)
                        config.macRecoveryIpswURL = url
                        config.bootLoader = try Bootloader(for: .macOS)
                        #endif
                    }
                case .kernel:
                    config.bootLoader = try Bootloader(for: .Linux, linuxKernelURL: url)
                case .ramdisk:
                    config.bootLoader!.linuxInitialRamdiskURL = url
                case .unsupported:
                    break
                }
                operatingSystem = currentOperatingSystem
                switch operatingSystem {
                case .macOS:
                    config.isConsoleDisplay = false
                    config.isSerialEnabled = false
                case .Linux:
                    config.isConsoleDisplay = true
                    config.isSerialEnabled = true
                default:
                    break
                }
            }.value
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
