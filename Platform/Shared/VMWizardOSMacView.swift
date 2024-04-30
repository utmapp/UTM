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
    @State private var isFileImporterPresented = false

    var body: some View {
        VMWizardContent("macOS") {
            Section {
                Text("To install macOS, you need to download a recovery IPSW. If you do not select an existing IPSW, the latest macOS IPSW will be downloaded from Apple.")
                Spacer()

                Text("Drag and drop IPSW file here").foregroundColor(.secondary)
                Spacer()

                #if arch(arm64)
                if let selected = wizardState.macRecoveryIpswURL {
                    Text(selected.lastPathComponent)
                        .font(.caption)
                }
                FileBrowseField(url: $wizardState.macRecoveryIpswURL, isFileImporterPresented: $isFileImporterPresented)
                #endif
                if wizardState.isBusy {
                    Spinner(size: .large)
                }
                Spacer()
            } header: {
                Text("Import IPSW")
            }
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.ipsw], onCompletion: processIpsw)
        .onDrop(of: [.fileURL], delegate: self)
    }
    
    private func processIpsw(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            #if arch(arm64)
            let url = try result.get()
            let scopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if scopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let image = try await VZMacOSRestoreImage.image(from: url)
            guard let model = image.mostFeaturefulSupportedConfiguration?.hardwareModel else {
                throw NSLocalizedString("Your machine does not support running this IPSW.", comment: "VMWizardOSMacView")
            }
            await MainActor.run {
                wizardState.macPlatform = UTMAppleConfigurationMacPlatform(newHardware: model)
                wizardState.macRecoveryIpswURL = url
                wizardState.macPlatformVersion = image.buildVersion.integerPrefix()
                wizardState.bootDevice = .none
                wizardState.bootImageURL = nil
                wizardState.next()
            }
            #else
            throw NSLocalizedString("macOS guests are only supported on ARM64 devices.", comment: "VMWizardOSMacView")
            #endif
        }
    }
}

@available(macOS 12, *)
extension VMWizardOSMacView: DropDelegate {

    func validateDrop(info: DropInfo) -> Bool {
        urlFrom(info: info) != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let url = urlFrom(info: info) else { return false }

        processIpsw(.success(url))
        return true
    }

    private func urlFrom(info: DropInfo) -> URL? {
        let providers = info.itemProviders(for: [.fileURL])
        guard providers.count == 1,
              let first = providers.first
            else { return nil }

        var validURL: URL?

        let group = DispatchGroup()
        group.enter()

        _ = first.loadObject(ofClass: URL.self) { url, _ in
            if url?.pathExtension == "ipsw" {
                validURL = url
            }
            group.leave()
        }

        group.wait()

        return validURL
    }
}

@available(macOS 12, *)
struct VMWizardOSMacView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSMacView(wizardState: wizardState)
    }
}
