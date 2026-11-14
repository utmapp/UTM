//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

import XCTest
@testable import UTM

/// The configuration the new-VM wizard generates from its answers.
@MainActor final class VMWizardStateTests: XCTestCase {
    private let image = URL(fileURLWithPath: "/tmp/install.iso")

    private func wizard(_ os: VMWizardOS, architecture: QEMUArchitecture, target: any QEMUTarget) -> VMWizardState {
        let state = VMWizardState()
        state.name = "Wizard VM"
        state.operatingSystem = os
        state.systemArchitecture = architecture
        state.systemTarget = target
        state.bootDevice = .cd
        state.bootImageURL = image
        return state
    }

    private func qemuConfig(_ state: VMWizardState) throws -> UTMQemuConfiguration {
        try XCTUnwrap(try state.generateConfig() as? UTMQemuConfiguration)
    }

    private func systemDisk(_ config: UTMQemuConfiguration) throws -> UTMQemuConfigurationDrive {
        try XCTUnwrap(config.drives.first { $0.imageType == .disk && $0.imageURL == nil && $0.sizeMib > 1 })
    }

    func testNameIsRequired() {
        let state = wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        state.name = nil
        XCTAssertThrowsError(try state.generateConfig()) { error in
            guard case VMWizardError.nameEmpty = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testMacOSIsRejectedForQemu() {
        let state = wizard(.macOS, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        XCTAssertThrowsError(try state.generateConfig())
    }

    /// Linux keeps the virtio disk; only Windows on aarch64 is moved to NVMe.
    func testLinuxAarch64GuestUsesVirtioDisk() throws {
        let config = try qemuConfig(wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt))
        XCTAssertEqual(try systemDisk(config).interface, .virtio)
        XCTAssertFalse(config.drives.contains { $0.interface == .nvme })
    }

    func testWindowsAarch64GuestUsesNvmeDisk() throws {
        let config = try qemuConfig(wizard(.Windows, architecture: .aarch64, target: QEMUTarget_aarch64.virt))
        XCTAssertEqual(try systemDisk(config).interface, .nvme)
    }

    func testBootImageBecomesRemovableDrive() throws {
        let config = try qemuConfig(wizard(.Other, architecture: .x86_64, target: QEMUTarget_x86_64.q35))
        let boot = try XCTUnwrap(config.drives.first { $0.imageURL == image })
        XCTAssertTrue(boot.isExternal)
        XCTAssertEqual(boot.imageType, .cd)
    }

    /// A shared directory on a Linux guest uses VirtFS rather than SPICE WebDAV (#5531).
    func testLinuxShareDirectoryUsesVirtfs() throws {
        let state = wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        state.sharingDirectoryURL = URL(fileURLWithPath: "/tmp/shared")
        state.sharingReadOnly = true
        let config = try qemuConfig(state)
        XCTAssertEqual(config.sharing.directoryShareMode, .virtfs)
        XCTAssertEqual(config.sharing.directoryShareUrl?.path, "/tmp/shared")
        XCTAssertTrue(config.sharing.isDirectoryShareReadOnly)
    }

    func testWindowsShareDirectoryKeepsWebdav() throws {
        let state = wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        state.sharingDirectoryURL = URL(fileURLWithPath: "/tmp/shared")
        XCTAssertEqual(try qemuConfig(state).sharing.directoryShareMode, .webdav)
    }

    func testWindowsGetsUefiTpmLocalTimeAndToolsDrive() throws {
        let state = wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        state.isGuestToolsInstallRequested = true
        let config = try qemuConfig(state)
        XCTAssertTrue(config.qemu.hasUefiBoot)
        XCTAssertTrue(config.qemu.hasTPMDevice)
        XCTAssertTrue(config.qemu.hasPreloadedSecureBootKeys)
        XCTAssertTrue(config.qemu.hasRTCLocalTime)
        XCTAssertEqual(config.drives.filter(\.isExternal).count, 2, "boot image and guest tools")
        XCTAssertEqual(config.drives.count, 3)
    }

    func testWindowsWithoutGuestToolsHasNoSpareDrive() throws {
        let config = try qemuConfig(wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.q35))
        XCTAssertEqual(config.drives.count, 2)
    }

    /// Legacy Windows guests need PS/2 input and USB 2.0 (464fd7dd, a7103d3c).
    func testLegacyWindowsUsesPs2AndUsb2() throws {
        let state = wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.pc)
        state.legacyHardware = true
        state.isWindows10OrHigher = false
        let config = try qemuConfig(state)
        XCTAssertTrue(config.qemu.hasPS2Controller)
        XCTAssertEqual(config.input.usbBusSupport, .usb2_0)
        XCTAssertEqual(config.displays.first?.upscalingFilter, .nearest)
    }

