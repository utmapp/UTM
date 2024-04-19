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
    @ObservedObject var wizardState: VMWizardState
    
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
                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemArchitecture)
                        .onChange(of: wizardState.systemArchitecture) { newValue in
                            wizardState.systemTarget = newValue.targetType.default
                        }
                } header: {
                    Text("Architecture")
                }
                
                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemTarget, type: wizardState.systemArchitecture.targetType)
                } header: {
                    Text("System")
                }

            }
            Section {
                RAMSlider(systemMemory: $wizardState.systemMemoryMib) { _ in
                    if wizardState.systemMemoryMib > maxMemoryMib {
                        wizardState.systemMemoryMib = maxMemoryMib
                    }
                }
            } header: {
                Text("Memory")
            }
            
            Section {
                HStack {
                    Stepper(value: $wizardState.systemCpuCount, in: minCores...maxCores) {
                        Text("CPU Cores")
                    }
                    NumberTextField("", number: $wizardState.systemCpuCount, prompt: "Default", onEditingChanged: { _ in
                        guard wizardState.systemCpuCount != 0  else {
                            return
                        }
                        if wizardState.systemCpuCount < minCores {
                            wizardState.systemCpuCount = minCores
                        } else if wizardState.systemCpuCount > maxCores {
                            wizardState.systemCpuCount = maxCores
                        }
                    })
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("CPU")
            }
            
            
            
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                DetailedSection("Hardware OpenGL Acceleration", description: "There are known issues in some newer Linux drivers including black screen, broken compositing, and apps failing to render.") {
                    Toggle("Enable hardware OpenGL acceleration", isOn: $wizardState.isGLEnabled)
                }
                
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if wizardState.useVirtualization {
                #if arch(arm64)
                wizardState.systemArchitecture = .aarch64
                #elseif arch(x86_64)
                wizardState.systemArchitecture = .x86_64
                #else
                #error("Unsupported architecture.")
                #endif
                wizardState.systemTarget = wizardState.systemArchitecture.targetType.default
            }
            if wizardState.legacyHardware && wizardState.systemArchitecture == .x86_64 {
                wizardState.systemTarget = QEMUTarget_x86_64.pc
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
