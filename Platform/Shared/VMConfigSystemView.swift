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

private let bytesInMib: UInt64 = 1024 * 1024
private let minMemoryMib = 32
private let baseUsageMib = 128
private let warningThreshold = 0.9

struct VMConfigSystemView: View {
    @Binding var config: UTMQemuConfigurationSystem
    @Binding var isResetConfig: Bool
    @State private var warningMessage: WarningMessage? = nil
    
    @State private var architecture: QEMUArchitecture = .x86_64
    @State private var target: any QEMUTarget = QEMUTarget_x86_64.pc
    
    var body: some View {
        VStack {
            Form {
                HardwareOptions(config: $config, architecture: $architecture, target: $target, warningMessage: $warningMessage)
                RAMSlider(systemMemory: $config.memorySize, onValidate: validateMemorySize)
                Section(header: Text("CPU")) {
                    VMConfigConstantPicker(selection: $config.cpu, type: config.architecture.cpuType)
                }
                CPUFlagsOptions(title: "Force Enable CPU Flags", config: $config, flags: $config.cpuFlagsAdd)
                    .help("If checked, the CPU flag will be enabled. Otherwise, the default value will be used.")
                CPUFlagsOptions(title: "Force Disable CPU Flags", config: $config, flags: $config.cpuFlagsRemove)
                    .help("If checked, the CPU flag will be disabled. Otherwise, the default value will be used.")
                DetailedSection("CPU Cores", description: "Force multicore may improve speed of emulation but also might result in unstable and incorrect emulation.") {
                    HStack {
                        NumberTextField("", number: $config.cpuCount, prompt: "Default", onEditingChanged: validateCpuCount)
                            .multilineTextAlignment(.trailing)
                        Text("Cores")
                    }
                    Toggle(isOn: $config.isForceMulticore, label: {
                        Text("Force Multicore")
                    })
                }
                DetailedSection("JIT Cache", description: "Default is 1/4 of the RAM size (above). The JIT cache size is additive to the RAM size in the total memory usage!") {
                    HStack {
                        NumberTextField("", number: $config.jitCacheSize, prompt: "Default", onEditingChanged: validateMemorySize)
                            .multilineTextAlignment(.trailing)
                        Text("MB")
                    }
                }
            }
        }.alert(item: $warningMessage) { warning in
            switch warning {
            case .overallocatedRam(_, _):
                return Alert(title: Text(warning.localizedWarningTitle), message: Text(warning.localizedWarningMessage))
            case .resetSystem:
                return Alert(title: Text(warning.localizedWarningTitle), message: Text(warning.localizedWarningMessage), primaryButton: .cancel(Text("Cancel"), action: {
                    architecture = config.architecture
                    target = config.target
                }), secondaryButton: .destructive(Text("Reset"), action: {
                    config.architecture = architecture
                    if !architecture.targetType.allRawValues.contains(target.rawValue) {
                        target = architecture.targetType.default
                    }
                    config.target = target
                    isResetConfig = true
                }))
            }
        }.disableAutocorrection(true)
    }
    
    func validateMemorySize(editing: Bool) {
        guard !editing else {
            return
        }
        let memorySizeMib = config.memorySize
        guard memorySizeMib >= minMemoryMib else {
            config.memorySize = 0
            return
        }
        let jitSizeMib = config.jitCacheSize
        guard jitSizeMib >= 0 else {
            config.jitCacheSize = 0
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
            warningMessage = WarningMessage.overallocatedRam(totalMib: totalDeviceMemory / bytesInMib, estimatedMib: estMemoryUsage / bytesInMib)
        }
    }

    func validateCpuCount(editing: Bool) {
        guard !editing else {
            return
        }
        guard config.cpuCount >= 0 else {
            config.cpuCount = 0
            return
        }
    }
}

private enum WarningMessage: Identifiable {
    case overallocatedRam(totalMib: UInt64, estimatedMib: UInt64)
    case resetSystem
    
    var id: Int {
        switch self {
        case .overallocatedRam(_, _):
            return 1
        case .resetSystem:
            return 2
        }
    }
    
