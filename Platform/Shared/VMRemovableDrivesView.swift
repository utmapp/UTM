//
// Copyright © 2020 osy. All rights reserved.
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
struct VMRemovableDrivesView: View {
    var vm: UTMVirtualMachine
    @EnvironmentObject private var data: UTMData
    @ObservedObject private var config: UTMConfiguration
    @ObservedObject private var sessionConfig: UTMViewState
    @Environment(\.importFiles) private var importFiles: ImportFilesAction
    
    init(vm: UTMVirtualMachine) {
        self.vm = vm
        self.config = vm.configuration
        self.sessionConfig = vm.viewState
    }
    
    var body: some View {
        Group {
            if config.shareDirectoryEnabled {
                HStack {
                    Label("Shared Directory", systemImage: "externaldrive.badge.person.crop")
                    Spacer()
                    Text(resolveBookmark(sessionConfig.sharedDirectory)).truncationMode(.head)
                    Button(action: clearShareDirectory, label: {
                        Text("Clear")
                    })
                    Button(action: selectShareDirectory, label: {
                        Text("Browse")
                    })
                }
            }
            ForEach(vm.drives) { drive in
                if drive.status != .fixed {
                    HStack {
                        Label("Interface: \(drive.interface ?? "")", systemImage: drive.imageType == .CD ? "opticaldiscdrive" : "externaldrive")
                        Spacer()
                        Text(resolveBookmark(sessionConfig.bookmark(forRemovableDrive: drive.name ?? ""))).truncationMode(.head)
                        Button(action: { clearRemovableImage(forDrive: drive) }, label: {
                            Text("Clear")
                        })
                        Button(action: { selectRemovableImage(forDrive: drive) }, label: {
                            Text("Browse")
                        })
                    }
                }
            }
        }
    }
    
    private func selectShareDirectory() {
        importFiles(singleOfType: [.folder]) { ret in
            data.busyWork {
                switch ret {
                case .success(let url):
                    try vm.changeSharedDirectory(url)
                    break
                case .failure(let err):
                    throw err
                case .none:
                    break
                }
            }
        }
    }
    
    private func clearShareDirectory() {
        vm.clearSharedDirectory()
    }
    
    private func selectRemovableImage(forDrive drive: UTMDrive) {
        importFiles(singleOfType: [.data]) { ret in
            data.busyWork {
                switch ret {
                case .success(let url):
                    try vm.changeMedium(for: drive, url: url)
                    break
                case .failure(let err):
                    throw err
                case .none:
                    break
                }
            }
        }
    }
    
    private func clearRemovableImage(forDrive drive: UTMDrive) {
        data.busyWork {
            try vm.ejectDrive(drive, force: true)
        }
    }
    
    private func resolveBookmark(_ bookmark: Data?) -> String {
        #if os(macOS)
        let resolveOption: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let resolveOption: URL.BookmarkResolutionOptions = []
        #endif
        guard let bookmarkData = bookmark else {
            return NSLocalizedString("(none)", comment: "VMRemovableDrivesView")
        }
        var stale: Bool = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData,
                                 options: resolveOption,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else {
            return NSLocalizedString("(error)", comment: "VMRemovableDrivesView")
        }
        if stale {
            logger.warning("bookmark for '\(url.path)' is stale!")
        }
        return url.lastPathComponent
    }
}

@available(iOS 14, macOS 11, *)
struct VMRemovableDrivesView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMRemovableDrivesView(vm: UTMVirtualMachine(configuration: config, withDestinationURL: URL(fileURLWithPath: "")))
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
