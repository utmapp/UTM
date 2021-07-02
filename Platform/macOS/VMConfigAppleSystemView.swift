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

@available(macOS 12, *)
struct VMConfigAppleSystemView: View {
    
    @ObservedObject var config: UTMAppleConfiguration
    
    var minCores: Int {
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
    }
    
    var maxCores: Int {
        VZVirtualMachineConfiguration.maximumAllowedCPUCount
    }
    
    var minMemory: UInt64 {
        VZVirtualMachineConfiguration.minimumAllowedMemorySize
    }
    
    var maxMemory: UInt64 {
        VZVirtualMachineConfiguration.maximumAllowedMemorySize
    }
    
    var body: some View {
        VStack {
            Form {
                HStack {
                    Stepper(value: $config.cpuCount, in: minCores...maxCores) {
                        Text("CPU Cores")
                    }
                    NumberTextField("", number: $config.cpuCount, onEditingChanged: { _ in
                        if config.cpuCount < minCores {
                            config.cpuCount = minCores
                        } else if config.cpuCount > maxCores {
                            config.cpuCount = maxCores
                        }
                    })
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                RAMSlider(systemMemory: $config.memorySize) { _ in
                    if config.memorySize < minMemory {
                        config.memorySize = minMemory
                    } else if config.memorySize > maxMemory {
                        config.memorySize = maxMemory
                    }
                }
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleSystemView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMConfigAppleSystemView(config: config)
    }
}
