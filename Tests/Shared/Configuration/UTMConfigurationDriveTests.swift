//
// Copyright © 2026 osy. All rights reserved.
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

final class UTMConfigurationDriveTests: XCTestCase {
    /// virtio-blk and Virtualization.framework reject serial numbers over 20
    /// characters, and a UUID-derived id is 36 (0f138b8a, #7355).
    func testDriveSerialIs20CharsWithoutDashes_0f138b8a() {
        let drive = UTMQemuConfigurationDrive()
        XCTAssertEqual(drive.id.count, 36)
        XCTAssertEqual(drive.serial.count, 20)
        XCTAssertFalse(drive.serial.contains("-"))
        XCTAssertTrue(drive.id.replacingOccurrences(of: "-", with: "").hasPrefix(drive.serial))
    }

    func testTwoDrivesGetDistinctSerials() {
        XCTAssertNotEqual(UTMQemuConfigurationDrive().serial, UTMQemuConfigurationDrive().serial)
    }

    // MARK: - Creating a QEMU drive

    private func newDisk(interface: QEMUDriveInterface = .virtio) -> UTMQemuConfigurationDrive {
        var drive = UTMQemuConfigurationDrive()
        drive.imageType = .disk
        drive.interface = interface
        return drive
    }

    func testMakingANewDriveRemovableGivesAReadOnlyRawCd() {
        var drive = newDisk()
        drive.setRemovable(true)
        XCTAssertTrue(drive.isExternal)
        XCTAssertEqual(drive.imageType, .cd)
        XCTAssertTrue(drive.isRawImage)
        XCTAssertTrue(drive.isReadOnly)
        XCTAssertEqual(drive.interface, .virtio, "no default interface was given, so it is kept")
    }

    func testMakingANewDriveRemovableUsesTheDefaultInterfaceForACd() {
        var drive = newDisk()
        drive.defaultInterfaceForImageType = { $0 == .cd ? .usb : .virtio }
        drive.setRemovable(true)
        XCTAssertEqual(drive.interface, .usb)
        XCTAssertEqual(drive.imageType, .cd)
    }

    func testMakingANewDriveRemovableWhenTheDefaultInterfaceIsAFloppyGivesADisk() {
        var drive = newDisk()
        drive.defaultInterfaceForImageType = { _ in .floppy }
        drive.setRemovable(true)
        XCTAssertEqual(drive.interface, .floppy)
        XCTAssertEqual(drive.imageType, .disk, "a floppy cannot hold a CD image")
    }

    func testANewRemovableFloppyStaysADiskWithoutADefaultInterface() {
        var drive = newDisk(interface: .floppy)
        drive.setRemovable(true)
        XCTAssertEqual(drive.imageType, .disk)
        XCTAssertEqual(drive.interface, .floppy)
        XCTAssertTrue(drive.isRawImage)
        XCTAssertTrue(drive.isReadOnly)
    }

    /// Drives the app creates know their default interface, so a floppy made removable
    /// moves to the default interface for a disk and becomes a CD there.
    func testANewRemovableFloppyFollowsTheDefaultInterface() {
        var drive = UTMQemuConfigurationDrive(forArchitecture: .x86_64, target: QEMUTarget_x86_64.q35)
        drive.interface = .floppy
        drive.setRemovable(true)
        XCTAssertEqual(drive.interface, .ide)
        XCTAssertEqual(drive.imageType, .cd)
    }

    func testMakingANewDriveFixedAgainGivesAWritableDiskImage() {
        var drive = newDisk()
        drive.setRemovable(true)
        drive.setRemovable(false)
        XCTAssertFalse(drive.isExternal)
        XCTAssertEqual(drive.imageType, .disk)
        XCTAssertFalse(drive.isRawImage)
        XCTAssertFalse(drive.isReadOnly)
    }

    func testChangingANewRemovableDriveToAFloppyAndBackSwitchesCdAndDisk() {
        var drive = newDisk()
        drive.setRemovable(true)
        drive.setInterfaceWhenCreating(.floppy)
        XCTAssertEqual(drive.imageType, .disk)
        drive.setInterfaceWhenCreating(.ide)
        XCTAssertEqual(drive.imageType, .cd)
    }

