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
    @State private var isSelectingShare: Bool = false
    @State private var selectedDrive: UTMQemuConfigurationDrive?
    @State private var isRefreshRequired: Bool = false
    
    private let noneText = NSLocalizedString("none", comment: "VMToolbarDriveMenuView")
    
    var body: some View {
        Menu {
            if config.sharing.directoryShareMode == .webdav {
                Menu {
                    Button {
                        selectedDrive = nil
                        isSelectingShare = true
                        isFileImporterShown.toggle()
                    } label: {
                        MenuLabel("Change…", systemImage: "folder.badge.person.crop")
                    }
                    Button {
                        Task {
                            await session.vm.clearSharedDirectory()
                        }
                    } label: {
                        MenuLabel("Clear…", systemImage: "clear")
                    }
                } label: {
                    let url = session.vm.sharedDirectoryURL
                    MenuLabel("Shared Directory: \(url?.lastPathComponent ?? noneText)", systemImage: url == nil ? "folder.badge.person.crop" : "folder.fill.badge.person.crop")
                }
                Divider()
            }
            ForEach(config.drives) { drive in
                if drive.isExternal {
                    #if !WITH_REMOTE // FIXME: implement remote feature
                    Menu {
                        Button {
                            selectedDrive = drive
                            isSelectingShare = false
                            isFileImporterShown.toggle()
                        } label: {
                            MenuLabel("Change…", systemImage: "opticaldisc")
                        }
                        Button {
                            ejectDriveImage(for: drive)
                        } label: {
                            MenuLabel("Eject…", systemImage: "eject")
                        }
                    } label: {
                        MenuLabel(label(for: drive), systemImage: session.vm.externalImageURL(for: drive) == nil ? "opticaldiscdrive" : "opticaldiscdrive.fill")
                    }
                    #else
                    Button {
                    } label: {
                        MenuLabel(label(for: drive), systemImage: session.vm.externalImageURL(for: drive) == nil ? "opticaldiscdrive" : "opticaldiscdrive.fill")
                    }.disabled(true)
                    #endif
                } else if drive.imageType == .disk || drive.imageType == .cd {
                    Button {
                    } label: {
                        MenuLabel(label(for: drive), systemImage: "internaldrive")
                    }.disabled(true)
                }
            }
        } label: {
            Label("Disk", systemImage: "opticaldisc")
        }.fileImporter(isPresented: $isFileImporterShown, allowedContentTypes: isSelectingShare ? [.folder] : [.item]) { result in
            switch result {
            case .success(let success):
                if isSelectingShare {
                    changeSharedDirectory(to: success)
                } else if let drive = selectedDrive {
                    changeDriveImage(for: drive, with: success)
                }
            case .failure(let failure):
                session.nonfatalError = failure.localizedDescription
            }
        }
        .onChange(of: isRefreshRequired) { _ in
            // dummy here since UTMDrive is not observable
            // this forces a redraw when we toggle
        }
    }
    
    private func changeDriveImage(for drive: UTMQemuConfigurationDrive, with imageURL: URL) {
        Task.detached(priority: .background) {
            do {
                try await session.vm.changeMedium(drive, to: imageURL)
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
    
    private func changeSharedDirectory(to url: URL) {
        Task.detached(priority: .background) {
            do {
                try await session.vm.changeSharedDirectory(to: url)
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
    
    private func ejectDriveImage(for drive: UTMQemuConfigurationDrive) {
        Task.detached(priority: .background) {
            do {
                try await session.vm.eject(drive)
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
    
    private func label(for drive: UTMQemuConfigurationDrive) -> String {
        let imageURL = session.vm.externalImageURL(for: drive) ?? drive.imageURL
        return String.localizedStringWithFormat(NSLocalizedString("%@ (%@): %@", comment: "VMToolbarDriveMenuView"),
                                                drive.imageType.prettyValue,
                                                drive.interface.prettyValue,
                                                imageURL?.lastPathComponent ?? noneText)
    }
}

struct VMToolbarDriveMenuView_Previews: PreviewProvider {
    @StateObject static var config = UTMQemuConfiguration()
    static var previews: some View {
        VMToolbarDriveMenuView(config: config)
    }
}
