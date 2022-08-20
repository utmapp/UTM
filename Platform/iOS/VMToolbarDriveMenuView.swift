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
    @State var config: UTMQemuConfiguration
    @EnvironmentObject private var session: VMSessionState
    @State private var isFileImporterShown: Bool = false
    @State private var selectedDrive: Binding<UTMQemuConfigurationDrive>?
    @State private var isRefreshRequired: Bool = false
    
    var body: some View {
        Menu {
            ForEach($config.drives) { $drive in
                if drive.isExternal {
                    Menu {
                        Button {
                            selectedDrive = $drive
                            isFileImporterShown.toggle()
                        } label: {
                            MenuLabel("Change…", systemImage: "opticaldisc")
                        }
                        Button {
                            ejectDriveImage(for: $drive)
                        } label: {
                            MenuLabel("Eject…", systemImage: "eject")
                        }
                    } label: {
                        MenuLabel(drive.label, systemImage: drive.imageURL == nil ? "opticaldiscdrive" : "opticaldiscdrive.fill")
                    }
                } else if drive.imageType == .disk || drive.imageType == .cd {
                    Button {
                    } label: {
                        MenuLabel(drive.label, systemImage: "internaldrive")
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
    
    private func changeDriveImage(for driveBinding: Binding<UTMQemuConfigurationDrive>, with imageURL: URL) {
        Task.detached(priority: .background) {
            do {
                try await session.vm.changeMedium(&driveBinding.wrappedValue, with: imageURL)
                Task { @MainActor in
                    isRefreshRequired.toggle()
                }
            } catch {
                Task { @MainActor in
                    session.nonfatalError = error.localizedDescription
                }
            }
        }
    }
    
    private func ejectDriveImage(for driveBinding: Binding<UTMQemuConfigurationDrive>) {
        Task.detached(priority: .background) {
            do {
                try await session.vm.eject(&driveBinding.wrappedValue)
                Task { @MainActor in
                    isRefreshRequired.toggle()
                }
            } catch {
                Task { @MainActor in
                    session.nonfatalError = error.localizedDescription
                }
            }
        }
    }
}

struct VMToolbarDriveMenuView_Previews: PreviewProvider {
    @StateObject static var config = UTMQemuConfiguration()
    static var previews: some View {
        VMToolbarDriveMenuView(config: config)
    }
}
