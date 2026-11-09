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
    case classicMacOSBoot
    case otherBoot
    case hardware
    case drives
    case sharing
    case summary
}

enum VMWizardOS: Identifiable, CaseIterable {
    var id: Self { self }

    case Other
    case macOS
    case Linux
    case Windows
    case ClassicMacOS

    var name: LocalizedStringKey {
        switch self {
        case .Other: return "Other"
        case .macOS: return "macOS"
        case .Linux: return "Linux"
        case .Windows: return "Windows"
        case .ClassicMacOS: return "Mac OS"
        }
    }

    var defaultIconName: String? {
        switch self {
        case .Other: return nil
        case .macOS: return "mac"
        case .Linux: return "linux"
        case .Windows: return "windows"
        case .ClassicMacOS: return "macos"
        }
    }
}

enum VMBootDevice: Int, Identifiable {
    var id: Int {
        return self.rawValue
    }

    case none
    case cd
    case floppy
    case kernel
    case drive
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
    @Published var isWindows10OrHigher: Bool = true
    @Published var quadra800RomUrl: URL?
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
    @Published var isDisplayEnabled: Bool = true
    @Published var isGLEnabled: Bool = false
    @Published var sharingDirectoryURL: URL?
    @Published var sharingReadOnly: Bool = false
    @Published var name: String?
    @Published var isOpenSettingsAfterCreation: Bool = false
    @Published var useNvmeAsDiskInterface = false
    @Published var machineProperties: String?
    #if os(macOS)
    /// Folder or drive to create the VM in, such as an external drive. The default storage if nil.
    @Published var saveLocationURL: URL? {
        didSet {
            saveFolderPath = saveLocationURL.map { UTMData.virtualMachinesFolder(in: $0).path }
        }
    }
    /// Folder the VM goes in for `saveLocationURL`, worked out once because it looks at the drive.
    @Published private(set) var saveFolderPath: String?
    /// `saveLocationURL`, unless the VM is created later by the IPSW download, which uses the default storage.
    var effectiveSaveLocationURL: URL? {
        isPendingIPSWDownload ? nil : saveLocationURL
    }
    #endif

