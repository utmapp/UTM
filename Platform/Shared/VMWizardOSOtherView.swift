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
    
    var body: some View {
#if os(macOS)
        Text("Other")
            .font(.largeTitle)
#endif
        List {
            if !wizardState.isSkipBootImage {
                Section {
                    Text("Boot ISO Image:")
                    (wizardState.bootImageURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
                    Button {
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    .disabled(wizardState.isBusy)
                    .padding(.leading, 1)
                    if wizardState.isBusy {
                        Spinner(size: .large)
                    }
                } header: {
                    Text("File Imported")
                }
            }
            Section {
                Toggle("Skip ISO boot", isOn: $wizardState.isSkipBootImage)
            } header: {
                Text("Advanced")
            }
        }
        .navigationTitle(Text("Other"))
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