    func testModernWindowsKeepsLinearUpscaling() throws {
        let config = try qemuConfig(wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.q35))
        XCTAssertFalse(config.qemu.hasPS2Controller)
        XCTAssertEqual(try XCTUnwrap(config.displays.first).upscalingFilter, .linear)
    }

    func testLinuxWithoutDisplayGetsSerialConsole() throws {
        let state = wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        state.isDisplayEnabled = false
        let config = try qemuConfig(state)
        XCTAssertTrue(config.displays.isEmpty)
        XCTAssertEqual(config.serials.count, 1)
    }

    func testLinuxDisplayFollowsGLSetting() throws {
        let state = wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-gpu-pci")
        state.isGLEnabled = true
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-gpu-gl-pci")
    }

    /// Windows always gets the GL variant of the default card, whether or not
    /// acceleration was ticked, since its guest tools expect it.
    func testWindowsAlwaysUsesGlVariantOfDefaultCard() throws {
        let state = wizard(.Windows, architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-vga-gl")
        state.isGLEnabled = true
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-vga-gl")
    }

    func testOtherGetsGlVariantOnlyWhenEnabled() throws {
        let state = wizard(.Other, architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-vga")
        state.isGLEnabled = true
        XCTAssertEqual(try qemuConfig(state).displays.first?.hardware.rawValue, "virtio-vga-gl")
    }

    func testKernelBootAddsKernelInitrdRootAndArguments() throws {
        let state = wizard(.Linux, architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        state.bootDevice = .kernel
        state.bootImageURL = nil
        state.linuxKernelURL = URL(fileURLWithPath: "/tmp/vmlinuz")
        state.linuxInitialRamdiskURL = URL(fileURLWithPath: "/tmp/initrd")
        state.linuxRootImageURL = URL(fileURLWithPath: "/tmp/root.img")
        state.linuxBootArguments = "console=ttyAMA0"
        let config = try qemuConfig(state)
        XCTAssertEqual(config.drives.map(\.imageType), [.linuxKernel, .linuxInitrd, .disk, .disk])
        XCTAssertEqual(config.drives[2].interface, .virtio)
        XCTAssertEqual(config.qemu.additionalArguments.map(\.string), ["-append", "console=ttyAMA0"])
    }

    func testClassicMacM68kAddsPramDriveFirstDiskAndNearestUpscaling() throws {
        let state = wizard(.ClassicMacOS, architecture: .m68k, target: QEMUTarget_m68k.q800)
        let config = try qemuConfig(state)
        XCTAssertEqual(config.drives.first?.imageType, .disk, "the system disk comes first so it is SCSI id 0")
        XCTAssertEqual(config.drives.first?.interface, .scsi)
        let pram = try XCTUnwrap(config.drives.first { $0.interface == .mtd })
        XCTAssertEqual(pram.sizeMib, 1)
        XCTAssertEqual(config.displays.first?.upscalingFilter, .nearest)
        XCTAssertFalse(config.qemu.hasUefiBoot)
    }

    // MARK: - Hardware page

    func testPickingAMachineSetsEverythingItImplies() {
        let state = VMWizardState()
        state.applyMachine(.quadra800)
        XCTAssertEqual(state.systemArchitecture, .m68k)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUTarget_m68k.q800.rawValue)
        XCTAssertEqual(state.systemMemoryMib, 128)
        XCTAssertEqual(state.systemCpuCount, 1)
        XCTAssertEqual(state.storageSizeGib, 2)
        XCTAssertTrue(state.legacyHardware)
        state.applyMachine(.q35)
        XCTAssertEqual(state.systemArchitecture, .x86_64)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUTarget_x86_64.q35.rawValue)
        XCTAssertEqual(state.systemCpuCount, 0, "no core limit means the default")
        XCTAssertFalse(state.legacyHardware)
    }

    func testEachOperatingSystemHasASupportedDefaultMachine() {
        for os in VMWizardOS.allCases {
            let machine = VMWizardState.SupportedMachine.default(for: os)
            XCTAssertTrue(machine.isSupported(running: os), "\(os)")
        }
    }

    func testWindowsRunsOnlyOnPcAndArm64Machines() {
        let windows = VMWizardState.SupportedMachine.allCases.filter { $0.isSupported(running: .Windows) }
        XCTAssertEqual(windows, [.i440FX, .q35, .arm64Virt])
        let classic = VMWizardState.SupportedMachine.allCases.filter { $0.isSupported(running: .ClassicMacOS) }
        XCTAssertEqual(classic, [.quadra800, .powerMacG4])
        XCTAssertEqual(VMWizardState.SupportedMachine.allCases.filter { $0.isSupported(running: .macOS) }, [.arm64Virt])
    }

    func testVirtualizationUsesTheHostArchitectureWithCurrentHardware() {
        let state = VMWizardState()
        state.legacyHardware = true
        state.prepareVirtualizedHardware()
        #if arch(arm64)
        XCTAssertEqual(state.systemArchitecture, .aarch64)
        #else
        XCTAssertEqual(state.systemArchitecture, .x86_64)
        #endif
        XCTAssertEqual(state.systemTarget.rawValue, state.systemArchitecture.targetType.default.rawValue)
        XCTAssertFalse(state.legacyHardware)
    }

    func testChangingTheArchitectureStartsOnItsDefaultMachine() {
        let state = VMWizardState()
        state.setSystemArchitecture(.aarch64)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUArchitecture.aarch64.targetType.default.rawValue)
    }

    func testMemoryIsKeptWithinTheMachineLimits() {
        let state = VMWizardState()
        state.systemMemoryMib = 4096
        state.clampSystemMemory(for: .powerMacG4, hostMaximumMib: 65536)
        XCTAssertEqual(state.systemMemoryMib, 2048)
        state.systemMemoryMib = 32
        state.clampSystemMemory(for: .powerMacG4, hostMaximumMib: 65536)
        XCTAssertEqual(state.systemMemoryMib, 64)
    }

    func testMemoryFallsBackToTheHostLimitForMachinesWithoutOne() {
        let state = VMWizardState()
        state.systemMemoryMib = 16384
        state.clampSystemMemory(for: .q35, hostMaximumMib: 8192)
        XCTAssertEqual(state.systemMemoryMib, 8192)
        state.systemMemoryMib = 16384
        state.clampSystemMemory(for: nil, hostMaximumMib: 8192)
        XCTAssertEqual(state.systemMemoryMib, 8192)
        state.systemMemoryMib = 1024
        state.clampSystemMemory(for: nil, hostMaximumMib: 8192)
        XCTAssertEqual(state.systemMemoryMib, 1024)
    }

    func testCoreCountIsKeptWithinTheHostRangeUnlessDefault() {
        let state = VMWizardState()
        for (entry, expected) in [(0, 0), (-1, 1), (4, 4), (20, 8)] {
            state.systemCpuCount = entry
            state.clampSystemCpuCount(in: 1...8)
            XCTAssertEqual(state.systemCpuCount, expected, "\(entry)")
        }
    }

    func testDisablingTheDisplayDisablesGpuAcceleration() {
        let state = VMWizardState()
        state.isGLEnabled = true
        state.setDisplayEnabled(false)
        XCTAssertFalse(state.isDisplayEnabled)
        XCTAssertFalse(state.isGLEnabled)
        state.isGLEnabled = true
        state.setDisplayEnabled(true)
        XCTAssertTrue(state.isGLEnabled)
    }

    // MARK: - Windows page

    func testWindows10OrHigherBootsUefiWithTpmAndGuestTools() {
        let state = VMWizardState()
        state.setWindows10OrHigher(false)
        XCTAssertFalse(state.isWindows10OrHigher)
        XCTAssertFalse(state.systemBootUefi)
        XCTAssertFalse(state.systemBootTpm)
        XCTAssertFalse(state.isGuestToolsInstallRequested)
        state.setWindows10OrHigher(true)
        XCTAssertTrue(state.systemBootUefi)
        XCTAssertTrue(state.systemBootTpm)
        XCTAssertTrue(state.isGuestToolsInstallRequested)
    }

    func testTurningUefiOffTurnsTheTpmOff() {
        let state = VMWizardState()
        state.setWindows10OrHigher(true)
        state.setBootUefi(false)
        XCTAssertFalse(state.systemBootUefi)
        XCTAssertFalse(state.systemBootTpm)
        state.setBootUefi(true)
        XCTAssertTrue(state.systemBootUefi)
        XCTAssertFalse(state.systemBootTpm, "UEFI alone does not bring the TPM back")
    }

    func testLegacyHardwareCannotInstallWindows10() {
        let state = VMWizardState()
        state.legacyHardware = true
        state.setWindows10OrHigher(true)
        state.prepareWindowsPage()
        XCTAssertEqual(state.bootDevice, .cd)
        XCTAssertFalse(state.isWindows10OrHigher)
        XCTAssertFalse(state.isGuestToolsInstallRequested)
        XCTAssertFalse(state.systemBootUefi)
        XCTAssertFalse(state.systemBootTpm)
    }

    #if !WITH_QEMU_TCI
    func testCurrentHardwareKeepsTheWindows10Choice() {
        let state = VMWizardState()
        state.legacyHardware = false
        state.setWindows10OrHigher(true)
        state.bootDevice = .kernel
        state.prepareWindowsPage()
        XCTAssertEqual(state.bootDevice, .cd)
        XCTAssertTrue(state.isWindows10OrHigher)
        XCTAssertTrue(state.systemBootUefi)
    }
    #endif

    #if os(macOS)
    // MARK: - Save location

    private func temporaryFolder(permissions: Int = 0o755) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: permissions])
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func testTheDefaultSaveLocationNeedsNoCheck() throws {
        let state = VMWizardState()
        XCTAssertNil(state.saveLocationURL)
        XCTAssertNoThrow(try state.validateSaveLocation())
    }

    func testAWritableFolderCanBeUsedAsSaveLocation() throws {
        let state = VMWizardState()
        state.saveLocationURL = try temporaryFolder()
        XCTAssertNoThrow(try state.validateSaveLocation())
    }

    func testAFolderThatIsGoneCannotBeUsedAsSaveLocation() throws {
        let state = VMWizardState()
        state.saveLocationURL = try temporaryFolder().appendingPathComponent("unplugged")
        XCTAssertThrowsError(try state.validateSaveLocation()) { error in
            guard case VMWizardError.saveLocationUnavailable(let name) = error else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(name, "unplugged")
        }
    }

    func testAFolderThatCannotBeWrittenToCannotBeUsedAsSaveLocation() throws {
        let state = VMWizardState()
        state.saveLocationURL = try temporaryFolder(permissions: 0o555)
        XCTAssertThrowsError(try state.validateSaveLocation()) { error in
            guard case VMWizardError.saveLocationReadOnly = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testANameAlreadyInTheSaveLocationIsRefusedBeforeAnythingIsCreated() throws {
        let folder = try temporaryFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Taken.utm"), withIntermediateDirectories: false)
        let state = VMWizardState()
        state.saveLocationURL = folder
        state.name = "Taken"
        XCTAssertThrowsError(try state.validateSaveLocation()) { error in
            guard case VMWizardError.saveLocationNameTaken(let name, let folderName) = error else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(name, "Taken")
            XCTAssertEqual(folderName, folder.lastPathComponent)
        }
        state.name = "Free"
        XCTAssertNoThrow(try state.validateSaveLocation())
    }

    func testTheNameCheckUsesTheSameFileNameAsTheSavedVirtualMachine() throws {
        let folder = try temporaryFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("a-b.utm"), withIntermediateDirectories: false)
        let state = VMWizardState()
        state.saveLocationURL = folder
        state.name = "a/b"
        XCTAssertThrowsError(try state.validateSaveLocation(), "characters that cannot be in a file name are replaced")
    }

    func testTheShownFolderIsWorkedOutWhenTheLocationIsChosen() throws {
        let folder = try temporaryFolder()
        let state = VMWizardState()
        XCTAssertNil(state.saveFolderPath)
        state.saveLocationURL = folder
        XCTAssertEqual(state.saveFolderPath, UTMData.virtualMachinesFolder(in: folder).path)
        state.saveLocationURL = nil
        XCTAssertNil(state.saveFolderPath)
    }

    #if arch(arm64)
    /// The VM of a macOS guest is created after its IPSW is downloaded, in the default storage.
    func testASaveLocationDoesNotApplyToAnIpswDownload() throws {
        let state = VMWizardState()
        state.useAppleVirtualization = true
        state.operatingSystem = .macOS
        state.macRecoveryIpswURL = try XCTUnwrap(URL(string: "https://example.com/restore.ipsw"))
        XCTAssertTrue(state.isPendingIPSWDownload)
        state.saveLocationURL = try temporaryFolder().appendingPathComponent("unplugged")
        XCTAssertNil(state.effectiveSaveLocationURL)
        XCTAssertNoThrow(try state.validateSaveLocation(), "a folder that is not used cannot stop the user from saving")
        state.macRecoveryIpswURL = image
        XCTAssertFalse(state.isPendingIPSWDownload)
        XCTAssertNotNil(state.effectiveSaveLocationURL)
        XCTAssertThrowsError(try state.validateSaveLocation())
    }
    #endif

    func testSaveLocationErrorsNameTheFolder() {
        XCTAssertTrue(VMWizardError.saveLocationUnavailable("Backup").localizedDescription.contains("Backup"))
        XCTAssertTrue(VMWizardError.saveLocationReadOnly("Backup").localizedDescription.contains("Backup"))
        XCTAssertTrue(VMWizardError.saveLocationFileSystemTooSmall("Backup").localizedDescription.contains("Backup"))
        let taken = VMWizardError.saveLocationNameTaken("Win", "Backup").localizedDescription
        XCTAssertTrue(taken.contains("Backup") && taken.contains("Win"))
    }
    #endif
}
