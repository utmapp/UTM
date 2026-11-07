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
#if canImport(Virtualization)
import Virtualization
#endif

struct VMWizardHardwareView: View {
    private typealias SupportedMachine = VMWizardState.SupportedMachine
    
    @ObservedObject var wizardState: VMWizardState
    @State private var isExpertMode: Bool = false
    @State private var selectedMachine: SupportedMachine?

    var minCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
        #else
        1
        #endif
    }
    
    var maxCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.maximumAllowedCPUCount
        #else
        Int(sysctlIntRead("hw.ncpu"))
        #endif
    }
    
    var minMemoryMib: Int {
        #if canImport(Virtualization)
        Int(VZVirtualMachineConfiguration.minimumAllowedMemorySize / UInt64(wizardState.bytesInMib))
        #else
        8
        #endif
    }
    
    var maxMemoryMib: Int {
        #if canImport(Virtualization)
        Int(VZVirtualMachineConfiguration.maximumAllowedMemorySize / UInt64(wizardState.bytesInMib))
        #else
        sysctlIntRead("hw.memsize")
        #endif
    }
    
    var body: some View {
        VMWizardContent("Hardware") {
            if !wizardState.useVirtualization {
                Toggle("Expert Mode", isOn: $isExpertMode)
                    .help("List all supported hardware. May require manual configuration to boot.")
            }
            if !wizardState.useVirtualization && isExpertMode {
                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemArchitecture)
                        .onChange(of: wizardState.systemArchitecture) { newValue in
                            wizardState.setSystemArchitecture(newValue)
                        }
                } header: {
                    Text("Architecture")
                }
                
                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemTarget, type: wizardState.systemArchitecture.targetType)
                } header: {
                    Text("System")
                }

            } else if !isExpertMode {
                Picker("Machine", selection: $selectedMachine) {
                    ForEach(SupportedMachine.allCases.filter({ $0.isSupported(running: wizardState.operatingSystem )})) { system in
                        Text(system.title).tag(system)
                    }
                }.pickerStyle(.inline)
                .onChange(of: selectedMachine) { newValue in
                    guard let newValue = newValue else {
                        return
                    }
                    wizardState.applyMachine(newValue)
                }
            }
            Section {
                RAMSlider(systemMemory: $wizardState.systemMemoryMib) { _ in
                    wizardState.clampSystemMemory(for: selectedMachine, hostMaximumMib: maxMemoryMib)
                }
            } header: {
                Text("Memory")
            }

            if isExpertMode || selectedMachine?.maxSupportedCores == 0 {
                Section {
                    HStack {
                        Stepper(value: $wizardState.systemCpuCount, in: minCores...maxCores) {
                            Text("CPU Cores")
                        }
                        NumberTextField("", number: $wizardState.systemCpuCount, prompt: "Default", onEditingChanged: { _ in
                            wizardState.clampSystemCpuCount(in: minCores...maxCores)
                        })
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("CPU")
                }
            }

            
            
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                DetailedSection("Display Output", description: "There are known issues in some newer Linux drivers including black screen, broken compositing, and apps failing to render.") {
                    Toggle("Enable display output", isOn: $wizardState.isDisplayEnabled)
                        .onChange(of: wizardState.isDisplayEnabled) { newValue in
                            wizardState.setDisplayEnabled(newValue)
                        }
                    Toggle("Enable hardware OpenGL acceleration", isOn: $wizardState.isGLEnabled)
                        .disabled(!wizardState.isDisplayEnabled)
                }
            }

            if !wizardState.useVirtualization && isExpertMode {
                Section {
                    Toggle("Legacy Hardware", isOn: $wizardState.legacyHardware)
                        .help("If checked, emulated devices with higher compatibility will be instantiated at the cost of performance.")
                } header: {
                    Text("Options")
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if wizardState.useVirtualization {
                isExpertMode = true
                selectedMachine = nil
                wizardState.prepareVirtualizedHardware()
            } else if selectedMachine == nil {
                let machine = SupportedMachine.default(for: wizardState.operatingSystem)
                selectedMachine = machine
                wizardState.applyMachine(machine)
            }
        }
    }
    
    private func sysctlIntRead(_ name: String) -> Int {
        var value: Int = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
}

struct VMWizardHardwareView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardHardwareView(wizardState: wizardState)
    }
}
