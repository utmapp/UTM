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
import Virtualization

@available(macOS 12, *)
struct VMWizardOSMacView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("macOS")
                .font(.largeTitle)
            Text("To install macOS, you need to download a recovery IPSW. If you do not select an existing IPSW, the latest macOS IPSW will be downloaded from Apple.")
                .padding()
            #if arch(arm64)
            if let selected = wizardState.macRecoveryIpswURL {
                Text(selected.lastPathComponent)
                    .font(.caption)
            }
            #endif
            HStack {
                Button {
                    isFileImporterPresented.toggle()
                } label: {
                    Text("Browse")
                }
                Button {
                    wizardState.macRecoveryIpswURL = nil
                    wizardState.macPlatform = nil
                } label: {
                    Text("Clear")
                }
            }.disabled(wizardState.isBusy)
            .buttonStyle(BrowseButtonStyle())
            if wizardState.isBusy {
                BigWhiteSpinner()
            }
            Spacer()
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processIpsw)
    }
    
    private func processIpsw(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            #if arch(arm64)
            let url = try result.get()
            let image = try await VZMacOSRestoreImage.image(from: url)
            guard let model = image.mostFeaturefulSupportedConfiguration?.hardwareModel else {
                throw NSLocalizedString("Your machine does not support running this IPSW.", comment: "VMWizardOSMacView")
            }
            wizardState.macPlatform = MacPlatform(newHardware: model)
            wizardState.macRecoveryIpswURL = url
            wizardState.isSkipBootImage = true
            wizardState.bootImageURL = nil
            wizardState.next()
            #else
            throw NSLocalizedString("macOS guests are only supported on ARM64 devices.", comment: "VMWizardOSMacView")
            #endif
        }
    }
}

@available(macOS 12, *)
struct VMWizardOSMacView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSMacView(wizardState: wizardState)
    }
}
