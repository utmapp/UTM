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

@available(iOS 14, macOS 11, *)
struct VMConfigSystemView: View {
    let bytesInMib: UInt64 = 1024 * 1024
    let minMemoryMib = 32
    let baseUsageMib = 128
    let warningThreshold = 0.9
    
    @ObservedObject var config: UTMQemuConfiguration
    @State private var warningMessage: String? = nil
    
    var body: some View {
        VStack {
            Form {
                HardwareOptions(config: config, validateMemorySize: validateMemorySize)
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
        }.alert(item: $warningMessage) { warning in
            Alert(title: Text(warning))
        }.disableAutocorrection(true)
    }
    
    func validateMemorySize(editing: Bool) {
        guard !editing else {
            return
        }
        guard let memorySizeMib = config.systemMemory?.intValue, memorySizeMib >= minMemoryMib else {
            config.systemMemory = NSNumber(value: minMemoryMib)
            return
        }
        guard let jitSizeMib = config.systemJitCacheSize?.intValue, jitSizeMib >= 0 else {
            config.systemJitCacheSize = NSNumber(value: 0)
            return
        }
        var totalDeviceMemory = ProcessInfo.processInfo.physicalMemory
        #if os(iOS)
        let availableMemory = UInt64(os_proc_available_memory())
        if availableMemory > 0 {
            totalDeviceMemory = availableMemory
        }
        #endif
        let actualJitSizeMib = jitSizeMib == 0 ? memorySizeMib / 4 : jitSizeMib
        let jitMirrorMultiplier = jb_has_jit_entitlement() ? 1 : 2;
        let estMemoryUsage = UInt64(memorySizeMib + jitMirrorMultiplier*actualJitSizeMib + baseUsageMib) * bytesInMib
        if Double(estMemoryUsage) > Double(totalDeviceMemory) * warningThreshold {
            let format = NSLocalizedString("Allocating too much memory will crash the VM. Your device has %llu MB of memory and the estimated usage is %llu MB.", comment: "VMConfigSystemView")
            warningMessage = String(format: format, totalDeviceMemory / bytesInMib, estMemoryUsage / bytesInMib)
        }
    }
    
    func validateCpuCount(editing: Bool) {
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
struct HardwareOptions: View {
    @ObservedObject var config: UTMQemuConfiguration
    let validateMemorySize: (Bool) -> Void
    @EnvironmentObject private var data: UTMData
    @State private var warningMessage: String? = nil
    
    var body: some View {
        Section(header: Text("Hardware")) {
            VMConfigStringPicker("Architecture", selection: $config.systemArchitecture, rawValues: UTMQemuConfiguration.supportedArchitectures(), displayValues: UTMQemuConfiguration.supportedArchitecturesPretty())
                .onChange(of: config.systemArchitecture, perform: { value in
                    guard let arch = value else {
                        return
                    }
                    let index = UTMQemuConfiguration.defaultTargetIndex(forArchitecture: arch)
                    let targets = UTMQemuConfiguration.supportedTargets(forArchitecture: arch)
                    config.systemTarget = targets?[index]
                    config.loadDefaults(forTarget: config.systemTarget, architecture: arch)
                    // disable unsupported hardware
                    if let displayCard = config.displayCard {
                        if !UTMQemuConfiguration.supportedDisplayCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(displayCard) == .orderedSame }) {
                            if UTMQemuConfiguration.supportedDisplayCards(forArchitecture: arch)!.contains("VGA") {
                                config.displayCard = "VGA" // most devices support VGA
                            } else {
                                config.displayConsoleOnly = true
                                config.shareClipboardEnabled = false
                                config.shareDirectoryEnabled = false
                            }
                        }
                    }
                    if let networkCard = config.networkCard {
                        if !UTMQemuConfiguration.supportedNetworkCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(networkCard) == .orderedSame }) {
                            config.networkEnabled = false
                        }
                    }
                    if let soundCard = config.soundCard {
                        if !UTMQemuConfiguration.supportedSoundCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(soundCard) == .orderedSame }) {
                            config.soundEnabled = false
                        }
                    }
                })
            if !UTMQemuVirtualMachine.isSupported(systemArchitecture: config.systemArchitecture) {
                Text("The selected architecture is unsupported in this version of UTM.")
                    .foregroundColor(.red)
            }
            VMConfigStringPicker("System", selection: $config.systemTarget, rawValues: UTMQemuConfiguration.supportedTargets(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedTargets(forArchitecturePretty: config.systemArchitecture))
                .onChange(of: config.systemTarget, perform: { value in
                    config.loadDefaults(forTarget: value, architecture: config.systemArchitecture)
                })
            RAMSlider(systemMemory: $config.systemMemory, onValidate: validateMemorySize)
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

@available(iOS 14, macOS 11, *)
struct VMConfigSystemView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigSystemView(config: config)
    }
}
