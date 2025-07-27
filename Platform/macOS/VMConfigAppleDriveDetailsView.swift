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

private let bytesInMib: Int64 = 1024 * 1024
private let mibInGib: Int = 1024

struct VMConfigAppleDriveDetailsView: View {
    private enum ConfirmItem: Identifiable {
        case resize(URL)

        var id: Int {
            switch self {
            case .resize(_): return 3
            }
        }
    }

    @Binding var config: UTMAppleConfigurationDrive
    @Binding var requestDriveDelete: UTMAppleConfigurationDrive?

    @EnvironmentObject private var data: UTMData
    
    @State private var confirmAlert: ConfirmItem?
    @State private var isResizePopoverShown: Bool = false
    @State private var proposedSizeMib: Int = 0

    var body: some View {
        Form {
            Toggle(isOn: $config.isExternal, label: {
                Text("Removable Drive")
            }).disabled(true)
            TextField("Name", text: .constant(config.imageURL?.lastPathComponent ?? NSLocalizedString("(New Drive)", comment: "VMConfigAppleDriveDetailsView")))
                .disabled(true)
            Toggle("Read Only?", isOn: $config.isReadOnly)
            if #available(macOS 14, *), !config.isExternal {
                Toggle(isOn: $config.isNvme,
                       label: {
                    Text("Use NVMe Interface")
                }).help("If checked, use NVMe instead of virtio as the disk interface, available on macOS 14+ for Linux guests only. This interface is slower but less likely to encounter filesystem errors.")
            }
            DefaultTextField("Size", text: .constant(config.sizeString)).disabled(true)
            HStack {
                if #unavailable(macOS 12) {
                    Button {
                        requestDriveDelete = config
                    } label: {
                        Label("Delete Drive", systemImage: "externaldrive.badge.minus")
                            .foregroundColor(.red)
                    }.help("Delete this drive.")
                }

                if #available(macOS 14, *), let imageUrl = config.imageURL, FileManager.default.fileExists(atPath: imageUrl.path) {
                    Button {
                        isResizePopoverShown.toggle()
                    } label: {
                        Label("Resize…", systemImage: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right")
                    }.help("Increase the size of the disk image.")
                    .popover(isPresented: $isResizePopoverShown) {
                        ResizePopoverView(imageURL: imageUrl, proposedSizeMib: $proposedSizeMib) {
                            confirmAlert = .resize(imageUrl)
                        }.padding()
                        .frame(minHeight: 120)
                    }
                }
            }.alert(item: $confirmAlert) { item in
                switch item {
                case .resize(let imageURL):
                    Alert(title: Text("Resizing is experimental and could result in data loss. You are strongly encouraged to back-up this VM before proceeding. Would you like to resize to \(proposedSizeMib / mibInGib) GiB?"), primaryButton: .destructive(Text("Resize")) {
                        resizeDrive(for: imageURL, sizeInMib: proposedSizeMib)
                    }, secondaryButton: .cancel())
                }
            }
        }
    }

    private func resizeDrive(for driveUrl: URL, sizeInMib: Int) {
        if #available(macOS 14, *) {
            data.busyWorkAsync {
                try await data.resizeAppleDrive(for: driveUrl, sizeInMib: sizeInMib)
            }
        }
    }
}

@available(macOS 14, *)
private struct ResizePopoverView: View {
    let imageURL: URL
    @Binding var proposedSizeMib: Int
    let onConfirm: () -> Void
    @EnvironmentObject private var data: UTMData

    @State private var currentSize: Int64?
    @State private var imageFormat: String?

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
                if let imageFormat = imageFormat {
                    Text("Image format: \(imageFormat)")
                }
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
                (imageFormat, currentSize) = data.appleDriveInfo(for: imageURL)
                proposedSizeMib = minSizeMib
            }
        }
    }
}

struct VMConfigAppleDriveDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        VMConfigAppleDriveDetailsView(config: .constant(UTMAppleConfigurationDrive(newSize: 100)), requestDriveDelete: .constant(nil))
    }
}
