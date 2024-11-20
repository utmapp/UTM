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

enum VMBootDevice: Int, Identifiable {
    var id: Int {
        return self.rawValue
    }

    case none
    case cd
    case floppy
    case kernel
}

struct AlertMessage: Identifiable {
    var message: String
    public var id: String {
        message
    }

    init(_ message: String) {
        self.message = message
    }
}

@MainActor class VMWizardState: ObservableObject {
    let bytesInMib = 1048576
    let bytesInGib = 1073741824
    
    @Published var slide: AnyTransition = .identity
    @Published var currentPage: VMWizardPage = .start
    @Published var pageHistory = [VMWizardPage]() {
        didSet {
            currentPage = pageHistory.last ?? .start
        }
    }
    @Published var nextPageBinding: Binding<VMWizardPage?> = .constant(nil)
    @Published var alertMessage: AlertMessage?
    @Published var isBusy: Bool = false
    @Published var systemBootUefi: Bool = true
    @Published var systemBootTpm: Bool = true
    @Published var isGuestToolsInstallRequested: Bool = false
    @Published var useVirtualization: Bool = false {
        didSet {
            if !useVirtualization {
                useAppleVirtualization = false
            }
        }
    }
    @Published var useAppleVirtualization: Bool = false {
        didSet {
            if #unavailable(macOS 13), useAppleVirtualization {
                bootDevice = .kernel
            }
        }
    }
    @Published var operatingSystem: VMWizardOS = .Other
    #if os(macOS) && arch(arm64)
    @Published var macPlatform: UTMAppleConfigurationMacPlatform?
    @Published var macRecoveryIpswURL: URL?
    @Published var macPlatformVersion: Int?
    var macIsLeastVentura: Bool {
        if let macPlatformVersion = macPlatformVersion {
            return macPlatformVersion >= 22
        } else {
            return false
        }
    }
    var macIsLeastSonoma: Bool {
        if let macPlatformVersion = macPlatformVersion {
            return macPlatformVersion >= 23
        } else {
            return false
        }
    }
    #endif
    @Published var legacyHardware: Bool = false
    @Published var bootDevice: VMBootDevice = .cd
    @Published var bootImageURL: URL?
    @Published var linuxKernelURL: URL?
    @Published var linuxInitialRamdiskURL: URL?
    @Published var linuxRootImageURL: URL?
    @Published var linuxBootArguments: String = ""
    @Published var linuxHasRosetta: Bool = false
    @Published var windowsBootVhdx: URL?
    @Published var isWindows10OrHigher: Bool = true
    @Published var systemArchitecture: QEMUArchitecture = .x86_64
    @Published var systemTarget: any QEMUTarget = QEMUTarget_x86_64.default
    #if os(macOS)
    @Published var systemMemoryMib: Int = 4096
    @Published var storageSizeGib: Int = 64
    #else
    @Published var systemMemoryMib: Int = 512
    @Published var storageSizeGib: Int = 8
    #endif
    @Published var systemCpuCount: Int = 0
    @Published var isGLEnabled: Bool = false
    @Published var sharingDirectoryURL: URL?
    @Published var sharingReadOnly: Bool = false
    @Published var name: String?
    @Published var isOpenSettingsAfterCreation: Bool = false
    @Published var useNvmeAsDiskInterface = false
    
    /// SwiftUI BUG: on macOS 12, when VoiceOver is enabled and isBusy changes the disable state of a button being clicked, 
    var isNeverDisabledWorkaround: Bool {
        #if os(macOS)
        if #available(macOS 12, *) {
            if #unavailable(macOS 13) {
                return false
            }
        }
        return true
        #else
        return true
        #endif
    }
    
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
        guard #available(macOS 12, *), useAppleVirtualization && operatingSystem == .macOS else {
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
            #if WITH_QEMU_TCI
            nextPage = .otherBoot
            #else
            nextPage = .operatingSystem
            #endif
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
            guard bootDevice == .none || bootImageURL != nil else {
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
            if bootDevice == .kernel {
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
            guard systemMemoryMib > 0 else {
                alertMessage = AlertMessage(NSLocalizedString("Invalid RAM size specified.", comment: "VMWizardState"))
                return
            }
            nextPage = .drives
            #if arch(arm64)
            if operatingSystem == .Windows && windowsBootVhdx != nil {
                nextPage = .sharing
            }
            #endif
            if operatingSystem == .Linux && linuxRootImageURL != nil {
                nextPage = .sharing
                if useAppleVirtualization {
                    if #available(macOS 12, *) {
                    } else {
                        nextPage = .summary
                    }
                }
            }
        case .drives:
            guard storageSizeGib > 0 else {
                alertMessage = AlertMessage(NSLocalizedString("Invalid drive size specified.", comment: "VMWizardState"))
                return
            }
            nextPage = .sharing
            if useAppleVirtualization {
                if #available(macOS 12, *) {
                    if operatingSystem != .Linux {
                        nextPage = .summary // only support linux currently
                    }
                } else {
                    nextPage = .summary
                }
            }
        case .sharing:
            nextPage = .summary
        case .summary:
            break
        }
        slide = slideIn
        withAnimation {
            pageHistory.append(nextPage)
            nextPageBinding.wrappedValue = nextPage
            nextPageBinding = .constant(nil)
        }
    }
    
    func back() {
        slide = slideOut
        withAnimation {
            _ = pageHistory.popLast()
        }
    }
    
    #if os(macOS)
    private func generateAppleConfig() throws -> UTMAppleConfiguration {
        let config = UTMAppleConfiguration()
        config.information.name = name!
        config.system.memorySize = systemMemoryMib
        config.system.cpuCount = systemCpuCount
        if bootDevice != .none, let bootImageURL = bootImageURL {
            config.drives.append(UTMAppleConfigurationDrive(existingURL: bootImageURL, isExternal: true))
        }
        var isSkipDiskCreate = false
        switch operatingSystem {
        case .Other:
            break
        case .macOS:
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: "mac")
            #if os(macOS) && arch(arm64)
            if #available(macOS 12, *) {
                config.system.boot = try! UTMAppleConfigurationBoot(for: .macOS)
                config.system.boot.macRecoveryIpswURL = macRecoveryIpswURL
                config.system.macPlatform = macPlatform
            }
            #endif
        case .Linux:
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: "linux")
            #if os(macOS)
            if bootDevice == .kernel {
                var bootloader = try UTMAppleConfigurationBoot(for: .linux, linuxKernelURL: linuxKernelURL!)
                bootloader.linuxInitialRamdiskURL = linuxInitialRamdiskURL
                bootloader.linuxCommandLine = linuxBootArguments
                config.system.boot = bootloader
                if let linuxRootImageURL = linuxRootImageURL {
                    config.drives.append(UTMAppleConfigurationDrive(existingURL: linuxRootImageURL))
                    isSkipDiskCreate = true
                }
            } else {
                config.system.boot = try UTMAppleConfigurationBoot(for: .linux)
            }
            config.system.genericPlatform = UTMAppleConfigurationGenericPlatform()
            config.virtualization.hasRosetta = linuxHasRosetta
            #endif
        case .Windows:
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: "windows")
            if let windowsBootVhdx = windowsBootVhdx {
                config.drives.append(UTMAppleConfigurationDrive(existingURL: windowsBootVhdx, isExternal: false))
                isSkipDiskCreate = true
            }
        }
        if !isSkipDiskCreate {
            var newDisk = UTMAppleConfigurationDrive(newSize: storageSizeGib * bytesInGib / bytesInMib)
            if #available(macOS 14, *), useNvmeAsDiskInterface {
                newDisk.isNvme = true
            }
            config.drives.append(newDisk)
        }
        if #available(macOS 12, *), let sharingDirectoryURL = sharingDirectoryURL {
            config.sharedDirectories = [UTMAppleConfigurationSharedDirectory(directoryURL: sharingDirectoryURL, isReadOnly: sharingReadOnly)]
        }
        // some meaningful defaults
        if #available(macOS 12, *) {
            let isMac = operatingSystem == .macOS
            var hasDisplay = isMac
            if #available(macOS 13, *) {
                hasDisplay = hasDisplay || (operatingSystem == .Linux)
            }
            if hasDisplay {
                config.displays = [UTMAppleConfigurationDisplay(width: 1920, height: 1200)]
                config.virtualization.hasAudio = true
                config.virtualization.keyboard = .generic
                config.virtualization.pointer = .mouse
            }
            #if arch(arm64)
            if isMac && macIsLeastVentura {
                config.virtualization.pointer = .trackpad
            }
            if isMac && macIsLeastSonoma {
                config.virtualization.keyboard = .mac
            }
            #endif
        }
        config.virtualization.hasBalloon = true
        config.virtualization.hasEntropy = true
        config.networks = [UTMAppleConfigurationNetwork()]
        if operatingSystem == .Linux && bootDevice == .kernel {
            config.serials = [UTMAppleConfigurationSerial()]
        }
        if #available(macOS 13, *) {
            config.virtualization.hasClipboardSharing = true
        }
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
                        self.macPlatform = UTMAppleConfigurationMacPlatform(newHardware: hardwareModel)
                        self.macRecoveryIpswURL = restoreImage.url
                        self.macPlatformVersion = restoreImage.buildVersion.integerPrefix()
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
        config.information.name = name!
        config.system.architecture = systemArchitecture
        config.system.target = systemTarget
        config.reset(forArchitecture: systemArchitecture, target: systemTarget)
        config.system.memorySize = systemMemoryMib
        config.system.cpuCount = systemCpuCount
        config.qemu.hasHypervisor = useVirtualization
        config.sharing.isDirectoryShareReadOnly = sharingReadOnly
        if let sharingDirectoryURL = sharingDirectoryURL {
            config.sharing.directoryShareUrl = sharingDirectoryURL
        }
        if config.sharing.directoryShareMode != .none && operatingSystem == .Linux {
            // change default sharing to virtfs if linux
            config.sharing.directoryShareMode = .virtfs
        }
        if operatingSystem == .Windows {
            // only change UEFI settings for Windows
            config.qemu.hasUefiBoot = systemBootUefi
            config.qemu.hasTPMDevice = systemBootTpm
        }
        if operatingSystem == .Linux && config.displays.first != nil {
            // change default display to virtio-gpu if supported
            let newCard = isGLEnabled ? "virtio-gpu-gl-pci" : "virtio-gpu-pci"
            let allCards = systemArchitecture.displayDeviceType.allRawValues
            if allCards.contains(where: { $0 == newCard }) {
                config.displays[0].hardware = AnyQEMUConstant(rawValue: newCard)!
            }
        } else if isGLEnabled || operatingSystem == .Windows, let displayCard = config.displays.first?.hardware {
            let newCard = displayCard.rawValue + "-gl"
            let allCards = systemArchitecture.displayDeviceType.allRawValues
            if allCards.contains(where: { $0 == newCard }) {
                config.displays[0].hardware = AnyQEMUConstant(rawValue: newCard)!
            }
        }
        let mainDriveInterface: QEMUDriveInterface
        if systemArchitecture == .aarch64 && operatingSystem == .Windows {
            mainDriveInterface = .nvme
        } else {
            mainDriveInterface = UTMQemuConfigurationDrive.defaultInterface(forArchitecture: systemArchitecture, target: systemTarget, imageType: .disk)
        }
        if bootDevice != .none && bootImageURL != nil {
            var bootDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: true)
            if bootDevice == .floppy {
                bootDrive.interface = .floppy
            }
            bootDrive.imageURL = bootImageURL
            config.drives.append(bootDrive)
        }
        switch operatingSystem {
        case .Other:
            break
        case .macOS:
            throw NSLocalizedString("macOS is not supported with QEMU.", comment: "VMWizardState")
        case .Linux:
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: "linux")
            if bootDevice == .kernel {
                var kernel = UTMQemuConfigurationDrive()
                kernel.imageURL = linuxKernelURL
                kernel.imageType = .linuxKernel
                kernel.isRawImage = true
                config.drives.append(kernel)
                if let linuxInitialRamdiskURL = linuxInitialRamdiskURL {
                    var initrd = UTMQemuConfigurationDrive()
                    initrd.imageURL = linuxInitialRamdiskURL
                    initrd.imageType = .linuxInitrd
                    initrd.isRawImage = true
                    config.drives.append(initrd)
                }
                if let linuxRootImageURL = linuxRootImageURL {
                    var rootImage = UTMQemuConfigurationDrive()
                    rootImage.imageURL = linuxRootImageURL
                    rootImage.imageType = .disk
                    rootImage.interface = mainDriveInterface
                    config.drives.append(rootImage)
                }
                if linuxBootArguments.count > 0 {
                    config.qemu.additionalArguments.append(QEMUArgument("-append"))
                    config.qemu.additionalArguments.append(QEMUArgument(linuxBootArguments))
                }
            }
        case .Windows:
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: "windows")
            config.qemu.hasRTCLocalTime = true
            if let windowsBootVhdx = windowsBootVhdx {
                var rootImage = UTMQemuConfigurationDrive()
                rootImage.imageURL = windowsBootVhdx
                rootImage.imageType = .disk
                rootImage.interface = mainDriveInterface
                config.drives.append(rootImage)
                let diskDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: true)
                config.drives.append(diskDrive)
            }
        }
        if windowsBootVhdx == nil {
            var diskImage = UTMQemuConfigurationDrive()
            diskImage.sizeMib = storageSizeGib * bytesInGib / bytesInMib
            diskImage.imageType = .disk
            diskImage.interface = mainDriveInterface
            config.drives.append(diskImage)
            if operatingSystem == .Windows && isGuestToolsInstallRequested {
                let toolsDiskDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: true)
                config.drives.append(toolsDiskDrive)
            }
        }
        if legacyHardware {
            config.qemu.hasUefiBoot = false
            config.input.usbBusSupport = .usb2_0
        }
        return config
    }
    
    func generateConfig() throws -> any UTMConfiguration {
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
    
    /// Execute a task with spinning progress indicator (Swift concurrency version)
    /// - Parameter work: Function to execute
    func busyWorkAsync(_ work: @escaping @Sendable () async throws -> Void) {
        Task.detached(priority: .userInitiated) {
            await MainActor.run { self.isBusy = true }
            do {
                try await work()
            } catch {
                logger.error("\(error)")
                await MainActor.run { self.alertMessage = AlertMessage(error.localizedDescription) }
            }
            await MainActor.run { self.isBusy = false }
        }
    }
}

