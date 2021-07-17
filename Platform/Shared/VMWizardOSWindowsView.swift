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
struct VMWizardOSWindowsView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("Windows")
                .font(.largeTitle)
                .padding()
            #if arch(arm64)
            Link("Download Windows 10 for ARM64 Preview", destination: URL(string: "https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64")!)
            Text("Boot VHDX Image")
                .padding()
            #else
            Text("Boot ISO Image")
                .padding()
            #endif
            if let selected = wizardState.bootImageURL {
                Text(selected.lastPathComponent)
                    .font(.caption)
            }
            Button {
                isFileImporterPresented.toggle()
            } label: {
                Text("Browse")
            }.buttonStyle(BigButtonStyle(width: 150, height: 50))
            .disabled(wizardState.isBusy)
            if wizardState.isBusy {
                BigWhiteSpinner()
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
struct VMWizardOSWindowsView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSWindowsView(wizardState: wizardState)
    }
}
