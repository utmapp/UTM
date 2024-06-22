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
    case windowsUnattendConfig
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
    @Published var windowsUnattendedInstall = false
    @Published var unattendLanguage = "en-US"
    @Published var unattendUsername = "user"
    @Published var unattendPassword = ""
    
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
            if windowsUnattendedInstall {
                nextPage = .windowsUnattendConfig
            } else {
                nextPage = .hardware
            }
        case .windowsUnattendConfig:
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
                config.system.genericPlatform = UTMAppleConfigurationGenericPlatform()
                if let linuxRootImageURL = linuxRootImageURL {
                    config.drives.append(UTMAppleConfigurationDrive(existingURL: linuxRootImageURL))
                    isSkipDiskCreate = true
                }
            } else {
                config.system.boot = try UTMAppleConfigurationBoot(for: .linux)
            }
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
            if operatingSystem == .Windows {
                if isGuestToolsInstallRequested {
                    let toolsDiskDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: true)
                    config.drives.append(toolsDiskDrive)
                }
                if windowsUnattendedInstall {
                    var unattendDrive = UTMQemuConfigurationDrive(forArchitecture: systemArchitecture, target: systemTarget, isExternal: false)
                    unattendDrive.isRawImage = true
                    unattendDrive.imageURL = try createAutounattendIso()
                    unattendDrive.interface = .usb
                    unattendDrive.imageType = .cd
                    config.drives.append(unattendDrive)
                }
            }
        }
        if legacyHardware {
            config.qemu.hasUefiBoot = false
            config.input.usbBusSupport = .usb2_0
        }
        return config
    }
    
    func createUnattendXml() -> String {
        return """
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <!--
      For documentation on components:
      https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/
    -->
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <EnableLUA>false</EnableLUA>
        </component>
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <EnableLUA>false</EnableLUA>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
        </component>
    </settings>
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
        </component>
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
        </component>
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SkipRearm>1</SkipRearm>
        </component>
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
            <OEMInformation>
                <Manufacturer>UTM</Manufacturer>
                <Model>UTM Virtual Machine</Model>
                <SupportPhone></SupportPhone>
                <SupportProvider>UTM</SupportProvider>
                <SupportURL>https://mac.getutm.app/support/</SupportURL>
            </OEMInformation>
            <OEMName>UTM</OEMName>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
            <OEMInformation>
                <Manufacturer>UTM</Manufacturer>
                <Model>UTM Virtual Machine</Model>
                <SupportPhone></SupportPhone>
                <SupportProvider>UTM</SupportProvider>
                <SupportURL>https://mac.getutm.app/support/</SupportURL>
            </OEMInformation>
            <OEMName>UTM</OEMName>
        </component>
        <component name="Microsoft-Windows-SQMApi" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <CEIPEnabled>0</CEIPEnabled>
        </component>
        <component name="Microsoft-Windows-SQMApi" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <CEIPEnabled>0</CEIPEnabled>
        </component>
    </settings>
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>\(unattendLanguage)</UILanguage>
            </SetupUILanguage>
            <InputLocale>\(unattendLanguage)</InputLocale>
            <SystemLocale>\(unattendLanguage)</SystemLocale>
            <UILanguage>\(unattendLanguage)</UILanguage>
            <UserLocale>\(unattendLanguage)</UserLocale>
        </component>
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>\(unattendLanguage)</UILanguage>
            </SetupUILanguage>
            <InputLocale>e\(unattendLanguage)</InputLocale>
            <SystemLocale>\(unattendLanguage)</SystemLocale>
            <UILanguage>\(unattendLanguage)</UILanguage>
            <UserLocale>\(unattendLanguage)</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Diagnostics>
                <OptIn>false</OptIn>
            </Diagnostics>
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassCPUCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassRAMCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassTPMCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
            <UserData>
                <!-- https://docs.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys -->
                <ProductKey>
                    <Key>W269N-WFGWX-YVC9B-4J6C9-T83GX</Key>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>100</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>FAT32</Format>
                            <Label>EFI</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Order>2</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Diagnostics>
                <OptIn>false</OptIn>
            </Diagnostics>
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassCPUCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassRAMCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Path>reg add HKLM\\System\\Setup\\LabConfig /v BypassTPMCheck /t REG_DWORD /d 0x00000001 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
            <UserData>
                <!-- https://docs.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys -->
                <ProductKey>
                    <Key>W269N-WFGWX-YVC9B-4J6C9-T83GX</Key>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>100</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>FAT32</Format>
                            <Label>EFI</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Order>2</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
        <component name="Microsoft-Windows-PnpCustomizationsWinPE" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" processorArchitecture="amd64">
            <!--
              This makes the VirtIO drivers available to Windows, assuming that
              the VirtIO driver disk is available as drive E:
              https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
            -->
            <DriverPaths>
                <PathAndCredentials wcm:action="add" wcm:keyValue="1">
                    <Path>E:\\Drivers\\qemufwcfg\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="2">
                    <Path>E:\\Drivers\\vioscsi\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="3">
                    <Path>E:\\Drivers\\viostor\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="4">
                    <Path>E:\\Drivers\\vioserial\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="5">
                    <Path>E:\\Drivers\\qxldod\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="6">
                    <Path>E:\\Drivers\\viogpu\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="7">
                    <Path>E:\\Drivers\\viorng\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="8">
                    <Path>E:\\Drivers\\NetKVM\\w10\\amd64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="9">
                    <Path>E:\\Drivers\\Balloon\\w10\\amd64</Path>
                </PathAndCredentials>
            </DriverPaths>
        </component>
        <component name="Microsoft-Windows-PnpCustomizationsWinPE" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" processorArchitecture="arm64">
            <DriverPaths>
                <PathAndCredentials wcm:action="add" wcm:keyValue="1">
                    <Path>E:\\Drivers\\vioscsi\\w10\\ARM64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="2">
                    <Path>E:\\Drivers\\viostor\\w10\\ARM64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="3">
                    <Path>E:\\Drivers\\vioserial\\w10\\ARM64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="4">
                    <Path>E:\\Drivers\\viogpu\\w10\\ARM64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="5">
                    <Path>E:\\Drivers\\NetKVM\\w10\\ARM64</Path>
                </PathAndCredentials>
                <PathAndCredentials wcm:action="add" wcm:keyValue="6">
                    <Path>E:\\Drivers\\Balloon\\w10\\ARM64</Path>
                </PathAndCredentials>
            </DriverPaths>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>\(unattendLanguage)</InputLocale>
            <SystemLocale>\(unattendLanguage)</SystemLocale>
            <UILanguage>\(unattendLanguage)</UILanguage>
            <UserLocale>\(unattendLanguage)</UserLocale>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>\(unattendLanguage)</InputLocale>
            <SystemLocale>\(unattendLanguage)</SystemLocale>
            <UILanguage>\(unattendLanguage)</UILanguage>
            <UserLocale>\(unattendLanguage)</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <DisplayName>\(unattendUsername)</DisplayName>
                        <Name>\(unattendUsername)</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value>\(unattendPassword)</Value>
                            <PlainText>true</PlainText>
                         </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Enabled>true</Enabled>
                <Username>\(unattendUsername)</Username>
                <Password>
                    <PlainText>true</PlainText>
                    <Value>\(unattendPassword)</Value>
                </Password>
                <LogonCount>1</LogonCount>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <VMModeOptimizations>
                    <SkipWinREInitialization>true</SkipWinREInitialization>
                </VMModeOptimizations>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>Cmd /c POWERCFG -H OFF</CommandLine>
                    <Description>Disable Hibernation</Description>
                    <Order>1</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>reg add "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon" /v AutoLogonCount /t REG_DWORD /d 0 /f</CommandLine>
                    <Description>Disable Autologon</Description>
                    <Order>2</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell "$name = 'utm-guest-tools-0.229.exe'; foreach ($drive in Get-PSDrive -PSProvider FileSystem) { $path = Join-Path $drive.Root $name; if (Test-Path $path) { &amp; $path; break } }"</CommandLine>
                    <Description>Install SPICE tools</Description>
                    <Order>3</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <DisplayName>alice</DisplayName>
                        <Name>\(unattendUsername)</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value>\(unattendPassword)</Value>
                            <PlainText>true</PlainText>
                         </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Enabled>true</Enabled>
                <Username>\(unattendUsername)</Username>
                <Password>
                    <PlainText>true</PlainText>
                    <Value>\(unattendPassword)</Value>
                </Password>
                <LogonCount>1</LogonCount>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <VMModeOptimizations>
                    <SkipWinREInitialization>true</SkipWinREInitialization>
                </VMModeOptimizations>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>Cmd /c POWERCFG -H OFF</CommandLine>
                    <Description>Disable Hibernation</Description>
                    <Order>1</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>reg add "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon" /v AutoLogonCount /t REG_DWORD /d 0 /f</CommandLine>
                    <Description>Disable Autologon</Description>
                    <Order>2</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell "$name = 'utm-guest-tools-0.229.exe'; foreach ($drive in Get-PSDrive -PSProvider FileSystem) { $path = Join-Path $drive.Root $name; if (Test-Path $path) { &amp; $path; break } }"</CommandLine>
                    <Description>Install SPICE tools</Description>
                    <Order>3</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
"""
    }

    func createAutounattendIso() throws -> URL {
        let fileManager = FileManager.default
        let url = fileManager.temporaryDirectory.appendingPathComponent("autounattend.iso")
        let xml = createUnattendXml().data(using: .utf8)!
        // Data layout
        // Sectors 0-15 - empty
        // Sector 16 - Primary Volume Descriptor
        // Sector 17 - Descriptor Set Terminator
        // Sector 18 - LE Path Table
        // Sector 19 - BE Path Table
        // Sector 20 - Root Directory
        // Sector 21 - File Data
        let sector = 2048
        var iso = Data(count: sector * 21)
        let xpad = 100
        iso.withCursor { data in
            var data = data
            let descriptorId = "CD001"
            data.advance(by: 16 * sector)
            data.write(u8: 1) // Primary Volume Descriptor
            data.write(ascii: descriptorId) // id
            data.write(u8: 1) // version
            data.write(u8: 0) // unused
            data.write(ascii: "", padTo: 32) // System Identifier
            data.write(ascii: "AUTOUNATTEND", padTo: 32) // Volume Identifier
            data.advance(by: 8)
            var xmlSect = xml.count / sector
            if xml.count % sector != 0 {
                xmlSect += 1
            }
            data.write(i32bi: Int32(20 + xmlSect + xpad)) // Volume Space Size
            data.advance(by: 32)
            data.write(i16bi: 1) // Volume Set Size
            data.write(i16bi: 1) // Volume Sequence Number
            data.write(i16bi: Int16(sector)) // Logical Block Size
            data.write(i32bi: 10) // Path table size
            data.write(i32: 18) // Type-L Path Table
            data.write(i32: 0) // Type-L Optional Path Table
            data.write(i32: Int32(19).bigEndian) // Type-M Path Table
            data.write(i32: 0) // Type-M Optional Path Table
            // Root Directory Record
            data.writeDirRecord(name: Data(repeating: 0, count: 1), location: 20, size: Int32(sector), directory: true)

            data.write(ascii: "", padTo: 128) // Volume Set Identifier
            data.write(ascii: "", padTo: 128) // Publisher Identifier
            data.write(ascii: "", padTo: 128) // Data Preparer Identifier
            data.write(ascii: "", padTo: 128) // Application Identifier
            data.write(ascii: "", padTo: 37) // Copyright File Identifier
            data.write(ascii: "", padTo: 37) // Abstract File Identifier
            data.write(ascii: "", padTo: 37) // Bibliographic File Identifier
            data.write(decDate: NSDate.now as Date) // Creation Date
            data.write(decDate: NSDate.now as Date) // Modification Date
            data.write(decDate: NSDate.now as Date + 315360000) // Expiration Date
            data.write(decDate: NSDate.now as Date) // Effective Date
            data.write(u8: 1) // File Structure Version
            data.write(u8: 0) // Padding
            data.advance(by: 512) // Application Use
            data.advance(by: 653) // Reserved

            data.write(u8: 255) // Descriptor Set Terminator
            data.write(ascii: descriptorId) // id
            data.write(u8: 1) // Version
            data.advance(by: sector - 7) // Reserved

            // L - Path Table
            data.write(u8: 1) // Directory Identifier Length
            data.write(u8: 0) // XA Length
            data.write(i32: 20) // Location
            data.write(i16: 1) // Parent directory number
            data.write(u8: 0) // Filename
            data.write(u8: 0) // Padding
            data.advance(by: sector - 10)

            // M - Path Table
            data.write(u8: 1) // Directory Identifier Length
            data.write(u8: 0) // XA Length
            data.write(i32: Int32(20).bigEndian) // Location
            data.write(i16: Int16(1).bigEndian) // Parent directory number
            data.write(u8: 0) // Filename
            data.write(u8: 0) // Padding
            data.advance(by: sector - 10)

            // Root directory
            data.writeDirRecord(name: Data(repeating: 0, count: 1), location: 20, size: Int32(sector), directory: true)
            data.writeDirRecord(name: Data(repeating: 1, count: 1), location: 20, size: Int32(sector), directory: true)
            data.writeDirRecord(name: "AUTOUNATTEND.XML;1".data(using: .ascii)!, location: 21, size: Int32(xml.count), directory: false)
        }
        iso.append(xml)
        if xml.count % sector != 0 {
            iso.append(Data(repeating: 0, count: 2048 - xml.count % sector))
        }
        iso.append(Data(repeating: 0, count: sector * xpad))
        fileManager.createFile(atPath: url.path, contents: iso)
        return url
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

struct DataCursor {
    var ptr: UnsafeMutableRawBufferPointer
    var cursor: Int
    mutating func advance(by: Int) {
        self.cursor += by
    }
    mutating func write(u8: UInt8) {
        ptr[cursor] = u8
        self.cursor += 1
    }
    mutating func write(i32: Int32) {
        ptr.storeBytes(of: i32, toByteOffset: self.cursor, as: Int32.self)
        self.cursor += 4
    }
    mutating func write(i32bi i: Int32) {
        write(i32: i)
        write(i32: i.bigEndian)
    }
    mutating func write(i16: Int16) {
        ptr.storeBytes(of: i16, toByteOffset: self.cursor, as: Int16.self)
        self.cursor += 2
    }
    mutating func write(i16bi i: Int16) {
        write(i16: i)
        write(i16: i.bigEndian)
    }
    mutating func write(ascii: String) {
        write(ascii: ascii, padTo: ascii.utf8.count)
    }
    mutating func write(ascii: String, padTo: Int) {
        ascii.withCString { bytes in
            for i in 0..<ascii.utf8.count {
                write(u8: UInt8(bytes[i]))
            }
        }
        let padding = max(0, padTo - ascii.utf8.count)
        for _ in 0..<padding {
            write(u8: 0x20)
        }
    }
    mutating func write(dirDate date: Date) {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.current
        let components = cal.dateComponents(in: tz, from: date)
        write(u8: UInt8(components.year! - 1900))
        write(u8: UInt8(components.month!))
        write(u8: UInt8(components.day!))
        write(u8: UInt8(components.hour!))
        write(u8: UInt8(components.minute!))
        write(u8: UInt8(components.second!))
        write(u8: UInt8(0))
    }
    mutating func write(digit: UInt8) {
        write(u8: digit + 48)
    }
    mutating func write(decDate date: Date) {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.current
        let components = cal.dateComponents(in: tz, from: date)
        let year = components.year!
        write(digit: UInt8(year / 1000))
        write(digit: UInt8(year % 1000 / 100))
        write(digit: UInt8(year % 100 / 10))
        write(digit: UInt8(year % 10))
        let month = UInt8(components.month!)
        write(digit: month / 10)
        write(digit: month % 10)
        let day = UInt8(components.day!)
        write(digit: day / 10)
        write(digit: day % 10)
        let hour = UInt8(components.hour!)
        write(digit: hour / 10)
        write(digit: hour % 10)
        let minute = UInt8(components.minute!)
        write(digit: minute / 10)
        write(digit: minute % 10)
        let second = UInt8(components.second!)
        write(digit: second / 10)
        write(digit: second % 10)
        let ms = UInt8(0)
        write(digit: ms / 10)
        write(digit: ms % 10)
        write(u8: UInt8(0))
    }
    mutating func write(data: Data) {
        for i in 0..<data.count {
            write(u8: data[i])
        }
    }
    mutating func writeDirRecord(name: Data, location: Int32, size: Int32, directory: Bool) {
        write(u8: UInt8(33 + name.count + 1 - name.count % 2)) // Length
        write(u8: 0) // Extended Attribute Length
        write(i32bi: location) // Location of extent
        write(i32bi: size) // Data Size
        write(dirDate: NSDate.now as Date) // Recording Date
        var flags = 0
        if directory {
            flags = 2
        }
        write(u8: UInt8(flags)) // Flags
        write(u8: 0) // File unit size
        write(u8: 0) // Interleave gap size
        write(i16bi: 1) // Volume Sequence Number
        write(u8: UInt8(name.count)) // File name length
        write(data: name) // File name
        if (name.count % 2 == 0) {
            write(u8: 0) // Padding
        }
    }
}

extension Data {
    mutating func withCursor<ResultType>(_ body: (DataCursor) throws -> ResultType) rethrows -> ResultType {
        try self.withUnsafeMutableBytes { ptr in
            let dc = DataCursor(ptr: ptr, cursor: 0)
            return try body(dc)
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
