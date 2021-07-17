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
    
    var body: some View {
        Group {
            switch wizardState.currentPage {
            case .start:
                VMWizardStartView(wizardState: wizardState)
            case .operatingSystem:
                VMWizardOSView(wizardState: wizardState)
            case .otherBoot:
                VMWizardOSOtherView(wizardState: wizardState)
            case .macOSBoot:
                if #available(macOS 12, *) {
                    VMWizardOSMacView(wizardState: wizardState)
                }
            case .linuxBoot:
                VMWizardOSLinuxView(wizardState: wizardState)
            case .windowsBoot:
                VMWizardOSWindowsView(wizardState: wizardState)
            default:
                EmptyView()
            }
        }.frame(width: 450, height: 450)
            .background(Color(NSColor.windowBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    if wizardState.currentPage != .start {
                        Button("Back") {
                            wizardState.back()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if wizardState.hasNextButton {
                        Button(wizardState.currentPage == .summary ? "Save" : "Next") {
                            wizardState.next()
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