    /// SwiftUI BUG: on macOS 12, when VoiceOver is enabled and isBusy changes the disable state of a button being clicked, 
    var isNeverDisabledWorkaround: Bool {
        #if os(macOS)
        if #unavailable(macOS 13) {
            return false
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
        guard useAppleVirtualization && operatingSystem == .macOS else {
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
            nextPage = .hardware
        case .hardware:
            guard systemMemoryMib > 0 else {
                alertMessage = AlertMessage(NSLocalizedString("Invalid RAM size specified.", comment: "VMWizardState"))
                return
            }
            switch operatingSystem {
            case .Other:
                nextPage = .otherBoot
            case .macOS:
                nextPage = .macOSBoot
            case .Linux:
                nextPage = .linuxBoot
            case .Windows:
                nextPage = .windowsBoot
            case .ClassicMacOS:
                nextPage = .classicMacOSBoot
            }
        case .otherBoot, .macOSBoot, .linuxBoot, .windowsBoot, .classicMacOSBoot:
            guard [.kernel, .none].contains(bootDevice) || bootImageURL != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                return
            }
            if currentPage == .macOSBoot {
                #if os(macOS) && arch(arm64)
                if macPlatform == nil || macRecoveryIpswURL == nil {
                    fetchLatestPlatform()
                }
                #endif
            }
            if currentPage == .linuxBoot {
                guard bootDevice != .kernel || linuxKernelURL != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a kernel file.", comment: "VMWizardState"))
                    return
                }
            }
            if currentPage == .classicMacOSBoot {
                guard systemTarget.rawValue != QEMUTarget_m68k.q800.rawValue || quadra800RomUrl != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a ROM file.", comment: "VMWizardState"))
                    return
                }
            }
            if bootDevice == .drive {
                nextPage = .sharing
            } else {
                nextPage = .drives
            }
            if operatingSystem == .Linux && linuxRootImageURL != nil {
                nextPage = .sharing
            }
        case .drives:
            guard storageSizeGib > 0 else {
                alertMessage = AlertMessage(NSLocalizedString("Invalid drive size specified.", comment: "VMWizardState"))
                return
            }
            nextPage = .sharing
            if useAppleVirtualization {
                if operatingSystem != .Linux {
                    nextPage = .summary // only support linux currently
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
        if let iconName = operatingSystem.defaultIconName {
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: iconName)
        }
        switch operatingSystem {
        case .Other, .ClassicMacOS, .Windows:
            break
        case .macOS:
            #if os(macOS) && arch(arm64)
            config.system.boot = try! UTMAppleConfigurationBoot(for: .macOS)
            config.system.boot.macRecoveryIpswURL = macRecoveryIpswURL
            config.system.macPlatform = macPlatform
            #endif
        case .Linux:
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
        }
        if !isSkipDiskCreate {
            var newDisk = UTMAppleConfigurationDrive(newSize: storageSizeGib * bytesInGib / bytesInMib)
            if #available(macOS 14, *), useNvmeAsDiskInterface {
                newDisk.isNvme = true
            }
            if UTMAppleDiskImage.isASIFSupported {
                newDisk.isASIF = true
            }
            config.drives.append(newDisk)
        }
        if let sharingDirectoryURL = sharingDirectoryURL {
            config.sharedDirectories = [UTMAppleConfigurationSharedDirectory(directoryURL: sharingDirectoryURL, isReadOnly: sharingReadOnly)]
        }
        // some meaningful defaults
        let isMac = operatingSystem == .macOS
        var hasDisplay = isMac
        if #available(macOS 13, *) {
            hasDisplay = hasDisplay || (operatingSystem == .Linux)
        }
        if hasDisplay {
            config.displays = [UTMAppleConfigurationDisplay(width: 1920, height: 1200)]
            config.virtualization.audio = .inputOutput
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
        let isClassicMacM68K = systemArchitecture == .m68k && systemTarget.rawValue == QEMUTarget_m68k.q800.rawValue
        let isClassicMacPPC = [.ppc, .ppc64].contains(systemArchitecture) && systemTarget.rawValue == QEMUTarget_ppc.mac99.rawValue
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
        if operatingSystem == .Windows || operatingSystem == .Other {
            // only change UEFI settings for Windows or Other
            config.qemu.hasUefiBoot = systemBootUefi
            config.qemu.hasTPMDevice = operatingSystem == .Windows && systemBootTpm
            config.qemu.hasPreloadedSecureBootKeys = config.qemu.hasTPMDevice
        } else if legacyHardware {
            config.qemu.hasUefiBoot = false
            config.qemu.hasTPMDevice = false
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
        // Low-resolution guests upscale better with nearest neighbour: linear washes out
        // their already-chunky text (#3371). Legacy hardware is checked on its own rather
        // than folded into the Windows case so that picking a legacy machine opts in under
        // any OS, and because the summary page can enable it after the Windows page has
        // latched isWindows10OrHigher. Modern guests keep the linear default, where the
        // upscale is a non-integer ratio and nearest looks blocky instead of sharp.
        if operatingSystem == .ClassicMacOS || legacyHardware || (operatingSystem == .Windows && !isWindows10OrHigher) {
            for i in config.displays.indices {
                config.displays[i].upscalingFilter = .nearest
            }
        }
        if operatingSystem == .Linux && !isDisplayEnabled {
            config.displays = []
            let newSerial = UTMQemuConfigurationSerial(forArchitecture: systemArchitecture, target: systemTarget)!
            config.serials = [newSerial]
        }
        let mainDriveInterface: QEMUDriveInterface
        if systemArchitecture == .aarch64 && operatingSystem == .Windows {
            mainDriveInterface = .nvme
        } else {
            mainDriveInterface = UTMQemuConfigurationDrive.defaultInterface(forArchitecture: systemArchitecture, target: systemTarget, imageType: .disk)
        }
        if bootDevice != .none && bootImageURL != nil {
            var bootDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: bootDevice != .drive)
            if bootDevice == .floppy {
                bootDrive.interface = .floppy
            } else if bootDevice == .drive {
                bootDrive.interface = mainDriveInterface
            }
            if isClassicMacM68K {
                //bootDrive.interfaceLocation = [3, 0]
            } else if isClassicMacPPC {
                //bootDrive.interfaceLocation = [0, 1]
            }
            bootDrive.imageURL = bootImageURL
            config.drives.append(bootDrive)
        }
        if let iconName = operatingSystem.defaultIconName {
            config.information.iconURL = UTMConfigurationInfo.builtinIcon(named: iconName)
        }
        switch operatingSystem {
        case .Other:
            break
        case .macOS:
            throw NSLocalizedString("macOS is not supported with QEMU.", comment: "VMWizardState")
        case .Linux:
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
            config.qemu.hasRTCLocalTime = true
        case .ClassicMacOS:
            if systemArchitecture == .ppc || systemArchitecture == .ppc64 {
                config.qemu.machinePropertyOverride = machineProperties
            }
            if systemArchitecture == .m68k {
                var pramDrive = UTMQemuConfigurationDrive()
                pramDrive.sizeMib = 1
                pramDrive.imageType = .disk
                pramDrive.interface = .mtd
                config.drives.append(pramDrive)
                if let quadra800RomUrl = quadra800RomUrl {
                    var bios = UTMQemuConfigurationDrive()
                    bios.imageURL = quadra800RomUrl
                    bios.imageType = .bios
                    bios.isRawImage = true
                    config.drives.append(bios)
                }
            }
        }
        if bootDevice != .drive {
            var diskImage = UTMQemuConfigurationDrive()
            diskImage.sizeMib = storageSizeGib * bytesInGib / bytesInMib
            diskImage.imageType = .disk
            diskImage.interface = mainDriveInterface
            if isClassicMacM68K {
                //diskImage.interfaceLocation = [0, 0]
            } else if isClassicMacPPC {
                //diskImage.interfaceLocation = [0, 0]
            }
            if isClassicMacPPC || isClassicMacM68K {
                config.drives.insert(diskImage, at: 0)
            } else {
                config.drives.append(diskImage)
            }
            if (operatingSystem == .Windows && isGuestToolsInstallRequested) ||
               (legacyHardware && bootDevice == .floppy) {
                // extra CD drive for guest tools OR first CD drive for floppy boot systems
                let toolsDiskDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: true)
                config.drives.append(toolsDiskDrive)
            }
        }
        if legacyHardware && operatingSystem == .Windows {
            config.qemu.hasPS2Controller = true
        }
        if legacyHardware && systemArchitecture.hasUsbSupport && systemTarget.hasUsbSupport {
            config.input.usbBusSupport = .usb2_0
        }
        return config
    }
    
    func generateConfig() throws -> any UTMConfiguration {
        guard name != nil else {
            throw VMWizardError.nameEmpty
        }
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
    
    #if os(macOS)
    /// Check that the VM can be created in the chosen folder
    ///
    /// The folder is on a drive that UTM does not control, so a read-only drive (such as NTFS) or
    /// a FAT32 drive that cannot hold a large disk image is reported before anything is created.
    func validateSaveLocation() throws {
        guard let url = effectiveSaveLocationURL else {
            return
        }
        let isScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var info = statfs()
        guard statfs(url.path, &info) == 0 else {
            throw VMWizardError.saveLocationUnavailable(url.lastPathComponent)
        }
        guard info.f_flags & UInt32(MNT_RDONLY) == 0, FileManager.default.isWritableFile(atPath: url.path) else {
            throw VMWizardError.saveLocationReadOnly(url.lastPathComponent)
        }
        let fileSystem = withUnsafeBytes(of: info.f_fstypename) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        let maxFat32FileSizeGib = 4
        if fileSystem == "msdos" && storageSizeGib >= maxFat32FileSizeGib {
            throw VMWizardError.saveLocationFileSystemTooSmall(url.lastPathComponent)
        }
        // the suggested name only avoids the VMs in the default storage, so one in this folder can have it
        if let name = name, !name.isEmpty {
            let folder = UTMData.virtualMachinesFolder(in: url)
            if FileManager.default.fileExists(atPath: ConcreteVirtualMachine.virtualMachinePath(for: name, in: folder).path) {
                throw VMWizardError.saveLocationNameTaken(name, folder.lastPathComponent)
            }
        }
    }
    #endif

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
    case nameEmpty
    case saveLocationUnavailable(String)
    case saveLocationReadOnly(String)
    case saveLocationFileSystemTooSmall(String)
    case saveLocationNameTaken(String, String)
}

