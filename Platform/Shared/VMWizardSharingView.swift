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
        VStack {
            Text("Shared Directory")
                .font(.largeTitle)
            Text("Optionally select a directory to make accessible inside the VM. Note that support for shared directories varies by the guest operating system and may require additional guest drivers to be installed. See UTM support pages for more details.")
                .padding()
            Text(wizardState.sharingDirectoryURL?.lastPathComponent ?? " ")
                .font(.caption)
            HStack {
                Button {
                    isFileImporterPresented.toggle()
                } label: {
                    Text("Browse")
                }
                Button {
                    wizardState.sharingDirectoryURL = nil
                } label: {
                    Text("Clear")
                }
            }.disabled(wizardState.isBusy)
            Spacer()
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.folder], onCompletion: processDirectory)
    }
    
    private func processDirectory(_ result: Result<URL, Error>) {
        wizardState.busyWork {
            let url = try result.get()
            DispatchQueue.main.async {
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
