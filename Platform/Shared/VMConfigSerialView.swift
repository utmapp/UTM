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

struct VMConfigSerialView: View {
    @Binding var config: UTMQemuConfigurationSerial
    @Binding var system: UTMQemuConfigurationSystem
    
    @State private var isFirstAppear: Bool = true
    @State private var isUnsupportedAlertShown: Bool = false
    @State private var hardware: any QEMUSerialDevice = AnyQEMUConstant(rawValue: "")!
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Connection")) {
                    VMConfigConstantPicker("Mode", selection: $config.mode)
                        .onChange(of: config.mode) { newValue in
                            if newValue == .builtin && config.terminal == nil {
                                config.terminal = .init()
                            }
                        }
                    VMConfigConstantPicker("Target", selection: $config.target)
                        .onChange(of: config.target) { newValue in
                            if newValue == .manualDevice && system.architecture.serialDeviceType.allRawValues.isEmpty {
                                config.target = .autoDevice
                                isUnsupportedAlertShown.toggle()
                            }
                        }
                    if config.mode == .tcpServer {
                        Toggle("Wait for Connection", isOn: $config.isWaitForConnection.bound)
                        Toggle("Allow Remote Connection", isOn: $config.isRemoteConnectionAllowed.bound)
                    }
                }
                
                if config.target == .manualDevice {
                    Section(header: Text("Hardware")) {
                        VMConfigConstantPicker("Emulated Serial Device", selection: $hardware, type: system.architecture.serialDeviceType)
                    }
                    .onAppear {
                        if isFirstAppear {
                            if let configHardware = config.hardware {
                                hardware = configHardware
                            } else if let `default` = system.architecture.serialDeviceType.allCases.first {
                                hardware = `default`
                            }
                        }
                        isFirstAppear = false
                    }
                    .onChange(of: hardware.rawValue) { newValue in
                        config.hardware = hardware
                    }
                    .onChange(of: config.hardware?.rawValue) { newValue in
                        if let configHardware = config.hardware {
                            hardware = configHardware
                        }
                    }
                }
                
                if config.mode == .builtin {
                    VMConfigDisplayConsoleView(config: $config.terminal.bound)
                } else if config.mode == .tcpClient || config.mode == .tcpServer {
                    Section(header: Text("TCP")) {
                        if config.mode == .tcpClient {
                            DefaultTextField("Server Address", text: $config.tcpHostAddress.bound, prompt: "example.com")
                                .keyboardType(.decimalPad)
                        }
                        NumberTextField("Port", number: $config.tcpPort.bound, prompt: "1234")
                    }
                }
            }
        }.disableAutocorrection(true)
        .alert(isPresented: $isUnsupportedAlertShown) {
            Alert(title: Text("The target does not support hardware emulated serial connections."))
        }
        #if !os(macOS)
        .padding(.horizontal, 0)
        #endif
    }
}

struct VMConfigSerialView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationSerial()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigSerialView(config: $config, system: $system)
    }
}
