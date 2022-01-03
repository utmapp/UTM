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
    @State private var showAdvanced: Bool = false
    @State private var warningMessage: String? = nil
    
    var supportsUefi: Bool {
        ["arm", "aarch64", "i386", "x86_64"].contains(config.systemArchitecture ?? "")
    }
    
    var body: some View {
        VStack {
            Form {
                HardwareOptions(config: config, validateMemorySize: validateMemorySize)
                Toggle(isOn: $showAdvanced.animation(), label: {
                    Text("Show Advanced Settings")
                })
                if showAdvanced {
                    Section(header: Text("Tweaks")) {
                        Toggle("UEFI Boot", isOn: $config.systemBootUefi)
                            .disabled(!supportsUefi)
                    }
                    Section(header: Text("CPU")) {
                        VMConfigStringPicker(selection: $config.systemCPU.animation(), label: EmptyView(), rawValues: UTMQemuConfiguration.supportedCpus(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedCpus(forArchitecturePretty: config.systemArchitecture))
                    }
                    CPUFlagsOptions(config: config)
                    Section(header: Text("CPU Cores"), footer: Text("Set to 0 to use maximum supported CPUs. Force multicore might result in incorrect emulation.").padding(.bottom)) {
                        HStack {
                            NumberTextField("Default", number: $config.systemCPUCount, onEditingChanged: validateCpuCount)
                                .multilineTextAlignment(.trailing)
                            Text("Cores")
                        }
                        Toggle(isOn: $config.systemForceMulticore, label: {
                            Text("Force Multicore")
                        })
                    }
                    Section(header: Text("JIT Cache"), footer: Text("Set to 0 for default which is 1/4 of the allocated Memory size. This is in addition to the host memory!").padding(.bottom)) {
                        HStack {
                            NumberTextField("Default", number: $config.systemJitCacheSize, onEditingChanged: validateMemorySize)
                                .multilineTextAlignment(.trailing)
                            Text("MB")
                        }
                    }
                    Section(header: Text("QEMU Machine Properties")) {
                        #if swift(>=5.5)
                        if #available(iOS 15, macOS 12, *) {
                            TextField("", text: $config.systemMachineProperties.bound, prompt: Text("None"))
                        } else {
                            TextField("None", text: $config.systemMachineProperties.bound)
                        }
                        #else
                        TextField("None", text: $config.systemMachineProperties.bound)
                        #endif
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
            VMConfigStringPicker(selection: $config.systemArchitecture, label: Text("Architecture"), rawValues: UTMQemuConfiguration.supportedArchitectures(), displayValues: UTMQemuConfiguration.supportedArchitecturesPretty())
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
            if !data.isSupported(systemArchitecture: config.systemArchitecture) {
                Text("The selected architecture is unsupported in this version of UTM.")
                    .foregroundColor(.red)
            }
            VMConfigStringPicker(selection: $config.systemTarget, label: Text("System"), rawValues: UTMQemuConfiguration.supportedTargets(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedTargets(forArchitecturePretty: config.systemArchitecture))
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
