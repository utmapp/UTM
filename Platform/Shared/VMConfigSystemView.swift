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
    #if os(macOS)
    let warningThreshold = 0.9
    #else
    let warningThreshold = 0.4
    #endif
    
    @ObservedObject var config: UTMConfiguration
    @State private var showAdvanced: Bool = false
    @State private var warningMessage: String? = nil
    
    var body: some View {
        VStack {
            Form {
                HardwareOptions(config: config, validateMemorySize: validateMemorySize)
                Toggle(isOn: $showAdvanced.animation(), label: {
                    Text("Show Advanced Settings")
                })
                if showAdvanced {
                    Section(header: Text("CPU")) {
                        VMConfigStringPicker(selection: $config.systemCPU.animation(), label: EmptyView(), rawValues: UTMConfiguration.supportedCpus(forArchitecture: config.systemArchitecture), displayValues: UTMConfiguration.supportedCpus(forArchitecturePretty: config.systemArchitecture))
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
                        TextField("None", text: $config.systemMachineProperties.bound)
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
        let totalDeviceMemory = ProcessInfo.processInfo.physicalMemory
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
    let validMemoryValues = [32, 64, 128, 256, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 10240, 12288, 14336, 16384, 32768]
    
    @ObservedObject var config: UTMConfiguration
    let validateMemorySize: (Bool) -> Void
    @EnvironmentObject private var data: UTMData
    @State private var memorySizeIndex: Float = 0
    @State private var warningMessage: String? = nil
    
    var body: some View {
        let memorySizeIndexObserver = Binding<Float>(
            get: {
                return memorySizePickerIndex(size: config.systemMemory)
            },
            set: {
                config.systemMemory = memorySize(pickerIndex: $0)
            }
        )
        Section(header: Text("Hardware")) {
            VMConfigStringPicker(selection: $config.systemArchitecture, label: Text("Architecture"), rawValues: UTMConfiguration.supportedArchitectures(), displayValues: UTMConfiguration.supportedArchitecturesPretty())
                .onChange(of: config.systemArchitecture, perform: { value in
                    guard let arch = value else {
                        return
                    }
                    let index = UTMConfiguration.defaultTargetIndex(forArchitecture: arch)
                    let targets = UTMConfiguration.supportedTargets(forArchitecture: arch)
                    config.systemTarget = targets?[index]
                    config.loadDefaults(forTarget: config.systemTarget, architecture: arch)
                    // disable unsupported hardware
                    if let displayCard = config.displayCard {
                        if !UTMConfiguration.supportedDisplayCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(displayCard) == .orderedSame }) {
                            if UTMConfiguration.supportedDisplayCards(forArchitecture: arch)!.contains("VGA") {
                                config.displayCard = "VGA" // most devices support VGA
                            } else {
                                config.displayConsoleOnly = true
                                config.shareClipboardEnabled = false
                                config.shareDirectoryEnabled = false
                            }
                        }
                    }
                    if let networkCard = config.networkCard {
                        if !UTMConfiguration.supportedNetworkCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(networkCard) == .orderedSame }) {
                            config.networkEnabled = false
                        }
                    }
                    if let soundCard = config.soundCard {
                        if !UTMConfiguration.supportedSoundCards(forArchitecture: arch)!.contains(where: { $0.caseInsensitiveCompare(soundCard) == .orderedSame }) {
                            config.soundEnabled = false
                        }
                    }
                })
            if !data.isSupported(systemArchitecture: config.systemArchitecture) {
                Text("The selected architecture is unsupported in this version of UTM.")
                    .foregroundColor(.red)
            }
            VMConfigStringPicker(selection: $config.systemTarget, label: Text("System"), rawValues: UTMConfiguration.supportedTargets(forArchitecture: config.systemArchitecture), displayValues: UTMConfiguration.supportedTargets(forArchitecturePretty: config.systemArchitecture))
                .onChange(of: config.systemTarget, perform: { value in
                    config.loadDefaults(forTarget: value, architecture: config.systemArchitecture)
                })
            HStack {
                Slider(value: memorySizeIndexObserver, in: 0...Float(validMemoryValues.count-1), step: 1) { start in
                    if !start {
                        validateMemorySize(false)
                    }
                } label: {
                    Text("Memory")
                }
                NumberTextField("Size", number: $config.systemMemory, onEditingChanged: validateMemorySize)
                    .frame(width: 50, height: nil)
                Text("MB")
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
}

@available(iOS 14, macOS 11, *)
struct CPUFlagsOptions: View {
    @ObservedObject var config: UTMConfiguration
    @State private var showAllFlags: Bool = false
    
    var body: some View {
        let allFlags = UTMConfiguration.supportedCpuFlags(forArchitecture: config.systemArchitecture) ?? []
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
    @ObservedObject static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigSystemView(config: config)
    }
}
