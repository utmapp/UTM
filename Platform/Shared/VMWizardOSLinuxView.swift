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

struct VMWizardOSLinuxView: View {
    private enum SelectImage {
        case kernel
        case initialRamdisk
        case rootImage
        case bootImage
    }
    
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    @State private var selectImage: SelectImage = .kernel
    
    private var hasVenturaFeatures: Bool {
        if #available(macOS 13, *) {
            return true
        } else {
            return false
        }
    }
    
    var body: some View {
#if os(macOS)
        Text("Linux")
            .font(.largeTitle)
#endif
        List {
#if os(macOS)
            if wizardState.useVirtualization {
                DetailedSection("Virtualization Engine", description: "Apple Virtualization is experimental and only for advanced use cases. Leave unchecked to use QEMU, which is recommended.") {
                    Toggle("Use Apple Virtualization", isOn: $wizardState.useAppleVirtualization)
                }
            }
#endif
            
            Section {
                Toggle("Boot from kernel image", isOn: $wizardState.useLinuxKernel)
                    .help("If set, boot directly from a raw kernel image and initrd. Otherwise, boot from a supported ISO.")
                    .disabled(wizardState.useAppleVirtualization && !hasVenturaFeatures)
                if !wizardState.useLinuxKernel {
#if arch(arm64)
                Link("Download Ubuntu Server for ARM", destination: URL(string: "https://ubuntu.com/download/server/arm")!)
                    .buttonStyle(.borderless)
#else
                Link("Download Ubuntu Desktop", destination: URL(string: "https://ubuntu.com/download/desktop")!)
                    .buttonStyle(.borderless)
#endif
                }
            } header: {
                Text("Boot Image Type")
            }
            
            #if arch(arm64)
            if #available(macOS 13, *), wizardState.useAppleVirtualization {
                Section {
                    Toggle("Enable Rosetta (x86_64 Emulation)", isOn: $wizardState.linuxHasRosetta)
                    Link("Installation Instructions", destination: URL(string: "https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496")!)
                        .buttonStyle(.borderless)
                    Text("Note: The file system tag for mounting the installer is 'rosetta'.")
                        .font(.footnote)
                } header: {
                    Text("Additional Options")
                }
            }
            #endif
            
            if wizardState.useLinuxKernel {
                
                Section {
                    (wizardState.linuxKernelURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
                    Button {
                        selectImage = .kernel
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    .padding(.leading, 1)
                } header: {
                    if wizardState.useAppleVirtualization {
                        Text("Uncompressed \(Text("Linux kernel (required):"))")
                    } else {
                        Text("Linux kernel (required):")
                    }
                }
                
                Section {
                    (wizardState.linuxInitialRamdiskURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
#if os(macOS)
                    HStack {
                        Button {
                            selectImage = .initialRamdisk
                            isFileImporterPresented.toggle()
                        } label: {
                            Text("Browse…")
                        }
                        .disabled(wizardState.isBusy)
                        .padding(.leading, 1)
                        Button {
                            wizardState.linuxInitialRamdiskURL = nil
                        } label: {
                            Text("Clear")
                        }
                        .padding(.leading, 1)
                    }
#else
                    Button {
                        selectImage = .initialRamdisk
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    .disabled(wizardState.isBusy)
                    .padding(.leading, 1)
                    Button {
                        wizardState.linuxInitialRamdiskURL = nil
                    } label: {
                        Text("Clear")
                    }
                    .padding(.leading, 1)
#endif
                    
                } header: {
                    if wizardState.useAppleVirtualization {
                        Text("Uncompressed \(Text("Linux initial ramdisk (optional):"))")
                    } else {
                        Text("Linux initial ramdisk (optional):")
                    }
                }
                
                Section {
                    (wizardState.linuxRootImageURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
#if os(macOS)
                    HStack {
                        Button {
                            selectImage = .rootImage
                            isFileImporterPresented.toggle()
                        } label: {
                            Text("Browse…")
                        }
                        Button {
                            wizardState.linuxRootImageURL = nil
                        } label: {
                            Text("Clear")
                        }
                    }
#else
                    Button {
                        selectImage = .rootImage
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    Button {
                        wizardState.linuxRootImageURL = nil
                    } label: {
                        Text("Clear")
                    }
#endif
                    
                } header: {
                    Text("Linux Root FS Image (optional):")
                }
                
                Section {
                    (wizardState.bootImageURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
#if os(macOS)
                    HStack {
                        Button {
                            selectImage = .bootImage
                            isFileImporterPresented.toggle()
                        } label: {
                            Text("Browse…")
                        }
                        .disabled(wizardState.isBusy)
                        .padding(.leading, 1)
                        Button {
                            wizardState.bootImageURL = nil
                            wizardState.isSkipBootImage = true
                        } label: {
                            Text("Clear")
                        }
                        .disabled(wizardState.isBusy)
                        .padding(.leading, 1)
                    }
#else
                    Button {
                        selectImage = .bootImage
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }
                    .disabled(wizardState.isBusy)
                    .padding(.leading, 1)
                    Button {
                        wizardState.bootImageURL = nil
                        wizardState.isSkipBootImage = true
                    } label: {
                        Text("Clear")
                    }
                    .disabled(wizardState.isBusy)
                    .padding(.leading, 1)
#endif
                    
                } header: {
                    Text("Boot ISO Image (optional):")
                }
                
                Section {
                    TextField("Boot Arguments", text: $wizardState.linuxBootArguments)
                } header: {
                    Text("Boot Arguments")
                }
            } else {
                Section {
                    Text("Boot ISO Image:")
                    (wizardState.bootImageURL?.lastPathComponent.map { Text($0) } ?? Text("Empty"))
                        .font(.caption)
                    Button {
                        selectImage = .bootImage
                        isFileImporterPresented.toggle()
                    } label: {
                        Text("Browse…")
                    }.disabled(wizardState.isBusy)
                } header: {
                    Text("File Imported")
                }
            }
            if wizardState.isBusy {
                Spinner(size: .large)
            }
            
            
        }
        .navigationTitle(Text("Linux"))
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
    }
    
    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                switch selectImage {
                case .kernel:
                    wizardState.linuxKernelURL = url
                case .initialRamdisk:
                    wizardState.linuxInitialRamdiskURL = url
                case .rootImage:
                    wizardState.linuxRootImageURL = url
                case .bootImage:
                    wizardState.bootImageURL = url
                    wizardState.isSkipBootImage = false
                }
            }
        }
    }
}

struct VMWizardOSLinuxView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSLinuxView(wizardState: wizardState)
    }
}