// MARK: - Warnings for common mistakes

extension VMWizardState {
    nonisolated func confusedUserCheck() {
        Task { @MainActor in
            do {
                try confusedUserCheckBootImage()
            } catch {
                self.alertMessage = AlertMessage(error.localizedDescription)
            }
        }
    }
    
    private func confusedUserCheckBootImage() throws {
        guard let path = bootImageURL?.path.lowercased() else {
            return
        }
        if systemArchitecture == .aarch64 {
            if path.contains("x64") {
                throw VMWizardError.confusedArchitectureWarning("x64", systemArchitecture, "a64")
            }
            if path.contains("amd64") {
                throw VMWizardError.confusedArchitectureWarning("amd64", systemArchitecture, "arm64")
            }
            if path.contains("x86_64") {
                throw VMWizardError.confusedArchitectureWarning("x86_64", systemArchitecture, "arm64")
            }
        }
        if systemArchitecture == .x86_64 {
            if path.contains("arm64") {
                throw VMWizardError.confusedArchitectureWarning("arm64", systemArchitecture, "amd64")
            }
        }
    }
}

enum VMWizardError: Error {
    case confusedArchitectureWarning(String, QEMUArchitecture, String)
}

extension VMWizardError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .confusedArchitectureWarning(let pattern, let architecture, let expected): return String.localizedStringWithFormat(NSLocalizedString("The selected boot image contains the word '%@' but the guest architecture is '%@'. Please ensure you have selected an image that is compatible with '%@'.", comment: "VMWizardState"), pattern, architecture.prettyValue, expected)
        }
    }
}
