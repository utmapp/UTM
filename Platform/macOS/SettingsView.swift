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
    @AppStorage("AlwaysNativeResolution") var isAlwaysNativeResolution = false
    @AppStorage("DisplayFixed") var isVMDisplayFixed = false
    @AppStorage("NoHypervisor") var isNoHypervisor = false
    @AppStorage("CtrlRightClick") var isCtrlRightClick = false
    @AppStorage("NoUsbPrompt") var isNoUsbPrompt = false
    
    var body: some View {
        Form {
            Section(header: Text("Scaling")) {
                Toggle(isOn: $isAlwaysNativeResolution, label: {
                    Text("Always use native (HiDPI) resolution")
                })
                Toggle(isOn: $isVMDisplayFixed, label: {
                    Text("VM display size is fixed")
                })
            }
            Section(header: Text("Acceleration")) {
                Toggle(isOn: $isNoHypervisor, label: {
                    Text("Force slower emulation even when hypervisor is available")
                })
            }
            Section(header: Text("Input")) {
                Toggle(isOn: $isCtrlRightClick, label: {
                    Text("Hold Control (⌃) for right click")
                })
            }
            Section(header: Text("USB")) {
                Toggle(isOn: $isNoUsbPrompt, label: {
                    Text("Do not show prompt when USB device is plugged in")
                })
            }
        }.padding()
    }
}

extension UserDefaults {
    @objc dynamic var NoCursorCaptureAlert: Bool { false }
    @objc dynamic var AlwaysNativeResolution: Bool { false }
    @objc dynamic var DisplayFixed: Bool { false }
    @objc dynamic var NoHypervisor: Bool { false }
    @objc dynamic var CtrlRightClick: Bool { false }
    @objc dynamic var NoUsbPrompt: Bool { false }
}

@available(macOS 11, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