    func testChangingANewFixedDriveInterfaceKeepsADiskImage() {
        var drive = newDisk()
        drive.setInterfaceWhenCreating(.ide)
        XCTAssertEqual(drive.imageType, .disk)
        XCTAssertEqual(drive.interface, .ide)
    }

    // MARK: - Editing an existing QEMU drive

    func testChangingTheImageTypeAwayFromDiskMakesItReadOnly() {
        for imageType in [QEMUDriveImageType.cd, .bios, .linuxKernel, .linuxInitrd, .linuxDtb] {
            var drive = newDisk()
            drive.setImageType(imageType)
            XCTAssertTrue(drive.isReadOnly, "\(imageType)")
            XCTAssertFalse(drive.isReadOnlyEditable, "\(imageType)")
        }
    }

    func testChangingTheImageTypeToDiskOrNoneKeepsTheReadOnlyChoice() {
        for imageType in [QEMUDriveImageType.disk, .none] {
            var drive = newDisk()
            drive.isReadOnly = false
            drive.setImageType(imageType)
            XCTAssertFalse(drive.isReadOnly, "\(imageType)")
            XCTAssertTrue(drive.isReadOnlyEditable, "\(imageType)")
        }
    }

    func testOnlyDiskAndCdImagesHaveASelectableInterface() {
        for imageType in QEMUDriveImageType.allCases {
            var drive = newDisk()
            drive.imageType = imageType
            XCTAssertEqual(drive.hasSelectableInterface, imageType == .disk || imageType == .cd, "\(imageType)")
        }
    }

    func testChangingTheInterfaceOfACdToFloppyMakesItADisk() {
        var cd = newDisk()
        cd.imageType = .cd
        cd.setInterface(.floppy)
        XCTAssertEqual(cd.imageType, .disk)
        var disk = newDisk()
        disk.setInterface(.floppy)
        XCTAssertEqual(disk.imageType, .disk)
    }

    /// Drives saved before the IDE layout change keep interface version 0 until the user
    /// picks an interface or asks for the update (44973db9, f072dced).
    func testChangingTheInterfaceMovesTheDriveToTheCurrentLayout() {
        var drive = newDisk(interface: .ide)
        drive.interfaceVersion = 0
        XCTAssertTrue(drive.isInterfaceUpdateAvailable)
        drive.setInterface(.ide)
        XCTAssertEqual(drive.interfaceVersion, UTMQemuConfigurationDrive.latestInterfaceVersion)
        XCTAssertFalse(drive.isInterfaceUpdateAvailable)
    }

    func testUpdatingTheInterfaceMovesTheDriveToTheCurrentLayout() {
        var drive = newDisk(interface: .ide)
        drive.interfaceVersion = 0
        drive.updateInterface()
        XCTAssertEqual(drive.interfaceVersion, UTMQemuConfigurationDrive.latestInterfaceVersion)
        XCTAssertFalse(drive.isInterfaceUpdateAvailable)
    }

    func testOnlyAnOutdatedIdeDriveOffersTheInterfaceUpdate() {
        var virtio = newDisk(interface: .virtio)
        virtio.interfaceVersion = 0
        XCTAssertFalse(virtio.isInterfaceUpdateAvailable)
        XCTAssertFalse(newDisk(interface: .ide).isInterfaceUpdateAvailable)
    }

    #if os(macOS)
    // MARK: - Creating an Apple Virtualization drive

    func testMakingANewAppleDriveRemovableDropsItsImage() {
        var drive = UTMAppleConfigurationDrive(newSize: 4096)
        drive.isNvme = true
        drive.setRemovable(true, isASIFSupported: true)
        XCTAssertTrue(drive.isExternal)
        XCTAssertEqual(drive.sizeMib, 0)
        XCTAssertTrue(drive.isReadOnly)
        XCTAssertFalse(drive.isNvme)
    }

    func testMakingANewAppleDriveFixedAgainGivesADefaultSizedImage() {
        for isASIFSupported in [true, false] {
            var drive = UTMAppleConfigurationDrive(newSize: 4096)
            drive.setRemovable(true, isASIFSupported: isASIFSupported)
            drive.setRemovable(false, isASIFSupported: isASIFSupported)
            XCTAssertFalse(drive.isExternal)
            XCTAssertEqual(drive.sizeMib, 10240)
            XCTAssertFalse(drive.isReadOnly)
            XCTAssertEqual(drive.isASIF, isASIFSupported)
        }
    }
    #endif
}
