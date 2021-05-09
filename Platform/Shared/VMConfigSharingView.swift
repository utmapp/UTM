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
struct VMConfigSharingView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            Form {
                if config.displayConsoleOnly {
                    Text("These settings are unavailable in console display mode.")
                }
                
                Section(header: Text("Clipboard Sharing"), footer: Text("Requires SPICE guest agent tools to be installed.").padding(.bottom)) {
                    Toggle(isOn: $config.shareClipboardEnabled, label: {
                        Text("Enable Clipboard Sharing")
                    })
                }
                
                Section(header: Text("Shared Directory"), footer: Text("Requires SPICE WebDAV service to be installed.").padding(.bottom)) {
                    Toggle(isOn: $config.shareDirectoryEnabled.animation(), label: {
                        Text("Enable Directory Sharing")
                    }).onChange(of: config.shareDirectoryEnabled, perform: { _ in
                        // remove legacy bookmark data
                        config.shareDirectoryBookmark = nil
                    })
                    Toggle(isOn: $config.shareDirectoryReadOnly, label: {
                        Text("Read Only")
                    })
                    Text("Note: select the path to share from the main screen.")
                }
                
                #if !WITH_QEMU_TCI
                Section(header: Text("USB Sharing"), footer: EmptyView().padding(.bottom)) {
                    if !jb_has_usb_entitlement() {
                        Text("USB not supported in this build of UTM.")
                    } else if config.displayConsoleOnly {
                        Text("USB not supported in console display mode.")
                    }
                    Toggle(isOn: $config.usb3Support) {
                        Text("USB 3.0 (XHCI) Support")
                    }
                    let maxUsbObserver = Binding<Int> {
                        Int(truncating: config.usbRedirectionMaximumDevices ?? 0)
                    } set: {
                        config.usbRedirectionMaximumDevices = NSNumber(value: $0)
                    }
                    HStack {
                        Stepper(value: maxUsbObserver, in: 0...64) {
                            Text("Maximum Shared USB Devices")
                        }
                        NumberTextField("", number: $config.usbRedirectionMaximumDevices, onEditingChanged: validateMaxUsb)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                    }
                }.disabled(!jb_has_usb_entitlement())
                #endif
            }.disabled(config.displayConsoleOnly)
        }
    }
    
    func validateMaxUsb(editing: Bool) {
        guard !editing else {
            return
        }
        guard let maxUsb = config.usbRedirectionMaximumDevices?.intValue else {
            config.usbRedirectionMaximumDevices = 3
            return
        }
        if maxUsb < 0 {
            config.usbRedirectionMaximumDevices = 0
        } else if maxUsb > 64 {
            config.usbRedirectionMaximumDevices = 64
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigSharingView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigSharingView(config: config)
    }
}
