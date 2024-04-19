//
// Copyright © 2024 osy. All rights reserved.
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

struct VMWizardStartViewTCI: View {
    @ObservedObject var wizardState: VMWizardState

    var body: some View {
        VMWizardContent("Start") {
            Section {
                Button {
                    wizardState.useVirtualization = false
                    wizardState.operatingSystem = .Other
                    wizardState.next()
                } label: {
                    HStack {
                        Image(systemName: "pc")
                            .font(.title)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New Machine")
                                .font(.title)
                            Text("Create a new emulated machine from scratch.")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.inList)

            } header: {
                Text("Custom")
            }
            Section {
                Button {
                    NotificationCenter.default.post(name: NSNotification.OpenVirtualMachine, object: nil)
                } label: {
                    Label {
                        Text("Open…")
                    } icon: {
                        Image(systemName: "doc")
                    }
                }
                Link(destination: URL(string: "https://mac.getutm.app/gallery/")!) {
                    Label {
                        Text("Download prebuilt from UTM Gallery…")
                    } icon: {
                        Image(systemName: "arrow.down.doc")
                    }
                }
            } header: {
                Text("Existing")
            }

        }
    }
}

#Preview {
    VMWizardStartViewTCI(wizardState: VMWizardState())
}
