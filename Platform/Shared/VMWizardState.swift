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

import Foundation
import SwiftUI
#if canImport(Virtualization)
import Virtualization
#endif

enum VMWizardPage: Int, Identifiable {
    var id: Int {
        return self.rawValue
    }
    
    case start
    case operatingSystem
    case macOSBoot
    case linuxBoot
    case windowsBoot
    case otherBoot
    case hardware
    case drives
    case sharing
    case summary
}

enum VMWizardOS: String, Identifiable {
    var id: String {
        return self.rawValue
    }
    
    case Other
    case macOS
    case Linux
    case Windows
}

@available(iOS 14, macOS 11, *)
class VMWizardState: ObservableObject {
    let bytesInMib = 1048576
    let bytesInGib = 1073741824
    
    @Published var slide: AnyTransition = .identity
    @Published var currentPage: VMWizardPage = .start
    @Published var nextPageBinding: Binding<VMWizardPage?> = .constant(nil)
    @Published var alertMessage: AlertMessage?
    @Published var isBusy: Bool = false
    @Published var useVirtualization: Bool = false {
        didSet {
            if !useVirtualization {
                useAppleVirtualization = false
            }
        }
    }
    @Published var useAppleVirtualization: Bool = false {
        didSet {
            if useAppleVirtualization {
                useLinuxKernel = true
            }
        }
    }
    @Published var operatingSystem: VMWizardOS = .Other
    #if os(macOS) && arch(arm64)
    @available(macOS 12, *)
    @Published var macPlatform: MacPlatform?
    @Published var macRecoveryIpswURL: URL?
    #endif
    @Published var isSkipBootImage: Bool = false
    @Published var bootImageURL: URL?
    @Published var useLinuxKernel: Bool = false {
        didSet {
            isSkipBootImage = useLinuxKernel
        }
    }
    @Published var linuxKernelURL: URL?
    @Published var linuxInitialRamdiskURL: URL?
    @Published var linuxRootImageURL: URL?
    @Published var linuxBootArguments: String = ""
    @Published var windowsBootVhdx: URL?
    @Published var systemArchitecture: String?
    @Published var systemTarget: String?
    #if os(macOS)
    @Published var systemMemory: UInt64 = 4096 * 1048576
    @Published var storageSizeGib: Int = 64
    #else
    @Published var systemMemory: UInt64 = 512 * 1048576
    @Published var storageSizeGib: Int = 8
    #endif
    @Published var systemCpuCount: Int = 4
    @Published var isGLEnabled: Bool = false
    @Published var sharingDirectoryURL: URL?
    @Published var sharingReadOnly: Bool = false
    @Published var name: String?
    @Published var isOpenSettingsAfterCreation: Bool = false
    
    var hasNextButton: Bool {
        switch currentPage {
        case .start:
            return false
        case .operatingSystem:
            return false
        case .summary:
            return false
        default:
            return true
        }
    }
    
