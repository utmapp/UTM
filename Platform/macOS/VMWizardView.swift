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

@available(macOS 11, *)
struct VMWizardView: View {
    @StateObject var wizardState = VMWizardState()
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Group {
            switch wizardState.currentPage {
            case .start:
                VMWizardStartView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .operatingSystem:
                VMWizardOSView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .otherBoot:
                VMWizardOSOtherView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .macOSBoot:
                if #available(macOS 12, *) {
                    VMWizardOSMacView(wizardState: wizardState)
                        .transition(wizardState.slide)
                }
            case .linuxBoot:
                VMWizardOSLinuxView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .windowsBoot:
                VMWizardOSWindowsView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .hardware:
                VMWizardHardwareView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .drives:
                VMWizardDrivesView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .sharing:
                VMWizardSharingView(wizardState: wizardState)
                    .transition(wizardState.slide)
            case .summary:
                VMWizardSummaryView(wizardState: wizardState)
                    .transition(wizardState.slide)
            }
        }.padding()
            .frame(width: 450, height: 450)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if wizardState.currentPage != .start {
                        Button("Back") {
                            wizardState.back()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if wizardState.hasNextButton {
                        Button("Next") {
                            wizardState.next()
                        }
                    } else if wizardState.currentPage == .summary {
                        Button("Save") {
                            presentationMode.wrappedValue.dismiss()
                            data.busyWork {
                                let config = try wizardState.generateConfig()
                                #if arch(arm64)
                                if #available(macOS 12, *), wizardState.isPendingIPSWDownload {
                                    data.createPendingIPSWDownload(config: config as! UTMAppleConfiguration)
                                    return
                                }
                                #endif
                                try data.create(config: config) { vm in
                                    data.selectedVM = vm
                                    if wizardState.isOpenSettingsAfterCreation {
                                        data.showSettingsModal = true
                                    }
                                    if let qemuVm = vm as? UTMQemuVirtualMachine {
                                        data.busyWork {
                                            try wizardState.qemuPostCreate(with: qemuVm)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.alert(item: $wizardState.alertMessage) { msg in
                Alert(title: Text(msg.message))
            }
    }
}

@available(macOS 11, *)
struct VMWizardView_Previews: PreviewProvider {
    static var previews: some View {
        VMWizardView()
    }
}
