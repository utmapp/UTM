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
    private enum ClassicMacSystem: CaseIterable, Identifiable {
        case quadra800
        //case powerMacG3Beige
        case powerMacG4
        //case powerMacG5

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .quadra800: "Macintosh Quadra 800 (M68K)"
            //case .powerMacG3Beige: "Power Macintosh G3 (Beige)"
            case .powerMacG4: "Power Macintosh G4 (PPC)"
            //case .powerMacG5: "Power Macintosh G5 (PPC64)"
            }
        }

        var architecture: QEMUArchitecture {
            switch self {
            case .quadra800: return .m68k
            //case .powerMacG3Beige: return .ppc
            case .powerMacG4: return .ppc
            //case .powerMacG5: return .ppc64
            }
        }

        var target: any QEMUTarget {
            switch self {
            case .quadra800: return QEMUTarget_m68k.q800
            //case .powerMacG3Beige: return QEMUTarget_ppc.g3beige
            case .powerMacG4: return QEMUTarget_ppc.mac99
            //case .powerMacG5: return QEMUTarget_ppc.mac99
            }
        }

        var minRam: Int {
            switch self {
            case .quadra800: return 8
            //case .powerMacG3Beige: return 32
            case .powerMacG4: return 64
            //case .powerMacG5: return 64
            }
        }

        var maxRam: Int {
            switch self {
            case .quadra800: return 1024
            //case .powerMacG3Beige: return 2047
            case .powerMacG4: return 2048
            //case .powerMacG5: return 2048
            }
        }

        var defaultRam: Int {
            switch self {
            case .quadra800: return 128
            //case .powerMacG3Beige: return 512
            case .powerMacG4: return 512
            //case .powerMacG5: return 512
            }
        }
    }
    @ObservedObject var wizardState: VMWizardState
    @State private var classicMacSystem: ClassicMacSystem = .powerMacG4

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
            if !wizardState.useVirtualization && wizardState.operatingSystem != .ClassicMacOS {
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

            } else if wizardState.operatingSystem == .ClassicMacOS {
                Picker("Machine", selection: $classicMacSystem) {
                    ForEach(ClassicMacSystem.allCases) { system in
                        Text(system.title).tag(system)
                    }
                }.pickerStyle(.inline)
                .onChange(of: classicMacSystem) { newValue in
                    wizardState.systemArchitecture = newValue.architecture
                    wizardState.systemTarget = newValue.target
                    wizardState.systemMemoryMib = newValue.defaultRam
                    wizardState.systemCpuCount = 1
                    wizardState.storageSizeGib = 2
                }
            }
            Section {
                RAMSlider(systemMemory: $wizardState.systemMemoryMib) { _ in
                    let validMax = wizardState.operatingSystem == .ClassicMacOS ? classicMacSystem.maxRam : maxMemoryMib
                    if wizardState.systemMemoryMib > validMax {
                        wizardState.systemMemoryMib = validMax
                    }
                    let validMin = wizardState.operatingSystem == .ClassicMacOS ? classicMacSystem.minRam : 0
                    if wizardState.systemMemoryMib < validMin {
                        wizardState.systemMemoryMib = validMin
                    }
                }
            } header: {
                Text("Memory")
            }

            if wizardState.operatingSystem != .ClassicMacOS {
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
            }

            
            
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                DetailedSection("Disply Output", description: "There are known issues in some newer Linux drivers including black screen, broken compositing, and apps failing to render.") {
                    Toggle("Enable display output", isOn: $wizardState.isDisplayEnabled)
                        .onChange(of: wizardState.isDisplayEnabled) { newValue in
                            if !newValue {
                                wizardState.isGLEnabled = false
                            }
                        }
                    Toggle("Enable hardware OpenGL acceleration", isOn: $wizardState.isGLEnabled)
                        .disabled(!wizardState.isDisplayEnabled)
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
            if wizardState.operatingSystem == .ClassicMacOS {
                wizardState.systemArchitecture = classicMacSystem.architecture
                wizardState.systemTarget = classicMacSystem.target
                wizardState.systemMemoryMib = classicMacSystem.defaultRam
                wizardState.systemCpuCount = 1
                wizardState.storageSizeGib = 2
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
