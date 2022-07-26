//
// Copyright © 2022 osy. All rights reserved.
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

struct VMToolbarDriveMenuView: View {
    @EnvironmentObject private var session: VMSessionState
    @State private var isFileImporterShown: Bool = false
    @State private var selectedDrive: UTMDrive?
    @State private var isRefreshRequired: Bool = false
    
    var body: some View {
        Menu {
            ForEach(session.vm.drives) { legacyDrive in
                if legacyDrive.status != .fixed {
                    Menu {
                        Button {
                            selectedDrive = legacyDrive
                            isFileImporterShown.toggle()
                        } label: {
                            Label("Change…", systemImage: "opticaldisc")
                        }
                        Button {
                            ejectDriveImage(for: legacyDrive)
                        } label: {
                            Label("Eject…", systemImage: "eject")
                        }
                    } label: {
                        Label(legacyDrive.label, systemImage: legacyDrive.status == .ejected ? "opticaldiscdrive" : "opticaldiscdrive.fill")
                    }
                } else {
                    Button {
                    } label: {
                        Label(legacyDrive.label, systemImage: "internaldrive")
                    }.disabled(true)
                }
            }
        } label: {
            Label("Disk", systemImage: "opticaldisc")
        }.fileImporter(isPresented: $isFileImporterShown, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let success):
                changeDriveImage(for: selectedDrive!, with: success)
            case .failure(let failure):
                session.nonfatalError = failure.localizedDescription
            }
        }
        .onChange(of: isRefreshRequired) { _ in
            // dummy here since UTMDrive is not observable
            // this forces a redraw when we toggle
        }
    }
    
    private func changeDriveImage(for legacyDrive: UTMDrive, with imageURL: URL) {
        do {
            try session.vm.changeMedium(for: legacyDrive, url: imageURL)
            isRefreshRequired.toggle()
        } catch {
            session.nonfatalError = error.localizedDescription
        }
    }
    
    private func ejectDriveImage(for legacyDrive: UTMDrive) {
        do {
            try session.vm.ejectDrive(legacyDrive, force: false)
            isRefreshRequired.toggle()
        } catch {
            session.nonfatalError = error.localizedDescription
        }
    }
}

struct VMToolbarDriveMenuView_Previews: PreviewProvider {
    static var previews: some View {
        VMToolbarDriveMenuView()
    }
}