extension VMWizardError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .confusedArchitectureWarning(let pattern, let architecture, let expected): return String.localizedStringWithFormat(NSLocalizedString("The selected boot image contains the word '%@' but the guest architecture is '%@'. Please ensure you have selected an image that is compatible with '%@'.", comment: "VMWizardState"), pattern, architecture.prettyValue, expected)
        case .nameEmpty: return NSLocalizedString("Name cannot be empty.", comment: "VMWizardState")
        case .saveLocationUnavailable(let name): return String.localizedStringWithFormat(NSLocalizedString("The folder “%@” cannot be accessed. Is the drive still connected?", comment: "VMWizardState"), name)
        case .saveLocationReadOnly(let name): return String.localizedStringWithFormat(NSLocalizedString("The folder “%@” is read-only, so the virtual machine cannot be saved there. Some drives, such as NTFS drives, can only be read on a Mac.", comment: "VMWizardState"), name)
        case .saveLocationNameTaken(let name, let folder): return String.localizedStringWithFormat(NSLocalizedString("The folder “%@” already has a virtual machine named “%@”. Please choose a different name.", comment: "VMWizardState"), folder, name)
        case .saveLocationFileSystemTooSmall(let name): return String.localizedStringWithFormat(NSLocalizedString("The drive holding “%@” is formatted as FAT32, which cannot store a file of 4 GiB or more. Choose a smaller storage size or a drive formatted as APFS, Mac OS Extended or exFAT.", comment: "VMWizardState"), name)
        }
    }
}

