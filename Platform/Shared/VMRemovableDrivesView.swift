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
    let vm: UTMVirtualMachine
    @EnvironmentObject private var data: UTMData
    @ObservedObject private var config: UTMConfiguration
    @ObservedObject private var sessionConfig: UTMViewState
    @State private var shareDirectoryFileImportPresented: Bool = false
    @State private var diskImageFileImportPresented: Bool = false
    @State private var currentDrive: UTMDrive?
    
    var fileManager: FileManager {
        FileManager.default
    }
    
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
                    Text(sessionConfig.sharedDirectoryPath ?? "").truncationMode(.head)
                    Button(action: clearShareDirectory, label: {
                        Text("Clear")
                    })
                    Button(action: { shareDirectoryFileImportPresented.toggle() }, label: {
                        Text("Browse")
                    })
                }.fileImporter(isPresented: $shareDirectoryFileImportPresented, allowedContentTypes: [.folder], onCompletion: selectShareDirectory)
            }
            ForEach(vm.drives) { drive in
                if drive.status != .fixed {
                    let path = sessionConfig.path(forRemovableDrive: drive.name ?? "") ?? ""
                    HStack {
                        Label("Interface: \(drive.interface ?? "")", systemImage: drive.imageType == .CD ? "opticaldiscdrive" : "externaldrive")
                        Spacer()
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Button(action: { clearRemovableImage(forDrive: drive) }, label: {
                            Text("Clear")
                        })
                        Button(action: {
                            currentDrive = drive
                            diskImageFileImportPresented.toggle()
                        }, label: {
                            Text("Browse")
                        })
                    }
                }
            }.fileImporter(isPresented: $diskImageFileImportPresented, allowedContentTypes: [.data]) { result in
                if let currentDrive = self.currentDrive {
                    selectRemovableImage(forDrive: currentDrive, result: result)
                    self.currentDrive = nil
                }
            }
        }
    }
    
    private func selectShareDirectory(result: Result<URL, Error>) {
        data.busyWork {
            switch result {
            case .success(let url):
                try vm.checkSandboxAccess(url)
                try vm.changeSharedDirectory(url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearShareDirectory() {
        vm.clearSharedDirectory()
    }
    
    private func selectRemovableImage(forDrive drive: UTMDrive, result: Result<URL, Error>) {
        data.busyWork {
            switch result {
            case .success(let url):
                try vm.changeMedium(for: drive, url: url)
                break
            case .failure(let err):
                throw err
            }
        }
    }
    
    private func clearRemovableImage(forDrive drive: UTMDrive) {
        data.busyWork {
            try vm.ejectDrive(drive, force: true)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMRemovableDrivesView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
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