    var localizedWarningTitle: String {
        switch self {
        case .overallocatedRam(_, _):
            return NSLocalizedString("Allocating too much memory will crash the VM.", comment: "VMConfigSystemView")
        case .resetSystem:
            return NSLocalizedString("This change will reset all settings", comment: "VMConfigSystemView")
        }
    }
    
    var localizedWarningMessage: String {
        switch self {
        case .overallocatedRam(let totalMib, let estimatedMib):
            let format = NSLocalizedString("Your device has %llu MB of memory and the estimated usage is %llu MB.", comment: "VMConfigSystemView")
            return String.localizedStringWithFormat(format, totalMib, estimatedMib)
        case .resetSystem:
            return NSLocalizedString("Any unsaved changes will be lost.", comment: "VMConfigSystemView")
        }
    }
}

private struct HardwareOptions: View {
    @Binding var config: UTMQemuConfigurationSystem
    @Binding var architecture: QEMUArchitecture
    @Binding var target: any QEMUTarget
    @Binding var warningMessage: WarningMessage?
    @EnvironmentObject private var data: UTMData
    @State private var isArchitectureFirstAppear: Bool = true
    @State private var isTargetFirstAppear: Bool = true
    
    var body: some View {
        Section(header: Text("Hardware")) {
            VMConfigConstantPicker("Architecture", selection: $architecture)
                .onAppear {
                    if isArchitectureFirstAppear {
                        architecture = config.architecture
                    }
                    isArchitectureFirstAppear = false
                }
                .onChange(of: architecture) { newValue in
                    if newValue != config.architecture {
                        warningMessage = .resetSystem
                    }
                }
                .onChange(of: config.architecture) { newValue in
                    if newValue != architecture {
                        architecture = newValue
                    }
                }
            if !UTMQemuVirtualMachine.isSupported(systemArchitecture: config.architecture) {
                Text("The selected architecture is unsupported in this version of UTM.")
                    .foregroundColor(.red)
            }
            VMConfigConstantPicker("System", selection: $target, type: config.architecture.targetType)
                .onAppear {
                    if isTargetFirstAppear {
                        target = config.target
                    }
                    isTargetFirstAppear = false
                }
                .onChange(of: target.rawValue) { newValue in
                    if newValue != config.target.rawValue {
                        warningMessage = .resetSystem
                    }
                }
                .onChange(of: config.target.rawValue) { newValue in
                    if newValue != target.rawValue {
                        target = AnyQEMUConstant(rawValue: newValue)!
                    }
                }
        }
    }
}

struct CPUFlagsOptions: View {
    let title: LocalizedStringKey
    @Binding var config: UTMQemuConfigurationSystem
    @Binding var flags: [any QEMUCPUFlag]
    @State private var showAllFlags: Bool = false
    
    var body: some View {
        let allFlags = config.architecture.cpuFlagType.allRawValues
        if config.cpu.rawValue != "default" && allFlags.count > 0 {
            Section(header: Text(title)) {
                if showAllFlags || flags.count > 0 {
                    OptionsList {
                        ForEach(allFlags) { flagStr in
                            let flag = AnyQEMUConstant(rawValue: flagStr)!
                            let isFlagOn = Binding<Bool> { () -> Bool in
                                flags.contains(where: { $0.rawValue == flag.rawValue })
                            } set: { isOn in
                                if isOn {
                                    flags.append(flag)
                                } else {
                                    flags.removeAll(where: { $0.rawValue == flag.rawValue })
                                }
                            }
                            if showAllFlags || isFlagOn.wrappedValue {
                                Toggle(isOn: isFlagOn, label: {
                                    Text(flag.prettyValue)
                                })
                            }
                        }
                    }
                }
                Button {
                    showAllFlags.toggle()
                } label: {
                    if (showAllFlags) {
                        Text("Hide Unused…")
                    } else {
                        Text("Show All…")
                    }
                }

            }
        }
    }
}

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

struct VMConfigSystemView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigSystemView(config: $config, isResetConfig: .constant(false))
    }
}
