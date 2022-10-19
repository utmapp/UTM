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
                    if wizardState.useAppleVirtualization {
                        Link(destination: URL(string: "https://docs.getutm.app/guides/debian/")!) {
                            Label("Debian Install Guide", systemImage: "link")
                        }.buttonStyle(.borderless)
                    } else {
                        Link(destination: URL(string: "https://docs.getutm.app/guides/ubuntu/")!) {
                            Label("Ubuntu Install Guide", systemImage: "link")
                        }.buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Boot Image Type")
            }
            
            #if arch(arm64)
            if #available(macOS 13, *), wizardState.useAppleVirtualization {
                Section {
                    Toggle("Enable Rosetta (x86_64 Emulation)", isOn: $wizardState.linuxHasRosetta)
                    Link(destination: URL(string: "https://docs.getutm.app/advanced/rosetta/")!) {
                        Label("Installation Instructions", systemImage: "link")
                    }.buttonStyle(.borderless)
                } header: {
                    Text("Additional Options")
                }
            }
            #endif
            
            if wizardState.useLinuxKernel {
                
                Section {
                    FileBrowseField(url: $wizardState.linuxKernelURL, isFileImporterPresented: $isFileImporterPresented, hasClearButton: false) {
                        selectImage = .kernel
                    }.disabled(wizardState.isBusy)
                } header: {
                    if wizardState.useAppleVirtualization {
                        Text("Uncompressed Linux kernel (required)")
                    } else {
                        Text("Linux kernel (required)")
                    }
                }
                
                Section {
                    FileBrowseField(url: $wizardState.linuxInitialRamdiskURL, isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .initialRamdisk
                    }.disabled(wizardState.isBusy)
                } header: {
                    if wizardState.useAppleVirtualization {
                        Text("Uncompressed Linux initial ramdisk (optional)")
                    } else {
                        Text("Linux initial ramdisk (optional)")
                    }
                }
                
                Section {
                    FileBrowseField(url: $wizardState.linuxRootImageURL, isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .rootImage
                    }.disabled(wizardState.isBusy)
                } header: {
                    Text("Linux Root FS Image (optional)")
                }
                
                Section {
                    FileBrowseField(url: $wizardState.bootImageURL, isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .bootImage
                    }.disabled(wizardState.isBusy)
                } header: {
                    Text("Boot ISO Image (optional)")
                }
                
                Section {
                    TextField("Boot Arguments", text: $wizardState.linuxBootArguments)
                } header: {
                    Text("Boot Arguments")
                }
            } else {
                Section {
                    FileBrowseField(url: $wizardState.bootImageURL, isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .bootImage
                    }.disabled(wizardState.isBusy)
                } header: {
                    Text("Boot ISO Image")
                }
            }
            if wizardState.isBusy {
                Spinner(size: .large)
            }
            
            
        }
        #if os(iOS)
        .navigationTitle(Text("Linux"))
        #endif
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
