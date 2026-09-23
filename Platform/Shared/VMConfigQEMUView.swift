//
// Copyright © 2020 osy. All rights reserved.
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

struct VMConfigQEMUView: View {
    @ObservedObject var config: UTMQemuConfiguration
    #if os(macOS)
    @Binding var isCustomArgumentsEnabled: Bool
    #endif
    @State private var showExportLog: Bool = false
    
    private var logExists: Bool {
        guard let debugLogURL = config.qemu.debugLogURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: debugLogURL.path)
    }
    
    private var supportsUefi: Bool {
        UTMQemuConfigurationQEMU.uefiImagePrefix(forArchitecture: config.system.architecture) != nil
    }
    
    private var supportsPs2: Bool {
        if config.system.target.rawValue.starts(with: "pc") || config.system.target.rawValue.starts(with: "q35") {
            return true
        } else {
            return false
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Logging")) {
                    Toggle(isOn: $config.qemu.hasDebugLog, label: {
                        Text("Debug Logging")
                    })
                    Button("Export Debug Log") {
                        showExportLog.toggle()
                    }.modifier(VMShareItemModifier(isPresented: $showExportLog, shareItem: exportDebugLog()))
                    .disabled(!logExists)
                }
                DetailedSection("Tweaks", description: "These are advanced settings affecting QEMU which should be kept default unless you are running into issues.") {
                    Toggle("UEFI Boot", isOn: $config.qemu.hasUefiBoot)
                        .disabled(!supportsUefi)
                        .help("Should be off for older operating systems such as Windows 7 or lower.")
                    Toggle("RNG Device", isOn: $config.qemu.hasRNGDevice)
                        .help("Should be on always unless the guest cannot boot because of this.")
                    Toggle("Balloon Device", isOn: $config.qemu.hasBalloonDevice)
                        .help("Should be on always unless the guest cannot boot because of this.")
                    Toggle("TPM 2.0 Device", isOn: $config.qemu.hasTPMDevice)
                        .help("TPM can be used to protect secrets in the guest operating system. Note that the host will always be able to read these secrets and therefore no expectation of physical security is provided.")
                        .onChange(of: config.qemu.hasTPMDevice) { newValue in
                            if newValue {
                                config.qemu.isUefiVariableResetRequested = true
                                config.qemu.hasPreloadedSecureBootKeys = true
                            } else {
                                config.qemu.hasPreloadedSecureBootKeys = false
                            }
                        }
                    Toggle("Use Hypervisor", isOn: $config.qemu.hasHypervisor)
                        .help("Only available if host architecture matches the target. Otherwise, TCG emulation is used.")
                        .disabled(!config.system.architecture.hasHypervisorSupport)
                    if config.qemu.hasHypervisor {
                        Toggle("Use TSO", isOn: $config.qemu.hasTSO)
                            .help("Only available when Hypervisor is used on supported hardware. TSO speeds up Intel emulation in the guest at the cost of decreased performance in general.")
                            .disabled(!config.system.architecture.hasTSOSupport)
                    }
                    Toggle("Use local time for base clock", isOn: $config.qemu.hasRTCLocalTime)
                        .help("If checked, use local time for RTC which is required for Windows. Otherwise, use UTC clock.")
                    Toggle("Force PS/2 controller", isOn: $config.qemu.hasPS2Controller)
                        .disabled(!supportsPs2)
                        .help("Instantiate PS/2 controller even when USB input is supported. Required for older Windows.")
                }
                DetailedSection("Maintenance", description: "Options here only apply on next boot and are not saved.") {
                    Toggle("Reset UEFI Variables", isOn: $config.qemu.isUefiVariableResetRequested)
                        .help("You can use this if your boot options are corrupted or if you wish to re-enroll in the default keys for secure boot.")
                        .disabled(!config.qemu.hasUefiBoot)
                    Toggle("Preload Secure Boot Keys", isOn: $config.qemu.hasPreloadedSecureBootKeys)
                        .help("Enable Secure Boot with Microsoft UEFI keys. This is required to Secure Boot Windows.")
                        .disabled(!config.qemu.isUefiVariableResetRequested || !config.qemu.hasTPMDevice)
                        .onChange(of: config.qemu.isUefiVariableResetRequested) { newValue in
                            if !newValue {
                                config.qemu.hasPreloadedSecureBootKeys = false
                            }
                        }
                }
                DetailedSection("QEMU Machine Properties", description: "This is appended to the -machine argument.") {
                    DefaultTextField("", text: $config.qemu.machinePropertyOverride.bound, prompt: "Default")
                }
                #if os(macOS)
                DetailedSection("Custom Arguments", description: "Custom arguments are for debugging only. Compatibility with future versions is not guaranteed.") {
                    Toggle("Use Custom Arguments", isOn: $isCustomArgumentsEnabled)
                        .onChange(of: isCustomArgumentsEnabled) { newValue in
                            if !newValue {
                                config.qemu.additionalArguments.removeAll()
                            }
                        }
                }
                #else
                Section(footer: Text("Custom arguments are for debugging only. Compatibility with future versions is not guaranteed.")) {
                    NavigationLink("Arguments") {
                        VMConfigQEMUArgumentsView(config: config)
                            .navigationTitle("Arguments")
                    }
                }
                #endif
            }
            .disableAutocorrection(true)
        }
    }
    
    private func exportDebugLog() -> VMShareItemModifier.ShareItem? {
        guard let srcLogPath = config.qemu.debugLogURL else {
            return nil
        }
        return .debugLog(srcLogPath)
    }
}

struct VMConfigQEMUView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        #if os(macOS)
        VMConfigQEMUView(config: config, isCustomArgumentsEnabled: .constant(false))
            .frame(minHeight: 500)
        #else
        VMConfigQEMUView(config: config)
            .frame(minHeight: 500)
        #endif
    }
}
