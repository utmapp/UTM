//
// Copyright © 2022 osy. All rights reserved.
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

struct VMToolbarUSBMenuView: View {
    @EnvironmentObject private var session: VMSessionState
    
    var body: some View {
        Menu {
            if session.allUsbDevices.isEmpty {
                Text("No USB devices detected.")
            } else {
                ForEach(session.allUsbDevices.indices, id: \.self) { i in
                    let usbDevice = session.allUsbDevices[i]
                    let connected = session.connectedUsbDevices.contains { $0 == usbDevice }
                    Button {
                        if connected {
                            session.disconnectDevice(usbDevice)
                        } else {
                            session.connectDevice(usbDevice)
                        }
                    } label: {
                        MenuLabel((usbDevice.name ?? usbDevice.description) + suffix(connected: connected), systemImage: connected ? "checkmark.circle.fill" : "")
                    }
                }
            }
        } label: {
            if session.isUsbBusy {
                Spinner(size: .regular)
            } else {
                Label("USB", image: "Toolbar USB")
            }
        }.simultaneousGesture(TapGesture().onEnded {
            session.refreshDevices()
        })
    }
    
    // When < iOS 14.5, the checkmark label image does not show up
    private func suffix(connected isConnected: Bool) -> String {
        if #unavailable(iOS 14.5), isConnected {
            return " ✓"
        } else {
            return ""
        }
    }
}

struct VMToolbarUSBMenuView_Previews: PreviewProvider {
    static var previews: some View {
        VMToolbarUSBMenuView()
    }
}
