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
import Virtualization

struct VMConfigAppleSystemView: View {
    private let bytesInMib = UInt64(1048576)
    
    @Binding var config: UTMAppleConfigurationSystem
    
    var minCores: Int {
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
    }
    
    var maxCores: Int {
        VZVirtualMachineConfiguration.maximumAllowedCPUCount
    }
    
    var minMemory: Int {
        Int(VZVirtualMachineConfiguration.minimumAllowedMemorySize / bytesInMib)
    }
    
    var maxMemory: Int {
        Int(VZVirtualMachineConfiguration.maximumAllowedMemorySize / bytesInMib)
    }
    
    var body: some View {
        Form {
            HStack {
                Stepper(value: $config.cpuCount, in: minCores...maxCores) {
                    Text("CPU Cores")
                }
                NumberTextField("", number: $config.cpuCount, prompt: "Default", onEditingChanged: { _ in
                    guard config.cpuCount != 0 else {
                        return
                    }
                    if config.cpuCount < minCores {
                        config.cpuCount = minCores
                    } else if config.cpuCount > maxCores {
                        config.cpuCount = maxCores
                    }
                })
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            RAMSlider(systemMemory: $config.memorySize) { _ in
                if config.memorySize > maxMemory {
                    config.memorySize = maxMemory
                }
            }
        }
    }
}

struct VMConfigAppleSystemView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationSystem()
    
    static var previews: some View {
        VMConfigAppleSystemView(config: $config)
    }
}
