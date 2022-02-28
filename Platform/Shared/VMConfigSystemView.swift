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

@available(iOS 13.0, *)
extension UTMQemuConfiguration {
    func validateMemorySize(editing: Bool) -> String? {
        guard !editing else {
            return nil
        }
        guard let memorySizeMib = systemMemory?.intValue, memorySizeMib >= minMemoryMib else {
            systemMemory = NSNumber(value: minMemoryMib)
            return nil
        }
        guard let jitSizeMib = systemJitCacheSize?.intValue, jitSizeMib >= 0 else {
            systemJitCacheSize = NSNumber(value: 0)
            return nil
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
            return String(format: format, totalDeviceMemory / bytesInMib, estMemoryUsage / bytesInMib)
        }
        return nil
    }

}

@available(iOS 14, macOS 11, *)
struct VMConfigSystemView: View {    
    @ObservedObject var config: UTMQemuConfiguration
    @State private var showAdvanced = false

    var body: some View {
        VStack {
            Form {
                HardwareOptions(config: config)
                #if os(iOS)
                Toggle(isOn: $showAdvanced.animation(), label: {
                    Text("Show Advanced Settings")
                })
                if showAdvanced {
                    VMConfigAdvancedSystemOptions(config: config)
                }
                #endif
            }
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct HardwareOptions: View {
    @ObservedObject var config: UTMQemuConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var warningMessage: String? = nil

    private func validateMemorySize(editing: Bool)  {
        warningMessage = config.validateMemorySize(editing: editing)
    }

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
        }.alert(item: $warningMessage) { warning in
            Alert(title: Text(warning))
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigSystemView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigSystemView(config: config)
    }
}
