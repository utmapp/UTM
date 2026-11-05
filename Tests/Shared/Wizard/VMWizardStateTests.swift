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
}
