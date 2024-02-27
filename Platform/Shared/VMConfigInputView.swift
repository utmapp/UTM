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

struct VMConfigInputView: View {
    @Binding var config: UTMQemuConfigurationInput
    
    var body: some View {
        VStack {
            Form {
                DetailedSection("USB", description: "If enabled, the default input devices will be emulated on the USB bus.") {
                    VMConfigConstantPicker("USB Support", selection: $config.usbBusSupport)
                }
                
                #if WITH_USB
                if config.usbBusSupport != .disabled {
                    Section(header: Text("USB Sharing")) {
                        if !jb_has_usb_entitlement() {
                            Text("USB sharing not supported in this build of UTM.")
                        }
                        Toggle(isOn: $config.hasUsbSharing) {
                            Text("Share USB devices from host")
                        }
                        HStack {
                            Stepper(value: $config.maximumUsbShare, in: 0...64) {
                                Text("Maximum Shared USB Devices")
                            }
                            NumberTextField("", number: $config.maximumUsbShare, onEditingChanged: validateMaxUsb)
                                .frame(width: 50)
                                .multilineTextAlignment(.trailing)
                        }
                    }.disabled(!jb_has_usb_entitlement())
                }
                #endif
                
                GestureSettingsSection()
            }
        }
    }
    
    private func validateMaxUsb(editing: Bool) {
        guard !editing else {
            return
        }
        if config.maximumUsbShare < 0 {
            config.maximumUsbShare = 0
        } else if config.maximumUsbShare > 64 {
            config.maximumUsbShare = 64
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

#if os(macOS) || os(visionOS)
@available(macOS 11, *)
struct GestureSettingsSection: View {
    var body: some View {
        EmptyView()
    }
}
#else
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

struct VMConfigInputView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationInput()
    
    static var previews: some View {
        VMConfigInputView(config: $config)
            #if os(macOS)
            .scrollable()
            #endif
    }
}
