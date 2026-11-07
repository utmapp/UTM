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

import SwiftUI
import ViewInspector
import XCTest
@testable import UTM

/// Synchronous inspection of a `@Binding`-driven configuration view.
@MainActor
final class VMConfigDriveCreateViewTests: XCTestCase {
    /// A new, non-removable virtio disk; XCTest creates a fresh instance per test.
    private var config: UTMQemuConfigurationDrive = {
        var drive = UTMQemuConfigurationDrive()
        drive.imageType = .disk
        drive.interface = .virtio
        return drive
    }()

    private func makeView() -> VMConfigDriveCreateView {
        VMConfigDriveCreateView(config: Binding(get: { self.config }, set: { self.config = $0 }))
    }

    private func removableToggle() throws -> InspectableView<ViewType.Toggle> {
        try makeView().inspect().find(ViewType.Toggle.self, containing: "Removable")
    }

    func testRemovableToggleIsBoundToIsExternal() throws {
        XCTAssertFalse(try removableToggle().isOn())
        try removableToggle().tap()
        XCTAssertTrue(config.isExternal)
        XCTAssertTrue(try removableToggle().isOn())
    }

    func testTurningRemovableOnMakesAReadOnlyRawCd() throws {
        config.isExternal = true
        try removableToggle().callOnChange(newValue: true)
        XCTAssertEqual(config.imageType, .cd)
        XCTAssertTrue(config.isRawImage)
        XCTAssertTrue(config.isReadOnly)
    }

    func testTurningRemovableOnUsesTheDefaultInterfaceForTheNewImageType() throws {
        config.defaultInterfaceForImageType = { $0 == .cd ? .usb : .virtio }
        config.isExternal = true
        try removableToggle().callOnChange(newValue: true)
        XCTAssertEqual(config.interface, .usb)
    }

    func testTurningRemovableOffRestoresAWritableDiskImage() throws {
        config.isExternal = true
        config.imageType = .cd
        config.isRawImage = true
        config.isReadOnly = true
        config.isExternal = false
        try removableToggle().callOnChange(newValue: false)
        XCTAssertEqual(config.imageType, .disk)
        XCTAssertFalse(config.isRawImage)
        XCTAssertFalse(config.isReadOnly)
    }

    func testRemovableFloppyStaysADiskImage() throws {
        config.interface = .floppy
        config.isExternal = true
        try removableToggle().callOnChange(newValue: true)
        XCTAssertEqual(config.imageType, .disk)
    }

    func testChangingInterfaceToFloppyTurnsARemovableCdIntoADisk() throws {
        config.isExternal = true
        config.imageType = .cd
        config.interface = .floppy
        let picker = try makeView().inspect().find(ViewType.View<VMConfigConstantPicker>.self)
        try picker.callOnChange(newValue: QEMUDriveInterface.floppy)
        XCTAssertEqual(config.imageType, .disk)
    }

    func testSizeAndRawImageControlsAreHiddenForRemovableDrives() throws {
        config.isExternal = true
        XCTAssertThrowsError(try makeView().inspect().find(ViewType.View<SizeTextField>.self))
        XCTAssertThrowsError(try makeView().inspect().find(ViewType.Toggle.self, containing: "Raw Image"))
        config.isExternal = false
        XCTAssertNoThrow(try makeView().inspect().find(ViewType.View<SizeTextField>.self))
        XCTAssertNoThrow(try makeView().inspect().find(ViewType.Toggle.self, containing: "Raw Image"))
    }
}
