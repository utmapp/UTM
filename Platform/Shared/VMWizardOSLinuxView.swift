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

@available(iOS 14, macOS 11, *)
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
    
    var body: some View {
        VStack {
            Text("Linux")
                .font(.largeTitle)
            #if os(macOS)
            if wizardState.useVirtualization {
                Toggle("Use Apple Virtualization", isOn: $wizardState.useAppleVirtualization)
                    .help("If set, use Apple's virtualization engine. Otherwise, use QEMU's virtualization engine.")
            }
            #endif
            Toggle("Boot from kernel image", isOn: $wizardState.useLinuxKernel)
                .help("If set, boot directly from a raw kernel image and initrd. Otherwise, boot from a supported ISO.")
                .disabled(wizardState.useAppleVirtualization)
            if wizardState.useLinuxKernel {
                ScrollView {
                    Group {
                        Text("Linux kernel (required):")
                            .padding(.top)
                        Text(wizardState.linuxKernelURL?.lastPathComponent ?? " ")
                            .font(.caption)
                        Button {
                            selectImage = .kernel
                            isFileImporterPresented.toggle()
                        } label: {
                            Text("Browse")
                        }
                        
                        Text("Linux initial ramdisk (optional):")
                            .padding(.top)
                        Text(wizardState.linuxInitialRamdiskURL?.lastPathComponent ?? " ")
                            .font(.caption)
                        HStack {
                            Button {
                                selectImage = .initialRamdisk
                                isFileImporterPresented.toggle()
                            } label: {
                                Text("Browse")
                            }
                            Button {
                                wizardState.linuxInitialRamdiskURL = nil
                            } label: {
                                Text("Clear")
                            }
                        }
                    }.disabled(wizardState.isBusy)
                    .buttonStyle(BrowseButtonStyle())
                     
                    Group{
                        Text("Linux Root FS Image (optional):")
                            .padding(.top)
                        Text(wizardState.linuxRootImageURL?.lastPathComponent ?? " ")
                            .font(.caption)
                        HStack {
                            Button {
                                selectImage = .rootImage
                                isFileImporterPresented.toggle()
                            } label: {
                                Text("Browse")
                            }
                            Button {
                                wizardState.linuxRootImageURL = nil
                            } label: {
                                Text("Clear")
                            }
                        }
                        
                        Text("Boot ISO Image (optional):")
                            .padding(.top)
                        Text(wizardState.bootImageURL?.lastPathComponent ?? " ")
                            .font(.caption)
                        HStack {
                            Button {
                                selectImage = .bootImage
                                isFileImporterPresented.toggle()
                            } label: {
                                Text("Browse")
                            }
                            Button {
                                wizardState.bootImageURL = nil
                                wizardState.isSkipBootImage = true
                            } label: {
                                Text("Clear")
                            }
                        }
                    }.disabled(wizardState.isBusy)
                    .buttonStyle(BrowseButtonStyle())
                    
                    TextField("Boot Arguments", text: $wizardState.linuxBootArguments)
                }
            } else {
                #if arch(arm64)
                Link("Download Ubuntu Server for ARM", destination: URL(string: "https://ubuntu.com/download/server/arm")!)
                    .buttonStyle(BorderlessButtonStyle())
                #else
                Link("Download Ubuntu Desktop", destination: URL(string: "https://ubuntu.com/download/desktop")!)
                    .buttonStyle(BorderlessButtonStyle())
                #endif
                Text("Boot ISO Image:")
                    .padding(.top)
                Text(wizardState.bootImageURL?.lastPathComponent ?? " ")
                    .font(.caption)
                Button {
                    selectImage = .bootImage
                    isFileImporterPresented.toggle()
                } label: {
                    Text("Browse")
                }.disabled(wizardState.isBusy)
                .buttonStyle(BrowseButtonStyle())
            }
            if wizardState.isBusy {
                BigWhiteSpinner()
            }
            Spacer()
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
    }
    
    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWork {
            let url = try result.get()
            DispatchQueue.main.async {
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

@available(iOS 14, macOS 11, *)
struct VMWizardOSLinuxView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSLinuxView(wizardState: wizardState)
    }
}
