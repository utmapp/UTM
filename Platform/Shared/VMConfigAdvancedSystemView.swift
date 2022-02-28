//
// Copyright © 2022 osy. All rights reserved.
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

@available(macOS 11, *)
@available(iOS, introduced: 14, unavailable)
struct VMConfigAdvancedSystemView: View {
    @ObservedObject var config: UTMQemuConfiguration

    var body: some View {
        ScrollView {
            Form {
                VMConfigAdvancedSystemOptions(config: config)
            }.padding()
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigAdvancedSystemOptions: View {
    @ObservedObject var config: UTMQemuConfiguration
    @State private var warningMessage: String? = nil

    private var supportsUefi: Bool {
        ["arm", "aarch64", "i386", "x86_64"].contains(config.systemArchitecture ?? "")
    }

    private func validateMemorySize(editing: Bool)  {
        warningMessage = config.validateMemorySize(editing: editing)
    }

    var body: some View {
        Section(header: Text("CPU")) {
            VMConfigStringPicker("", selection: $config.systemCPU.animation(), rawValues: UTMQemuConfiguration.supportedCpus(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedCpus(forArchitecturePretty: config.systemArchitecture))
        }
        CPUFlagsOptions(config: config)
        DetailedSection("CPU Cores", description: "Force multicore may improve speed of emulation but also might result in unstable and incorrect emulation.") {
            HStack {
                NumberTextField("", number: $config.systemCPUCount, prompt: "Default", onEditingChanged: validateCpuCount)
                    .multilineTextAlignment(.trailing)
                Text("Cores")
            }
            Toggle(isOn: $config.systemForceMulticore, label: {
                Text("Force Multicore")
            })
        }
        DetailedSection("JIT Cache", description: "Default is 1/4 of the RAM size (above). The JIT cache size is additive to the RAM size in the total memory usage!") {
            HStack {
                NumberTextField("", number: $config.systemJitCacheSize, prompt: "Default", onEditingChanged: validateMemorySize)
                    .multilineTextAlignment(.trailing)
                Text("MB")
            }
        }
    }

    private func validateCpuCount(editing: Bool) {
        guard !editing else {
            return
        }
        guard let cpuCount = config.systemCPUCount?.intValue, cpuCount >= 0 else {
            config.systemCPUCount = NSNumber(value: 0)
            return
        }
    }
}

@available(iOS 14, macOS 11, *)
struct CPUFlagsOptions: View {
    @ObservedObject var config: UTMQemuConfiguration
    @State private var showAllFlags: Bool = false

    var body: some View {
        let allFlags = UTMQemuConfiguration.supportedCpuFlags(forArchitecture: config.systemArchitecture) ?? []
        let activeFlags = config.systemCPUFlags ?? []
        if config.systemCPU != "default" && allFlags.count > 0 {
            Section(header: Text("CPU Flags")) {
                if showAllFlags || activeFlags.count > 0 {
                    OptionsList {
                        ForEach(allFlags) { flag in
                            let isFlagOn = Binding<Bool> { () -> Bool in
                                activeFlags.contains(flag)
                            } set: { isOn in
                                if isOn {
                                    config.newCPUFlag(flag)
                                } else {
                                    config.removeCPUFlag(flag)
                                }
                            }
                            if showAllFlags || isFlagOn.wrappedValue {
                                Toggle(isOn: isFlagOn, label: {
                                    Text(flag)
                                })
                            }
                        }
                    }
                }
                Button {
                    showAllFlags.toggle()
                } label: {
                    if (showAllFlags) {
                        Text("Hide Unused Flags...")
                    } else {
                        Text("Show All Flags...")
                    }
                }

            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct OptionsList<Content>: View where Content: View {
    private var columns: [GridItem] = [
        GridItem(.fixed(150), spacing: 16),
        GridItem(.fixed(150), spacing: 16),
        GridItem(.fixed(150), spacing: 16),
        GridItem(.fixed(150), spacing: 16)
    ]

    var content: () -> Content

    init(content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
#if os(macOS)
        LazyVGrid(columns: columns, alignment: .leading) {
            content()
        }
#else
        LazyVStack {
            content()
        }
#endif
    }
}

