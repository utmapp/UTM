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
private let mibInGib: Int = 1024

struct VMConfigDriveDetailsView: View {
    private enum ConfirmItem: Identifiable {
        case reclaim(URL)
        case compress(URL)
        case resize(URL)
        
        var id: Int {
            switch self {
            case .reclaim(_): return 1
            case .compress(_): return 2
            case .resize(_): return 3
            }
        }
    }
    
    @Binding var config: UTMQemuConfigurationDrive
    @Binding var requestDriveDelete: UTMQemuConfigurationDrive?
    
    @EnvironmentObject private var data: UTMData
    @State private var isImporterPresented: Bool = false
    
    @State private var confirmAlert: ConfirmItem?
    @State private var isResizePopoverShown: Bool = false
    @State private var proposedSizeMib: Int = 0
    
    var body: some View {
        Form {
            Toggle(isOn: $config.isExternal.animation(), label: {
                Text("Removable Drive")
            }).disabled(true)
            if !config.isExternal {
                HStack {
                    Text("Name")
                    Spacer()
                    if let imageName = config.imageURL?.lastPathComponent ?? config.imageName {
                        Text(imageName)
                            .lineLimit(1)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("(new)")
                    }
                }
            } else {
                FileBrowseField(url: $config.imageURL, isFileImporterPresented: $isImporterPresented)
                .globalFileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.item]) { result in
                    data.busyWorkAsync {
                        let url = try result.get()
                        await MainActor.run {
                            config.imageURL = url
                        }
                    }
                }
            }
            VMConfigConstantPicker("Image Type", selection: $config.imageType)
            if config.imageType == .disk || config.imageType == .cd {
                VMConfigConstantPicker("Interface", selection: $config.interface)
            }
            
            if let imageUrl = config.imageURL, let fileSize = data.computeSize(for: imageUrl) {
                DefaultTextField("Size", text: .constant(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary))).disabled(true)
            } else if config.sizeMib > 0 {
                DefaultTextField("Size", text: .constant(ByteCountFormatter.string(fromByteCount: Int64(config.sizeMib) * bytesInMib, countStyle: .binary))).disabled(true)
            }
            
            #if os(macOS)
            HStack {
                Button {
                    requestDriveDelete = config
                } label: {
                    Label("Delete Drive", systemImage: "externaldrive.badge.minus")
                        .foregroundColor(.red)
                }.help("Delete this drive.")
                
                if let imageUrl = config.imageURL, FileManager.default.fileExists(atPath: imageUrl.path) {
                    Button {
                        confirmAlert = .reclaim(imageUrl)
                    } label: {
                        Label("Reclaim Space", systemImage: "arrow.3.trianglepath")
                    }.help("Reclaim disk space by re-converting the disk image.")
                    
                    Button {
                        confirmAlert = .compress(imageUrl)
                    } label: {
                        Label("Compress", systemImage: "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left")
                    }.help("Compress by re-converting the disk image and compressing the data.")
                    
                    Button {
                        isResizePopoverShown.toggle()
                    } label: {
                        Label("Resize…", systemImage: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right")
                    }.help("Increase the size of the disk image.")
                    .popover(isPresented: $isResizePopoverShown) {
                        ResizePopoverView(imageURL: imageUrl, proposedSizeMib: $proposedSizeMib) {
                            confirmAlert = .resize(imageUrl)
                        }.padding()
                    }
                }
            }.alert(item: $confirmAlert) { item in
                switch item {
                case .reclaim(let imageURL):
                    return Alert(title: Text("Would you like to re-convert this disk image to reclaim unused space? Note this will require enough temporary space to perform the conversion. You are strongly encouraged to back-up this VM before proceeding."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Reclaim")) { reclaimSpace(for: imageURL, withCompression: false) })
                case .compress(let imageURL):
                    return Alert(title: Text("Would you like to re-convert this disk image to reclaim unused space and apply compression? Note this will require enough temporary space to perform the conversion. Compression only applies to existing data and new data will still be written uncompressed. You are strongly encouraged to back-up this VM before proceeding."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Reclaim")) { reclaimSpace(for: imageURL, withCompression: true) })
                case .resize(let imageURL):
                    return Alert(title: Text("Resizing is experimental and could result in data loss. You are strongly encouraged to back-up this VM before proceeding. Would you like to resize to \(proposedSizeMib / mibInGib) GiB?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Resize")) {
                        resizeDrive(for: imageURL, sizeInMib: proposedSizeMib)
                    })
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
    
    private func resizeDrive(for driveUrl: URL, sizeInMib: Int) {
        data.busyWorkAsync {
            try await data.resizeQcow2Drive(for: driveUrl, sizeInMib: sizeInMib)
        }
    }
    #endif
}

#if os(macOS)
private struct ResizePopoverView: View {
    let imageURL: URL
    @Binding var proposedSizeMib: Int
    let onConfirm: () -> Void
    @EnvironmentObject private var data: UTMData
    
    @State private var currentSize: Int64?
    
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    private var sizeString: String? {
        if let currentSize = currentSize {
            return ByteCountFormatter.string(fromByteCount: currentSize, countStyle: .binary)
        } else {
            return nil
        }
    }
    
    private var minSizeMib: Int {
        Int((currentSize! + bytesInMib - 1) / bytesInMib)
    }
    
    var body: some View {
        VStack {
            if let sizeString = sizeString {
                Text("Minimum size: \(sizeString)")
                Form {
                    SizeTextField($proposedSizeMib, minSizeMib: minSizeMib)
                    Button("Resize") {
                        if proposedSizeMib > minSizeMib {
                            onConfirm()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } else {
                ProgressView("Calculating current size...")
            }
        }.onAppear {
            Task { @MainActor in
                currentSize = await data.qcow2DriveSize(for: imageURL)
                proposedSizeMib = minSizeMib
            }
        }
    }
}
#endif
