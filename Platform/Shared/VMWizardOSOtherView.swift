//
// Copyright © 2021 osy. All rights reserved.
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

struct VMWizardOSOtherView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false

    private var supportsUefi: Bool {
        UTMQemuConfigurationQEMU.uefiImagePrefix(forArchitecture: wizardState.systemArchitecture) != nil
    }

    var body: some View {
        VMWizardContent("Other") {
            Picker("Boot Device", selection: $wizardState.bootDevice) {
                Text("None").tag(VMBootDevice.none)
                Text("CD/DVD Image").tag(VMBootDevice.cd)
                if wizardState.legacyHardware {
                    Text("Floppy Image").tag(VMBootDevice.floppy)
                }
                Text("Drive Image").tag(VMBootDevice.drive)
            }.pickerStyle(.inline)
            .onAppear {
                if !wizardState.legacyHardware && wizardState.bootDevice == .floppy {
                    wizardState.bootDevice = .none
                } else if wizardState.legacyHardware {
                    wizardState.systemBootUefi = false
                }
            }
            if wizardState.bootDevice != .none {
                Section {
                    FileBrowseField(url: $wizardState.bootImageURL, isFileImporterPresented: $isFileImporterPresented, hasClearButton: false)
                    .padding(.leading, 1)
                    if wizardState.isBusy {
                        Spinner(size: .large)
                    }
                } header: {
                    if wizardState.bootDevice == .cd {
                        Text("Boot ISO Image")
                    } else if wizardState.bootDevice == .drive {
                        Text("Import Disk Image")
                    } else {
                        Text("Boot IMG Image")
                    }
                }
            }
            if !wizardState.legacyHardware {
                DetailedSection("Options") {
                    Toggle("UEFI Boot", isOn: $wizardState.systemBootUefi)
                        .disabled(!supportsUefi)
                        .onAppear {
                            if !supportsUefi {
                                wizardState.systemBootUefi = false
                            }
                        }
                }
            }
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
    }
    
    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                wizardState.bootImageURL = url
            }
        }
    }
}

struct VMWizardOSOtherView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSOtherView(wizardState: wizardState)
    }
}
