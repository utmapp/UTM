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
struct VMConfigInputView: View {
    @ObservedObject var config: UTMLegacyQemuConfiguration
    
    private var usbSupport: Binding<UsbSupport> {
        Binding {
            if config.inputLegacy {
                return UsbSupport.off
            } else if config.usb3Support {
                return UsbSupport.usb3
            } else {
                return UsbSupport.usb2
            }
        } set: { support in
            config.inputLegacy = support == .off
            config.usb3Support = support == .usb3
        }
    }
    
    private var sharingEnabled: Binding<Bool> {
        Binding {
            config.usbRedirectionMaximumDevices != 0
        } set: { enabled in
            if enabled {
                config.usbRedirectionMaximumDevices = 3
            } else {
                config.usbRedirectionMaximumDevices = 0
            }
        }
    }
    
    private var maxUsbShared: Binding<Int> {
        Binding {
            Int(truncating: config.usbRedirectionMaximumDevices ?? 0)
        } set: {
            config.usbRedirectionMaximumDevices = NSNumber(value: $0)
        }
    }
    
    var body: some View {
        VStack {
            Form {
                DetailedSection("USB", description: "If enabled, the default input devices will be emulated on the USB bus.") {
                    DefaultPicker("USB Support", selection: usbSupport) {
                        Text("Off").tag(UsbSupport.off)
                        Text("USB 2.0").tag(UsbSupport.usb2)
                        Text("USB 3.0 (XHCI)").tag(UsbSupport.usb3)
                    }
                }
                
                #if !WITH_QEMU_TCI
                if !config.inputLegacy {
                    Section(header: Text("USB Sharing")) {
                        if !jb_has_usb_entitlement() {
                            Text("USB sharing not supported in this build of UTM.")
                        } else if config.displayConsoleOnly {
                            Text("USB sharing not supported in console display mode.")
                        }
                        Toggle(isOn: sharingEnabled) {
                            Text("Share USB devices from host")
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
                    }.disabled(!jb_has_usb_entitlement() || config.displayConsoleOnly)
                }
                #endif
                
                Section(header: Text("Mouse Wheel")) {
                    Toggle(isOn: $config.inputScrollInvert, label: {
                        Text("Invert Mouse Scroll")
                    })
                }
                
                GestureSettingsSection()
            }
        }
    }
    
    private func validateMaxUsb(editing: Bool) {
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

fileprivate enum UsbSupport: Int, Identifiable {
    case off
    case usb2
    case usb3
    
    var id: Int {
        self.rawValue
    }
}

#if os(macOS)
@available(macOS 11, *)
struct GestureSettingsSection: View {
    var body: some View {
        EmptyView()
    }
}
#else
@available(iOS 14, *)
struct GestureSettingsSection: View {
    var body: some View {
        Section(header: Text("Additional Settings")) {
            Button(action: {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            }, label: {
                Text("Gesture and Cursor Settings")
            })
        }
    }
}
#endif

@available(iOS 14, macOS 11, *)
struct VMConfigInputView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMLegacyQemuConfiguration()
    
    static var previews: some View {
        VMConfigInputView(config: config)
    }
}
