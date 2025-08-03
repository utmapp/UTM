//
// Copyright © 2025 osy. All rights reserved.
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

struct VMWizardOSClassicMacView: View {
    private enum PpcVia: CaseIterable, Identifiable {
        case pmu
        case pmuAdb
        case cuda
        
        var id: Self { self }
        
        var title: LocalizedStringKey {
            switch self {
            case .pmu: return "PMU"
            case .pmuAdb: return "PMU-ADB"
            case .cuda: return "CUDA"
            }
        }

        var machineProperties: String {
            switch self {
            case .pmu: return "via=pmu"
            case .pmuAdb: return "via=pmu-adb"
            case .cuda: return "via=cuda"
            }
        }
    }

    private enum SelectImage {
        case bios
        case bootImage
    }

    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    @State private var ppcVia: PpcVia = .pmu
    @State private var selectImage: SelectImage = .bootImage

    var body: some View {
        VMWizardContent("Classic Mac OS") {
            DetailedSection("Boot ISO Image") {
                FileBrowseField(url: $wizardState.bootImageURL, isFileImporterPresented: $isFileImporterPresented, hasClearButton: false) {
                    selectImage = .bootImage
                }
            }
            
            if wizardState.systemTarget.rawValue == QEMUTarget_m68k.q800.rawValue {
                DetailedSection("Quadra 800 ROM") {
                    FileBrowseField(url: $wizardState.quadra800RomUrl, isFileImporterPresented: $isFileImporterPresented, hasClearButton: false) {
                        selectImage = .bios
                    }
                }
            }
            
            if wizardState.systemArchitecture == .ppc || wizardState.systemArchitecture == .ppc64 {
                DetailedSection("Advanced Options") {
                    Picker("PMU", selection: $ppcVia) {
                        ForEach(PpcVia.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.inline)
                    #endif
                    .help("Different versions of Mac OS require different VIA option.")
                    .onChange(of: ppcVia) { newValue in
                        wizardState.machineProperties = newValue.machineProperties
                    }
                    .onAppear {
                        wizardState.machineProperties = ppcVia.machineProperties
                    }
                }
            }
            
            if wizardState.isBusy {
                Spinner(size: .large)
            }
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data]) { result in
            wizardState.busyWorkAsync {
                let url = try result.get()
                await MainActor.run {
                    switch selectImage {
                    case .bios:
                        wizardState.quadra800RomUrl = url
                    case .bootImage:
                        wizardState.bootImageURL = url
                    }
                }
            }
        }
    }
}

#Preview {
    VMWizardOSClassicMacView(wizardState: VMWizardState())
}
