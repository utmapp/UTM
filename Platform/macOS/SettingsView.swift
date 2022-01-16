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

@available(macOS 11, *)
struct SettingsView: View {
    @AppStorage("TerminateAfterLastWindowClosed") var isTerminateAfterLastWindowClosed = false
    @AppStorage("DisplayFixed") var isVMDisplayFixed = false
    @AppStorage("NoHypervisor") var isNoHypervisor = false
    @AppStorage("CtrlRightClick") var isCtrlRightClick = false
    @AppStorage("NoUsbPrompt") var isNoUsbPrompt = false
    @AppStorage("UseOnlyPcores") var isUseOnlyPcores = true
    @AppStorage("AlternativeCaptureKey") var isAlternativeCaptureKey = false
    
    var body: some View {
        Form {
            Section(header: Text("Application")) {
                Toggle(isOn: $isTerminateAfterLastWindowClosed, label: {
                    Text("Terminate when last window is closed and all VMs are shut down")
                })
            }
            Section(header: Text("Display")) {
                Toggle(isOn: $isVMDisplayFixed, label: {
                    Text("VM display size is fixed (no zoom)")
                })
            }
            Section(header: Text("Default VM Configuration")) {
                Toggle(isOn: $isNoHypervisor, label: {
                    Text("Force slower emulation by default (deprecated: now configured per-VM)")
                })
                Toggle(isOn: $isUseOnlyPcores, label: {
                    Text("Use only performance cores by default (deprecated: now configured per-VM)")
                })
            }
            Section(header: Text("Input")) {
                Toggle(isOn: $isCtrlRightClick, label: {
                    Text("Hold Control (⌃) for right click")
                })
                Toggle(isOn: $isAlternativeCaptureKey, label: {
                    Text("Use Command+Opt (⌘+⌥) for input capture/release")
                })
            }
            Section(header: Text("USB")) {
                Toggle(isOn: $isNoUsbPrompt, label: {
                    Text("Do not show prompt when USB device is plugged in")
                })
            }
        }.padding(.vertical)
        .padding()
    }
}

extension UserDefaults {
    @objc dynamic var TerminateAfterLastWindowClosed: Bool { false }
    @objc dynamic var NoCursorCaptureAlert: Bool { false }
    @objc dynamic var DisplayFixed: Bool { false }
    @objc dynamic var NoHypervisor: Bool { false }
    @objc dynamic var CtrlRightClick: Bool { false }
    @objc dynamic var NoUsbPrompt: Bool { false }
    @objc dynamic var UseOnlyPcores: Bool { false }
    @objc dynamic var AlternativeCaptureKey: Bool { false }
}

@available(macOS 11, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
