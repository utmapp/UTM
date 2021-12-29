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
    @State private var useVhdx: Bool = false
    
    var body: some View {
        VStack {
            Text("Windows")
                .font(.largeTitle)
            if useVhdx {
                Link("Download Windows 11 for ARM64 Preview VHDX", destination: URL(string: "https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64")!)
                Text("Boot VHDX Image:")
                    .padding(.top)
            } else {
                Link("Generate Windows Installer ISO", destination: URL(string: "https://uupdump.net/")!)
                Text("Boot ISO Image:")
                    .padding(.top)
            }
            Toggle("Import VHDX Image", isOn: $useVhdx)
            Text((useVhdx ? wizardState.windowsBootVhdx?.lastPathComponent : wizardState.bootImageURL?.lastPathComponent) ?? " ")
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
            Spacer()
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
        .onAppear {
            if wizardState.windowsBootVhdx != nil {
                useVhdx = true
            } else {
                #if arch(arm64)
                useVhdx = wizardState.useVirtualization
                #endif
            }
        }
    }
    
    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWork {
            let url = try result.get()
            DispatchQueue.main.async {
                if useVhdx {
                    wizardState.windowsBootVhdx = url
                    wizardState.bootImageURL = nil
                    wizardState.isSkipBootImage = true
                } else {
                    wizardState.windowsBootVhdx = nil
                    wizardState.bootImageURL = url
                    wizardState.isSkipBootImage = false
                }
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
