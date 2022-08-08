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

struct VMWizardSharingView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    
    var body: some View {
#if os(macOS)
        Text("Shared Directory")
            .font(.largeTitle)
#endif
        List {
            Section {
                HStack {
                    Text("Directory")
                    Spacer()
                    (wizardState.sharingDirectoryURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
                }
                if !wizardState.useAppleVirtualization {
                    Toggle("Share is read only", isOn: $wizardState.sharingReadOnly)
                }
            } header: {
                Text("Directory Selected")
            }
            Section {
#if os(macOS)
                HStack {
                    Button {
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    .disabled(wizardState.isBusy)
                    Button {
                        wizardState.sharingDirectoryURL = nil
                    } label: {
                        Text("Clear")
                    }
                    .disabled(wizardState.isBusy)
                }
                .padding(.leading, 1)
#else
                Button {
                    isFileImporterPresented.toggle()
                } label: {
                    Text("Browse…")
                }
                .disabled(wizardState.isBusy)
                Button {
                    wizardState.sharingDirectoryURL = nil
                } label: {
                    Text("Clear")
                }
                .disabled(wizardState.isBusy)
#endif
                
                if wizardState.isBusy {
                    Spinner(size: .large)
                }
            } footer: {
                Text("Optionally select a directory to make accessible inside the VM. Note that support for shared directories varies by the guest operating system and may require additional guest drivers to be installed. See UTM support pages for more details.")
            }
        }
        .navigationTitle(Text("Shared Directory"))
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.folder], onCompletion: processDirectory)
    }
    
    private func processDirectory(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                wizardState.sharingDirectoryURL = url
            }
        }
    }
}

struct VMWizardSharingView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardSharingView(wizardState: wizardState)
    }
}
