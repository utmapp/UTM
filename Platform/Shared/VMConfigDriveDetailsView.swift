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

private let bytesInMib: Int64 = 1024 * 1024

@available(iOS 14, macOS 11, *)
struct VMConfigDriveDetailsView: View {
    @ObservedObject var config: UTMQemuConfigurationDrive
    @Binding var triggerRefresh: Bool
    let onDelete: (() -> Void)?
    
    @EnvironmentObject private var data: UTMData
    @State private var isImporterPresented: Bool = false
    
    let helpMessage: LocalizedStringKey = "Reclaim disk space by re-converting the disk image."
    let confirmMessage: LocalizedStringKey = "Would you like to re-convert this disk image to reclaim unused space? Note this will require enough temporary space to perform the conversion. You are strongly encouraged to back-up this VM before proceeding."
    @State private var isConfirmConvertShown: Bool = false
    
    var body: some View {
        Form {
            Toggle(isOn: $config.isRemovable.animation(), label: {
                Text("Removable Drive")
            }).disabled(true)
            if !config.isRemovable {
                HStack {
                    Text("Name")
                    Spacer()
                    if let imageName = config.imageName {
                        Text(imageName)
                            .lineLimit(1)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("(new)")
                    }
                }
            } else {
                HStack {
                    TextField("Path", text: .constant(config.imageURL?.path ?? ""))
                        .disabled(true)
                    Button("Clear") {
                        config.imageURL = nil
                    }
                    Button("Browse…") {
                        isImporterPresented.toggle()
                    }.fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.item]) { result in
                        data.busyWorkAsync {
                            let url = try result.get()
                            await MainActor.run {
                                config.imageURL = url
                            }
                        }
                    }
                }
            }
            VMConfigConstantPicker("Image Type", selection: $config.imageType)
            .onChange(of: config.imageType) { _ in
                triggerRefresh.toggle()
            }
            if config.imageType == .disk || config.imageType == .cd {
                VMConfigConstantPicker("Interface", selection: $config.interface)
                .onChange(of: config.interface) { _ in
                    triggerRefresh.toggle()
                }
            }
            
            if let imageUrl = config.imageURL, let fileSize = data.computeSize(for: imageUrl) {
                DefaultTextField("Size", text: .constant(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))).disabled(true)
            } else if config.sizeMib > 0 {
                DefaultTextField("Size", text: .constant(ByteCountFormatter.string(fromByteCount: Int64(config.sizeMib) * bytesInMib, countStyle: .file))).disabled(true)
            }
            
            #if os(macOS)
            HStack {
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Label("Delete Drive", systemImage: "externaldrive.badge.minus")
                            .foregroundColor(.red)
                    }.help("Delete this drive.")
                }
                
                if let imageUrl = config.imageURL, FileManager.default.fileExists(atPath: imageUrl.path) {
                    if #available(macOS 12, *) {
                        Button(action: { isConfirmConvertShown.toggle() }) {
                            Label("Reclaim Space", systemImage: "arrow.3.trianglepath")
                        }.help(helpMessage)
                        .alert(confirmMessage, isPresented: $isConfirmConvertShown) {
                            Button("Cancel", role: .cancel) {}
                            Button("Reclaim", role: .destructive) { reclaimSpace(for: imageUrl, withCompression: false) }
                            Button("Reclaim and Compress", role: .destructive) { reclaimSpace(for: imageUrl, withCompression: true) }
                        }
                    } else {
                        Button(action: { isConfirmConvertShown.toggle() }) {
                            Label("Reclaim Space", systemImage: "arrow.3.trianglepath")
                        }.help(helpMessage)
                        .alert(isPresented: $isConfirmConvertShown) {
                            Alert(title: Text(confirmMessage), primaryButton: .cancel(), secondaryButton: .destructive(Text("Reclaim")) { reclaimSpace(for: imageUrl, withCompression: false) })
                        }
                    }
                }
            }
            #endif
        }
    }
    
    #if os(macOS)
    private func reclaimSpace(for driveUrl: URL, withCompression isCompressed: Bool) {
        data.busyWorkAsync {
            try await data.reclaimSpace(for: driveUrl, withCompression: isCompressed)
        }
    }
    #endif
}