// MARK: - Hardware and Windows page rules

extension VMWizardState {
    enum SupportedMachine: CaseIterable, Identifiable {
        case quadra800
        //case powerMacG3Beige
        case powerMacG4
        //case powerMacG5
        case i440FX
        case q35
        case arm64Virt
        case riscv64Virt

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .quadra800: "Macintosh Quadra 800 (1993, M68K)"
            //case .powerMacG3Beige: "Power Macintosh G3 (1997, Beige)"
            case .powerMacG4: "Power Macintosh G4 (1999, PPC)"
            //case .powerMacG5: "Power Macintosh G5 (2003, PPC64)"
            case .i440FX: "Intel i440FX based PC (1996, i386)"
            case .q35: "Intel ICH9 based PC (2009, x86_64)"
            case .arm64Virt: "ARM64 virtual machine (2014, ARM64)"
            case .riscv64Virt: "RISC-V64 virtual machine (2018, RISC-V64)"
            }
        }

        var architecture: QEMUArchitecture {
            switch self {
            case .quadra800: return .m68k
            //case .powerMacG3Beige: return .ppc
            case .powerMacG4: return .ppc
            //case .powerMacG5: return .ppc64
            case .i440FX: return .i386
            case .q35: return .x86_64
            case .arm64Virt: return .aarch64
            case .riscv64Virt: return .riscv64
            }
        }

        var target: any QEMUTarget {
            switch self {
            case .quadra800: return QEMUTarget_m68k.q800
            //case .powerMacG3Beige: return QEMUTarget_ppc.g3beige
            case .powerMacG4: return QEMUTarget_ppc.mac99
            //case .powerMacG5: return QEMUTarget_ppc.mac99
            case .i440FX: return QEMUTarget_i386.pc
            case .q35: return QEMUTarget_x86_64.q35
            case .arm64Virt: return QEMUTarget_aarch64.virt
            case .riscv64Virt: return QEMUTarget_riscv64.virt
            }
        }

        var minRam: Int {
            switch self {
            case .quadra800: return 8
            //case .powerMacG3Beige: return 32
            case .powerMacG4: return 64
            //case .powerMacG5: return 64
            default: return 0
            }
        }

        var maxRam: Int {
            switch self {
            case .quadra800: return 1024
            //case .powerMacG3Beige: return 2047
            case .powerMacG4: return 2048
            //case .powerMacG5: return 2048
            default: return 0
            }
        }

        var defaultRam: Int {
            switch self {
            case .quadra800: return 128
            //case .powerMacG3Beige: return 512
            case .powerMacG4: return 512
            //case .powerMacG5: return 512
            case .i440FX: return 512
            #if os(macOS)
            default: return 4096
            #else
            default: return 512
            #endif
            }
        }

        var defaultStorageGiB: Int {
            switch self {
            case .quadra800, .powerMacG4: return 2
            case .i440FX: return 2
            #if os(macOS)
            default: return 64
            #else
            default: return 2
            #endif
            }
        }

        var maxSupportedCores: Int {
            switch self {
            case .quadra800, .powerMacG4: return 1
            default: return 0
            }
        }

        var isLegacyHardware: Bool {
            switch self {
            case .quadra800, .powerMacG4, .i440FX: return true
            default: return false
            }
        }

        func isSupported(running os: VMWizardOS) -> Bool {
            switch os {
            case .Other: return true
            case .macOS: return [.arm64Virt].contains(self)
            case .Linux: return true
            case .Windows: return [.i440FX, .q35, .arm64Virt].contains(self)
            case .ClassicMacOS: return [.quadra800, .powerMacG4].contains(self)
            }
        }

        static func `default`(for os: VMWizardOS) -> Self {
            switch os {
            case .Other: return .q35
            case .macOS: return .arm64Virt
            case .Linux: return .q35
            case .Windows: return .q35
            case .ClassicMacOS: return .powerMacG4
            }
        }
    }
    
    /// Takes the architecture, machine, memory, cores, storage and hardware level of a machine the user picked.
    func applyMachine(_ machine: SupportedMachine) {
        systemArchitecture = machine.architecture
        systemTarget = machine.target
        systemMemoryMib = machine.defaultRam
        systemCpuCount = machine.maxSupportedCores
        storageSizeGib = machine.defaultStorageGiB
        legacyHardware = machine.isLegacyHardware
    }
    
    /// Virtualization runs the host's architecture on its default machine with current hardware.
    func prepareVirtualizedHardware() {
        #if arch(arm64)
        systemArchitecture = .aarch64
        #elseif arch(x86_64)
        systemArchitecture = .x86_64
        #else
        #error("Unsupported architecture.")
        #endif
        systemTarget = systemArchitecture.targetType.default
        legacyHardware = false
    }
    
    /// A new architecture starts on its default machine.
    func setSystemArchitecture(_ architecture: QEMUArchitecture) {
        systemArchitecture = architecture
        systemTarget = architecture.targetType.default
    }
    
    /// Keeps the memory within what the machine supports, or the host's maximum when
    /// the machine has no limit of its own.
    func clampSystemMemory(for machine: SupportedMachine?, hostMaximumMib: Int) {
        let machineMaximum = machine?.maxRam ?? 0
        let validMaximum = machineMaximum > 0 ? machineMaximum : hostMaximumMib
        if systemMemoryMib > validMaximum {
            systemMemoryMib = validMaximum
        }
        let validMinimum = machine?.minRam ?? 0
        if systemMemoryMib < validMinimum {
            systemMemoryMib = validMinimum
        }
    }
    
    /// Keeps an explicit core count within the host's range; zero means the default.
    func clampSystemCpuCount(in range: ClosedRange<Int>) {
        guard systemCpuCount != 0 else {
            return
        }
        if systemCpuCount < range.lowerBound {
            systemCpuCount = range.lowerBound
        } else if systemCpuCount > range.upperBound {
            systemCpuCount = range.upperBound
        }
    }
    
    /// GPU acceleration needs a display.
    func setDisplayEnabled(_ isEnabled: Bool) {
        isDisplayEnabled = isEnabled
        if !isEnabled {
            isGLEnabled = false
        }
    }
    
    /// Windows 10 and later boot UEFI with a TPM and get the guest tools; older versions do not.
    func setWindows10OrHigher(_ isWindows10OrHigher: Bool) {
        self.isWindows10OrHigher = isWindows10OrHigher
        systemBootUefi = isWindows10OrHigher
        systemBootTpm = isWindows10OrHigher
        isGuestToolsInstallRequested = isWindows10OrHigher
    }
    
    /// A TPM needs UEFI boot.
    func setBootUefi(_ isUefi: Bool) {
        systemBootUefi = isUefi
        if !isUefi {
            systemBootTpm = false
        }
    }
    
    /// Windows installs from a CD image; legacy hardware (always, in UTM SE) cannot run Windows 10.
    func prepareWindowsPage() {
        bootDevice = .cd
        #if WITH_QEMU_TCI
        legacyHardware = true
        #endif
        if legacyHardware {
            setWindows10OrHigher(false)
        }
    }
}
