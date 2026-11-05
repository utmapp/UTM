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

/// Command lines generated from a configuration. Each test builds its
/// configuration in code from the per-architecture defaults, pins the host
/// state the generator reads (user defaults, capabilities, CPU count), and
/// asserts on the arguments the fix it names would have changed.
@MainActor final class QemuArgumentsTests: XCTestCase {
    private var savedCapabilities: UTMCapabilities!
    private var savedArguments: [String: Any]!
    private var resources: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedCapabilities = UTMCapabilities.current
        savedArguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        resources = FileManager.default.temporaryDirectory.appendingPathComponent("qemu-resources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        UTMQemuConfiguration.resourceURLOverride = resources
    }

    override func tearDownWithError() throws {
        UTMQemuConfiguration.resourceURLOverride = nil
        UTMCapabilities.current = savedCapabilities
        UserDefaults.standard.setVolatileDomain(savedArguments, forName: UserDefaults.argumentDomain)
        try FileManager.default.removeItem(at: resources)
        try super.tearDownWithError()
    }

    /// Settings the generator reads from `UserDefaults.standard`, applied through the
    /// argument domain so nothing is written to disk and the host's own launch
    /// arguments stay in place.
    private func setDefaults(_ values: [String: Any]) {
        var domain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        domain.merge(values) { _, new in new }
        UserDefaults.standard.setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
    }

