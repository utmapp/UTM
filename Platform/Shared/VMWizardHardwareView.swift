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

@available(iOS 14, macOS 11, *)
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
    
    var minMemory: UInt64 {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.minimumAllowedMemorySize
        #else
        UInt64(8 * wizardState.bytesInMib)
        #endif
    }
    
    var maxMemory: UInt64 {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.maximumAllowedMemorySize
        #else
        sysctlIntRead("hw.memsize")
        #endif
    }
    
    var body: some View {
        VStack {
            Text("Hardware")
                .font(.largeTitle)
            if !wizardState.useVirtualization {
                VMConfigStringPicker(selection: $wizardState.systemArchitecture, label: Text("Architecture"), rawValues: UTMQemuConfiguration.supportedArchitectures(), displayValues: UTMQemuConfiguration.supportedArchitecturesPretty())
                    .onChange(of: wizardState.systemArchitecture) { newValue in
                        let targets = UTMQemuConfiguration.supportedTargets(forArchitecture: newValue)
                        let index = UTMQemuConfiguration.defaultTargetIndex(forArchitecture: newValue)
                        wizardState.systemTarget = targets![index]
                    }
                #if !os(macOS)
                Text(wizardState.systemArchitecture ?? " ")
                    .font(.caption)
                #endif
                VMConfigStringPicker(selection: $wizardState.systemTarget, label: Text("System"), rawValues: UTMQemuConfiguration.supportedTargets(forArchitecture: wizardState.systemArchitecture), displayValues: UTMQemuConfiguration.supportedTargets(forArchitecturePretty: wizardState.systemArchitecture))
                #if !os(macOS)
                Text(wizardState.systemTarget ?? " ")
                    .font(.caption)
                #endif
            }
            RAMSlider(systemMemory: $wizardState.systemMemory) { _ in
                if wizardState.systemMemory < minMemory {
                    wizardState.systemMemory = minMemory
                } else if wizardState.systemMemory > maxMemory {
                    wizardState.systemMemory = maxMemory
                }
            }
            HStack {
                Stepper(value: $wizardState.systemCpuCount, in: minCores...maxCores) {
                    Text("CPU Cores")
                }
                NumberTextField("", number: $wizardState.systemCpuCount, onEditingChanged: { _ in
                    if wizardState.systemCpuCount < minCores {
                        wizardState.systemCpuCount = minCores
                    } else if wizardState.systemCpuCount > maxCores {
                        wizardState.systemCpuCount = maxCores
                    }
                })
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
            }
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                Toggle("Enable hardware OpenGL acceleration (experimental)", isOn: $wizardState.isGLEnabled)
            }
            Spacer()
        }.onAppear {
            if wizardState.systemArchitecture == nil {
                wizardState.systemArchitecture = "x86_64"
            }
        }
    }
    
    private func sysctlIntRead(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
}

@available(iOS 14, macOS 11, *)
struct VMWizardHardwareView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardHardwareView(wizardState: wizardState)
    }
}
