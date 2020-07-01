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

struct VMConfigSystemView: View {
    let validMemoryValues = [32, 64, 128, 256, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 10240, 12288, 14336, 16384, 32768]
    
    @ObservedObject var config: UTMConfiguration
    @State private var memorySizeIndex: Float = 0
    @State private var showAdvanced: Bool = false
    
    var body: some View {
        VStack {
            Form {
                let archObserver = Binding<String?>(
                    get: {
                        return config.systemArchitecture
                    },
                    set: {
                        config.systemArchitecture = $0
                        let index = UTMConfiguration.defaultTargetIndex(forArchitecture: $0)
                        let targets = UTMConfiguration.supportedTargets(forArchitecture: $0)
                        config.systemTarget = targets?[index]
                    }
                )
                let memorySizeIndexObserver = Binding<Float>(
                    get: {
                        return memorySizePickerIndex(size: config.systemMemory)
                    },
                    set: {
                        config.systemMemory = memorySize(pickerIndex: $0)
                    }
                )
                Section(header: Text("Hardware")) {
                    VMConfigStringPicker(selection: archObserver, label: Text("Architecture"), rawValues: UTMConfiguration.supportedArchitectures(), displayValues: UTMConfiguration.supportedArchitecturesPretty())
                    VMConfigStringPicker(selection: $config.systemTarget, label: Text("System"), rawValues: UTMConfiguration.supportedTargets(forArchitecture: config.systemArchitecture) ?? [], displayValues: UTMConfiguration.supportedTargets(forArchitecturePretty: config.systemArchitecture) ?? [])
                    HStack {
                        Slider(value: memorySizeIndexObserver, in: 0...Float(validMemoryValues.count-1), step: 1) {
                            Text("Memory")
                        }
                        TextField("Size", value: $config.systemMemory, formatter: NumberFormatter(), onCommit: validateMemorySize)
                            .frame(width: 50, height: nil)
                            .keyboardType(.numberPad)
                        Text("MB")
                    }
                }
                Toggle(isOn: $showAdvanced.animation(), label: {
                    Text("Show Advanced Settings")
                })
                if showAdvanced {
                    Section(footer: Text("For most non-ARM targets, all CPUs will be emulated by a single CPU by default. Force Multicore will allow multi-CPU emulation even if the memory model is not supported by QEMU (x86 on ARM for example). This could result in incorrect emulation.").padding(.bottom)) {
                        HStack {
                            Text("CPU Count")
                            Spacer()
                            TextField("Size", value: $config.systemCPUCount, formatter: NumberFormatter(), onCommit: validateCpuCount)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                        }
                        Toggle(isOn: $config.systemForceMulticore, label: {
                            Text("Force Multicore")
                        })
                    }
                    Section(footer: Text("Set to 0 for default which is 1/4 of the allocated Memory size. This is in addition to the host memory!").padding(.bottom)) {
                        HStack {
                            Text("JIT Cache")
                            Spacer()
                            TextField("Default", value: $config.systemJitCacheSize, formatter: NumberFormatter(), onCommit: validateMemorySize)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                            Text("MB")
                        }
                    }
                    Section(header: Text("QEMU Machine Properties")) {
                        TextField("None", text: $config.systemMachineProperties.bound)
                    }
                }
            }
        }
    }
    
    func memorySizePickerIndex(size: NSNumber?) -> Float {
        guard let sizeUnwrap = size else {
            return 0
        }
        for (i, s) in validMemoryValues.enumerated() {
            if s >= Int(truncating: sizeUnwrap) {
                return Float(i)
            }
        }
        return Float(validMemoryValues.count - 1)
    }
    
    func memorySize(pickerIndex: Float) -> NSNumber {
        let i = Int(pickerIndex)
        guard i >= 0 && i < validMemoryValues.count else {
            return 0
        }
        return NSNumber(value: validMemoryValues[i])
    }
    
    func validateMemorySize() {
        //FIXME: implement
    }
    
    func validateCpuCount() {
        //FIXME: implement
    }
}

struct VMConfigSystemView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMConfigSystemView(config: config)
    }
}