    #if os(macOS) && arch(arm64)
    var isPendingIPSWDownload: Bool {
        guard #available(macOS 12, *), operatingSystem == .macOS else {
            return false
        }
        guard let url = macRecoveryIpswURL else {
            return false
        }
        return !url.isFileURL
    }
    #else
    let isPendingIPSWDownload: Bool = false
    #endif
    
    var slideIn: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .opacity)
    }
    
    var slideOut: AnyTransition {
        .asymmetric(insertion: .move(edge: .leading), removal: .opacity)
    }
    
    func next() {
        var nextPage = currentPage
        switch currentPage {
        case .start:
            nextPage = .operatingSystem
        case .operatingSystem:
            switch operatingSystem {
            case .Other:
                nextPage = .otherBoot
            case .macOS:
                nextPage = .macOSBoot
            case .Linux:
                nextPage = .linuxBoot
            case .Windows:
                nextPage = .windowsBoot
            }
        case .otherBoot:
            guard isSkipBootImage || bootImageURL != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                return
            }
            nextPage = .hardware
        case .macOSBoot:
            #if os(macOS) && arch(arm64)
            if #available(macOS 12, *) {
                if macPlatform == nil || macRecoveryIpswURL == nil {
                    fetchLatestPlatform()
                }
                nextPage = .hardware
            }
            #endif
        case .linuxBoot:
            if useLinuxKernel {
                guard linuxKernelURL != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a kernel file.", comment: "VMWizardState"))
                    return
                }
            } else {
                guard bootImageURL != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                    return
                }
            }
            nextPage = .hardware
        case .windowsBoot:
            guard bootImageURL != nil || windowsBootVhdx != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                return
            }
            nextPage = .hardware
        case .hardware:
            if !useVirtualization {
                guard systemArchitecture != nil && systemTarget != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a system to emulate.", comment: "VMWizardState"))
                    return
                }
            } else {
                #if arch(arm64)
                systemArchitecture = "aarch64"
                #elseif arch(x86_64)
                systemArchitecture = "x86_64"
                #else
                #error("Unsupported architecture.")
                #endif
            }
            if systemTarget == nil {
                let index = UTMQemuConfiguration.defaultTargetIndex(forArchitecture: systemArchitecture)
                let targets = UTMQemuConfiguration.supportedTargets(forArchitecture: systemArchitecture)
                systemTarget = targets?[index]
            }
            nextPage = .drives
            #if arch(arm64)
            if operatingSystem == .Windows && windowsBootVhdx != nil {
                nextPage = .sharing
            }
            #endif
        case .drives:
            nextPage = .sharing
        case .sharing:
            nextPage = .summary
        case .summary:
            break
        }
        slide = slideIn
        withAnimation {
            currentPage = nextPage
            nextPageBinding.wrappedValue = nextPage
            nextPageBinding = .constant(nil)
        }
    }
    
    func back() {
        var previousPage = currentPage
        switch currentPage {
        case .start:
            break
        case .operatingSystem:
            previousPage = .start
        case .otherBoot:
            previousPage = .operatingSystem
        case .macOSBoot:
            previousPage = .operatingSystem
        case .linuxBoot:
            previousPage = .operatingSystem
        case .windowsBoot:
            previousPage = .operatingSystem
        case .hardware:
            switch operatingSystem {
            case .Other:
                previousPage = .otherBoot
            case .macOS:
                previousPage = .macOSBoot
            case .Linux:
                previousPage = .linuxBoot
            case .Windows:
                previousPage = .windowsBoot
            }
        case .drives:
            previousPage = .hardware
        case .sharing:
            previousPage = .drives
            #if arch(arm64)
            if operatingSystem == .Windows && windowsBootVhdx != nil {
                previousPage = .hardware // skip drives when using Windows ARM
            }
            #endif
        case .summary:
            previousPage = .sharing
        }
        slide = slideOut
        withAnimation {
            currentPage = previousPage
        }
    }
    
    #if os(macOS)
    private func generateAppleConfig() throws -> UTMAppleConfiguration {
        let config = UTMAppleConfiguration()
        config.name = name!
        config.memorySize = systemMemory
        config.cpuCount = systemCpuCount
        if !isSkipBootImage, let bootImageURL = bootImageURL {
            config.diskImages.append(DiskImage(importImage: bootImageURL, isReadOnly: false, isExternal: true))
        }
        switch operatingSystem {
        case .Other:
            break
        case .macOS:
            config.icon = "mac"
            #if os(macOS) && arch(arm64)
            if #available(macOS 12, *) {
                config.bootLoader = try! Bootloader(for: .macOS)
                config.macRecoveryIpswURL = macRecoveryIpswURL
                config.macPlatform = macPlatform
            }
            #endif
        case .Linux:
            config.icon = "linux"
            #if os(macOS)
            if useLinuxKernel {
                var bootloader = try Bootloader(for: .Linux, linuxKernelURL: linuxKernelURL!)
                bootloader.linuxInitialRamdiskURL = linuxInitialRamdiskURL
                bootloader.linuxCommandLine = linuxBootArguments
                config.bootLoader = bootloader
                if let linuxRootImageURL = linuxRootImageURL {
                    config.diskImages.append(DiskImage(importImage: linuxRootImageURL))
                }
            }
            #endif
        case .Windows:
            config.icon = "windows"
            if let windowsBootVhdx = windowsBootVhdx {
                config.diskImages.append(DiskImage(importImage: windowsBootVhdx, isReadOnly: false, isExternal: true))
            }
        }
        if windowsBootVhdx == nil {
            config.diskImages.append(DiskImage(newSize: storageSizeGib * bytesInGib / bytesInMib))
        }
        if #available(macOS 12, *), let sharingDirectoryURL = sharingDirectoryURL {
            config.sharedDirectories = [SharedDirectory(directoryURL: sharingDirectoryURL, isReadOnly: sharingReadOnly)]
        }
        // some meaningful defaults
        if #available(macOS 12, *) {
            config.displays = [Display(for: .init(width: 1920, height: 1200), isHidpi: true)]
            config.isAudioEnabled = true
            config.isKeyboardEnabled = true
            config.isPointingEnabled = true
        }
        config.isBalloonEnabled = true
        config.isEntropyEnabled = true
        config.networkDevices = [Network(newInterfaceForMode: .Shared)]
        config.isSerialEnabled = operatingSystem == .Linux
        config.isConsoleDisplay = operatingSystem == .Linux
        return config
    }
    
    #if arch(arm64)
    @available(macOS 12, *)
    private func fetchLatestPlatform() {
        VZMacOSRestoreImage.fetchLatestSupported { result in
            switch result {
            case .success(let restoreImage):
                DispatchQueue.main.async {
                    if let hardwareModel = restoreImage.mostFeaturefulSupportedConfiguration?.hardwareModel {
                        self.macPlatform = MacPlatform(newHardware: hardwareModel)
                        self.macRecoveryIpswURL = restoreImage.url
                    } else {
                        self.alertMessage = AlertMessage(NSLocalizedString("Failed to get latest macOS version from Apple.", comment: "VMWizardState"))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    #endif
    #endif
    
    private func generateQemuConfig() throws -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.name = name!
        config.systemArchitecture = systemArchitecture
        config.systemTarget = systemTarget
        config.loadDefaults(forTarget: systemTarget, architecture: systemArchitecture)
        config.systemMemory = NSNumber(value: systemMemory / UInt64(bytesInMib))
        config.systemCPUCount = NSNumber(value: systemCpuCount)
        config.useHypervisor = useVirtualization
        config.shareDirectoryReadOnly = sharingReadOnly
        if isGLEnabled, let displayCard = config.displayCard {
            let newCard = displayCard + "-gl"
            let allCards = UTMQemuConfiguration.supportedDisplayCards(forArchitecture: systemArchitecture)!
            if allCards.contains(newCard) {
                config.displayCard = newCard
            }
        }
        let generateRemovableDrive: () -> Void = { [self] in
            config.newRemovableDrive("cdrom0", type: .CD, interface: UTMQemuConfiguration.defaultDriveInterface(forTarget: systemTarget, architecture: systemArchitecture, type: .CD))
        }
        if !isSkipBootImage && bootImageURL != nil {
            generateRemovableDrive()
        }
        switch operatingSystem {
        case .Other:
            break
        case .macOS:
            throw NSLocalizedString("macOS is not supported with QEMU.", comment: "VMWizardState")
        case .Linux:
            config.icon = "linux"
            if useLinuxKernel {
                config.newDrive("kernel", path: linuxKernelURL!.lastPathComponent, type: .kernel, interface: "")
                if let linuxInitialRamdiskURL = linuxInitialRamdiskURL {
                    config.newDrive("initrd", path: linuxInitialRamdiskURL.lastPathComponent, type: .initrd, interface: "")
                }
                if let linuxRootImageURL = linuxRootImageURL {
                    config.newDrive("root", path: linuxRootImageURL.lastPathComponent, type: .disk, interface: UTMQemuConfiguration.defaultDriveInterface(forTarget: systemTarget, architecture: systemArchitecture, type: .disk))
                }
                if linuxBootArguments.count > 0 {
                    config.newArgument("-append")
                    config.newArgument(linuxBootArguments)
                }
            }
        case .Windows:
            config.icon = "windows"
            if let windowsBootVhdx = windowsBootVhdx {
                config.newDrive("drive0", path: windowsBootVhdx.lastPathComponent, type: .disk, interface: "nvme")
                generateRemovableDrive() // order matters here
            }
        }
        if windowsBootVhdx == nil {
            let interface: String
            if operatingSystem == .Windows {
                interface = "nvme"
            } else {
                interface = UTMQemuConfiguration.defaultDriveInterface(forTarget: systemTarget, architecture: systemArchitecture, type: .disk)
            }
            config.newDrive("drive0", path: "data.qcow2", type: .disk, interface: interface)
        }
        return config
    }
    
    func generateConfig() throws -> UTMConfigurable {
        if useVirtualization && useAppleVirtualization {
            #if os(macOS)
            return try generateAppleConfig()
            #else
            throw NSLocalizedString("Unavailable for this platform.", comment: "VMWizardState")
            #endif
        } else {
            return try generateQemuConfig()
        }
    }
    
    private func copyItem(from url: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: false, attributes: nil)
        }
        let dstUrl = destination.appendingPathComponent(url.lastPathComponent)
        try fileManager.copyItem(at: url, to: dstUrl)
    }
    
    func qemuPostCreate(with vm: UTMQemuVirtualMachine) throws {
        if let sharingDirectoryURL = sharingDirectoryURL {
            try vm.changeSharedDirectory(sharingDirectoryURL)
        }
        let drive = vm.drives.first { drive in
            drive.name == "cdrom0"
        }
        if let drive = drive, let bootImageURL = bootImageURL {
            try vm.changeMedium(for: drive, url: bootImageURL)
        }
        let dataUrl = vm.qemuConfig.imagesPath
        if operatingSystem == .Linux && useLinuxKernel {
            try copyItem(from: linuxKernelURL!, to: dataUrl)
            if let linuxInitialRamdiskURL = linuxInitialRamdiskURL {
                try copyItem(from: linuxInitialRamdiskURL, to: dataUrl)
            }
            if let linuxRootImageURL = linuxRootImageURL {
                try copyItem(from: linuxRootImageURL, to: dataUrl)
            }
        }
        if let windowsBootVhdx = windowsBootVhdx {
            try copyItem(from: windowsBootVhdx, to: dataUrl)
        } else {
            let dstPath = dataUrl.appendingPathComponent("data.qcow2")
            if !GenerateDefaultQcow2File(dstPath as CFURL, storageSizeGib * bytesInGib / bytesInMib) {
                throw NSLocalizedString("Disk creation failed.", comment: "VMWizardState")
            }
        }
    }
    
    func busyWork(_ work: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            self.isBusy = true
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            }
            do {
                try work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    
    #if swift(>=5.5)
    @available(iOS 15, macOS 12, *)
    func busyWorkAsync(_ work: @escaping () async throws -> Void) {
        Task(priority: .userInitiated) {
            DispatchQueue.main.async {
                self.isBusy = true
            }
            defer {
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            }
            do {
                try await work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    #endif
}
