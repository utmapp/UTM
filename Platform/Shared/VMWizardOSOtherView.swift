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

@available(iOS 14, macOS 11, *)
struct VMWizardOSOtherView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("Boot Image")
                .font(.largeTitle)
            Toggle("Skip ISO boot (advanced)", isOn: $wizardState.isSkipBootImage)
            if !wizardState.isSkipBootImage {
                Text("Boot ISO Image:")
                    .padding(.top)
                Text(wizardState.bootImageURL?.lastPathComponent ?? " ")
                    .font(.caption)
                Button {
                    isFileImporterPresented.toggle()
                } label: {
                    Text("Browse")
                }.disabled(wizardState.isBusy)
                .buttonStyle(BrowseButtonStyle())
                if wizardState.isBusy {
                    BigWhiteSpinner()
                }
            }
            Spacer()
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
    }
    
    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWork {
            let url = try result.get()
            DispatchQueue.main.async {
                wizardState.bootImageURL = url
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMWizardOSOtherView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSOtherView(wizardState: wizardState)
    }
}