    private func configuration(architecture: QEMUArchitecture, target: any QEMUTarget) -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.system.architecture = architecture
        config.system.target = target
        config.reset(forArchitecture: architecture, target: target)
        config.system.cpuCount = 2
        config.information.name = "Test"
        return config
    }

    private func drive(_ config: UTMQemuConfiguration, interface: QEMUDriveInterface, type: QEMUDriveImageType = .disk, imageURL: URL? = URL(fileURLWithPath: "/tmp/image.qcow2"), interfaceVersion: Int = UTMQemuConfigurationDrive.latestInterfaceVersion) -> UTMQemuConfigurationDrive {
        var drive = UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target)
        drive.imageType = type
        drive.interface = interface
        drive.imageURL = imageURL
        drive.interfaceVersion = interfaceVersion
        return drive
    }

    private func arguments(_ config: UTMQemuConfiguration) -> QEMUArgumentList {
        QEMUArgumentList(config.allArguments)
    }

    // MARK: Drives

    /// A CD drive with nothing inserted has no file, so `file.locking=off` must not
    /// be emitted for it even when file locking is globally disabled (c50daa63).
    func testNoLockingOptionForEmptyCdWhenLockingDisabled_c50daa63() throws {
        setDefaults(["UseFileLock": false])
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = [drive(config, interface: .usb, type: .cd, imageURL: nil)]
        let args = arguments(config)
        let cd = try XCTUnwrap(args.value(of: "-drive", containing: "media=cdrom"))
        let options = QEMUArgumentList.options(cd)
        XCTAssertFalse(options.contains("file.locking=off"), cd)
        XCTAssertFalse(options.contains { $0.hasPrefix("file.filename=") }, cd)
        XCTAssertTrue(options.contains("readonly=on"), cd)
    }

    func testLockingDisabledOnDiskWhenSettingIsOff() throws {
        setDefaults(["UseFileLock": false])
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = [drive(config, interface: .virtio)]
        let disk = try XCTUnwrap(arguments(config).value(of: "-drive", containing: "media=disk"))
        XCTAssertTrue(QEMUArgumentList.options(disk).contains("file.locking=off"), disk)
    }

    func testLockingKeptWhenSettingIsOn() throws {
        setDefaults(["UseFileLock": true])
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = [drive(config, interface: .virtio)]
        let disk = try XCTUnwrap(arguments(config).value(of: "-drive", containing: "media=disk"))
        XCTAssertFalse(QEMUArgumentList.options(disk).contains("file.locking=off"), disk)
    }

    /// Machines other than the PC family take two units per IDE bus (44973db9).
    func testIdeDrivesShareBusesInPairsOnVirt() {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = (0..<3).map { _ in drive(config, interface: .ide) }
        let devices = arguments(config).devices(ofType: "ide-hd").map(QEMUArgumentList.options)
        guard devices.count == 3 else {
            return XCTFail("expected 3 IDE devices, got \(devices)")
        }
        XCTAssertTrue(devices[0].contains("bus=ide.0") && devices[0].contains("unit=0"), "\(devices[0])")
        XCTAssertTrue(devices[1].contains("bus=ide.0") && devices[1].contains("unit=1"), "\(devices[1])")
        XCTAssertTrue(devices[2].contains("bus=ide.1") && devices[2].contains("unit=0"), "\(devices[2])")
    }

    /// PC machines are hard-coded to one unit per IDE bus in QEMU (f072dced).
    func testIdeDrivesGetOneBusEachOnPc() {
        let config = configuration(architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        config.drives = (0..<3).map { _ in drive(config, interface: .ide) }
        let devices = arguments(config).devices(ofType: "ide-hd").map(QEMUArgumentList.options)
        guard devices.count == 3 else {
            return XCTFail("expected 3 IDE devices, got \(devices)")
        }
        for (index, options) in devices.enumerated() {
            XCTAssertTrue(options.contains("bus=ide.\(index)"), "\(options)")
            XCTAssertFalse(options.contains { $0.hasPrefix("unit=") }, "\(options)")
        }
    }

    /// Drives saved before the pairing change keep one bus each so their guest
    /// device order does not change (interface version 0).
    func testLegacyInterfaceVersionKeepsOneIdeBusPerDrive() throws {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = (0..<2).map { _ in drive(config, interface: .ide, interfaceVersion: 0) }
        let second = try XCTUnwrap(arguments(config).devices(ofType: "ide-hd").dropFirst().first)
        let options = QEMUArgumentList.options(second)
        XCTAssertTrue(options.contains("bus=ide.1"), second)
        XCTAssertFalse(options.contains { $0.hasPrefix("unit=") }, second)
    }

    /// The device carries the drive's shortened serial, not its 36-character id (0f138b8a).
    func testVirtioDriveCarriesDriveSerial_0f138b8a() throws {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = [drive(config, interface: .virtio)]
        let device = try XCTUnwrap(arguments(config).devices(ofType: "virtio-blk-pci").first)
        XCTAssertTrue(QEMUArgumentList.options(device).contains("serial=\(config.drives[0].serial)"), device)
    }

    /// `-prom-env boot-device=` chooses the boot device on PowerPC, and QEMU
    /// rejects it together with `bootindex` (#5717).
    func testBootIndexOmittedWhenPromEnvSelectsBootDevice() throws {
        let config = configuration(architecture: .ppc, target: QEMUTarget_ppc.mac99)
        config.drives = [drive(config, interface: .ide)]
        config.qemu.additionalArguments = [QEMUArgument("-prom-env"), QEMUArgument("boot-device=hd:,\\yaboot")]
        let device = try XCTUnwrap(arguments(config).devices(ofType: "ide-hd").first)
        XCTAssertFalse(QEMUArgumentList.options(device).contains { $0.hasPrefix("bootindex=") }, device)
        config.qemu.additionalArguments = []
        let withIndex = try XCTUnwrap(arguments(config).devices(ofType: "ide-hd").first)
        XCTAssertTrue(QEMUArgumentList.options(withIndex).contains("bootindex=0"), withIndex)
    }

    // MARK: Input

    /// With a PS/2 controller the USB keyboard and mouse would show up as
    /// duplicate input devices in the guest (a7103d3c).
    func testNoUsbHidDevicesWhenPs2ControllerIsUsed_a7103d3c() {
        let config = configuration(architecture: .x86_64, target: QEMUTarget_x86_64.pc)
        config.input.usbBusSupport = .usb2_0
        config.qemu.hasPS2Controller = true
        let args = arguments(config)
        XCTAssertTrue(args.devices(ofType: "usb-kbd").isEmpty)
        XCTAssertTrue(args.devices(ofType: "usb-mouse").isEmpty)
        XCTAssertFalse(args.devices(ofType: "usb-tablet").isEmpty, "the tablet is independent of PS/2")
    }

    func testUsbHidDevicesWithoutPs2Controller() {
        let config = configuration(architecture: .x86_64, target: QEMUTarget_x86_64.pc)
        config.input.usbBusSupport = .usb2_0
        config.qemu.hasPS2Controller = false
        let args = arguments(config)
        XCTAssertEqual(args.devices(ofType: "usb-kbd").count, 1)
        XCTAssertEqual(args.devices(ofType: "usb-mouse").count, 1)
    }

    // MARK: Custom arguments

    /// A quoted word is one argument; quotes inside a word are kept (1cf09506).
    func testQuotedCustomArgumentsAreSplitAndUnquoted_1cf09506() {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.qemu.additionalArguments = [QEMUArgument("-custom \"My VM\" -device virtio-rng,id=\"rng 0\"")]
        XCTAssertEqual(Array(arguments(config).strings.suffix(4)), ["-custom", "My VM", "-device", "virtio-rng,id=\"rng 0\""])
    }

    func testCustomArgumentsFollowGeneratedOnes() {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.qemu.additionalArguments = [QEMUArgument("-custom"), QEMUArgument("value")]
        let strings = arguments(config).strings
        XCTAssertEqual(strings.suffix(2), ["-custom", "value"])
        XCTAssertEqual(QEMUArgumentList(config.generatedArguments).strings.count, strings.count - 2)
    }

    // MARK: Sharing

    /// VirtFS sharing must produce the `-fsdev` without any further user action (#5531).
    func testVirtfsShareEmitsFsdevAndDevice() throws {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.sharing.directoryShareMode = .virtfs
        config.sharing.directoryShareUrl = URL(fileURLWithPath: "/tmp/shared")
        config.sharing.isDirectoryShareReadOnly = true
        let args = arguments(config)
        let fsdev = try XCTUnwrap(args.values(of: "-fsdev").first)
        let options = QEMUArgumentList.options(fsdev)
        XCTAssertEqual(options.first, "local", fsdev)
        XCTAssertTrue(options.contains("path=/tmp/shared") && options.contains("readonly=on"), fsdev)
        let device = try XCTUnwrap(args.devices(ofType: "virtio-9p-pci").first)
        XCTAssertTrue(QEMUArgumentList.options(device).contains("fsdev=virtfs0"), device)
    }

    func testNoFsdevWithoutVirtfs() {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.sharing.directoryShareMode = .webdav
        config.sharing.directoryShareUrl = URL(fileURLWithPath: "/tmp/shared")
        XCTAssertTrue(arguments(config).values(of: "-fsdev").isEmpty)
    }

    // MARK: Accelerator

    #if WITH_JIT
    /// Without the JIT entitlement QEMU needs mirror-mapped code (split-wx).
    func testSplitWxFollowsJitEntitlement() throws {
        let config = configuration(architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        config.qemu.hasHypervisor = false
        UTMCapabilities.current = []
        let withoutJit = try XCTUnwrap(arguments(config).values(of: "-accel").first)
        XCTAssertTrue(QEMUArgumentList.options(withoutJit).contains("split-wx=on"), withoutJit)
        UTMCapabilities.current = [.hasJitEntitlements]
        let withJit = try XCTUnwrap(arguments(config).values(of: "-accel").first)
        XCTAssertFalse(QEMUArgumentList.options(withJit).contains("split-wx=on"), withJit)
    }
    #endif

    func testCpuCountIsTakenFromConfiguration() throws {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.system.cpuCount = 3
        let smp = try XCTUnwrap(arguments(config).values(of: "-smp").first)
        XCTAssertTrue(QEMUArgumentList.options(smp).contains("cpus=3"), smp)
    }

    // MARK: UEFI

    private func stageFirmware(_ name: String) {
        FileManager.default.createFile(atPath: resources.appendingPathComponent(name).path, contents: Data())
    }

    private func pflashDrives(_ config: UTMQemuConfiguration) -> [String] {
        arguments(config).values(of: "-drive").filter { $0.hasPrefix("if=pflash") }
    }

    /// The firmware pflash drives appear only when the firmware image exists in
    /// the resource directory.
    func testUefiFirmwareDrivesFollowAvailableImage() throws {
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        XCTAssertTrue(config.qemu.hasUefiBoot, "virt defaults to UEFI")
        XCTAssertTrue(pflashDrives(config).isEmpty, "no firmware image staged yet")

        stageFirmware("edk2-aarch64-code.fd")
        let pflash = pflashDrives(config)
        guard pflash.count == 2 else {
            return XCTFail("expected code and vars drives, got \(pflash)")
        }
        let code = QEMUArgumentList.options(pflash[0])
        XCTAssertTrue(code.contains("unit=0") && code.contains("readonly=on"), pflash[0])
        XCTAssertTrue(code.contains("file.filename=\(resources.appendingPathComponent("edk2-aarch64-code.fd").path)"), pflash[0])
        XCTAssertTrue(QEMUArgumentList.options(pflash[1]).contains("unit=1"), pflash[1])

        config.qemu.hasUefiBoot = false
        XCTAssertTrue(pflashDrives(config).isEmpty)
    }

    /// A user-supplied BIOS or kernel replaces the bundled firmware.
    func testCustomBiosSuppressesUefiFirmware() throws {
        stageFirmware("edk2-aarch64-code.fd")
        let config = configuration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        XCTAssertEqual(pflashDrives(config).count, 2, "firmware is used without a custom BIOS")
        config.drives = [drive(config, interface: .none, type: .bios, imageURL: URL(fileURLWithPath: "/tmp/bios.bin"))]
        XCTAssertTrue(config.hasCustomBios)
        XCTAssertTrue(pflashDrives(config).isEmpty)
    }
}
