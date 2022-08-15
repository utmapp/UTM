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

struct VMWizardSummaryView: View {
    @ObservedObject var wizardState: VMWizardState
    @EnvironmentObject private var data: UTMData
    
    var storageDescription: String {
        var size = Int64(wizardState.storageSizeGib * wizardState.bytesInGib)
        #if arch(arm64)
        if wizardState.operatingSystem == .Windows && wizardState.useVirtualization {
            if let attributes = try? wizardState.bootImageURL?.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attributes.fileSize {
                size = Int64(fileSize)
            }
        }
        #endif
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var coreDescription: String {
        let cores = wizardState.systemCpuCount
        if cores == 0 {
            return NSLocalizedString("Default Cores", comment: "VMWizardSummaryView")
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("%lld Cores", comment: "VMWizardSummaryView"), cores)
        }
    }
    
    var body: some View {
        VStack {
            #if os(macOS)
            Text("Summary")
                .font(.largeTitle)
            ScrollView {
                Form {
                    info
                    Divider()
                    system
                        .disabled(true)
                    Divider()
                    boot
                        .disabled(true)
                    Divider()
                    sharing
                        .disabled(true)
                }
            }
            Spacer()
            #else
            Form {
                Section(header: Text("Information")) {
                    info
                }
                Section(header: Text("System")) {
                    system
                        .disabled(true)
                }
                Section(header: Text("Boot")) {
                    boot
                        .disabled(true)
                }
                Section(header: Text("Sharing")) {
                    sharing
                        .disabled(true)
                }
            }.textFieldStyle(.automatic)
            #endif
        }
        #if os(macOS)
        .padding([.horizontal, .bottom])
        #endif
        .navigationTitle(Text("Summary"))
        .onAppear {
            if wizardState.name == nil {
                let os = wizardState.operatingSystem
                if os == .Other {
                    wizardState.name = data.newDefaultVMName()
                } else {
                    wizardState.name = data.newDefaultVMName(base: os.rawValue)
                }
            }
        }
    }
    
    var info: some View {
        Group {
            TextField("Name", text: $wizardState.name.bound)
            #if os(macOS)
            Toggle("Open VM Settings", isOn: $wizardState.isOpenSettingsAfterCreation)
                .disabled(wizardState.isPendingIPSWDownload)
            #endif
        }
    }
    
    var system: some View {
        Group {
            TextField("Engine", text: .constant(wizardState.useAppleVirtualization ? "Apple Virtualization" : "QEMU"))
            Toggle("Use Virtualization", isOn: $wizardState.useVirtualization)
            if !wizardState.useAppleVirtualization {
                TextField("Architecture", text: .constant(wizardState.systemArchitecture.prettyValue))
                TextField("System", text: .constant(wizardState.systemTarget.prettyValue))
            }
            TextField("RAM", text: .constant(ByteCountFormatter.string(fromByteCount: Int64(wizardState.systemMemoryMib * wizardState.bytesInMib), countStyle: .memory)))
            TextField("CPU", text: .constant(coreDescription))
            TextField("Storage", text: .constant(storageDescription))
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                Toggle("Hardware OpenGL Acceleration", isOn: $wizardState.isGLEnabled)
            }
        }
    }
    
    var boot: some View {
        Group {
            TextField("Operating System", text: .constant(wizardState.operatingSystem.rawValue))
            Toggle("Skip Boot Image", isOn: $wizardState.isSkipBootImage)
            if !wizardState.isSkipBootImage {
                TextField("Boot Image", text: .constant(wizardState.bootImageURL?.path ?? ""))
            }
            switch wizardState.operatingSystem {
            case .macOS:
                #if os(macOS) && arch(arm64)
                TextField("IPSW", text: .constant(wizardState.macRecoveryIpswURL?.path ?? ""))
                #else
                EmptyView()
                #endif
            case .Linux:
                TextField("Kernel", text: .constant(wizardState.linuxKernelURL?.path ?? ""))
                TextField("Initial Ramdisk", text: .constant(wizardState.linuxInitialRamdiskURL?.path ?? ""))
                TextField("Root Image", text: .constant(wizardState.linuxRootImageURL?.path ?? ""))
                TextField("Boot Arguments", text: $wizardState.linuxBootArguments)
                #if arch(arm64)
                if wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                    Toggle("Use Rosetta", isOn: $wizardState.linuxHasRosetta)
                }
                #endif
            case .Windows, .Other:
                if let windowsBootVhdx = wizardState.windowsBootVhdx {
                    TextField("Disk Image", text: .constant(windowsBootVhdx.path))
                }
            }
        }
    }
    
    var sharing: some View {
        Group {
            Toggle("Share Directory", isOn: .constant(wizardState.sharingDirectoryURL != nil))
            if let sharingPath = wizardState.sharingDirectoryURL?.path {
                TextField("Directory", text: .constant(sharingPath))
                Toggle("Read Only", isOn: $wizardState.sharingReadOnly)
            }
        }
    }
}

struct VMWizardSummaryView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardSummaryView(wizardState: wizardState)
    }
}
