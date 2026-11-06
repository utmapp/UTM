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

#if os(macOS)
import AppKit
import XCTest
@testable import UTM

/// Starts and stops real QEMU virtual machines inside the app the tests are hosted by.
///
/// Each test creates a disposable aarch64 VM with no drives, network or sound, which boots
/// the bundled EDK2 firmware to its shell in a few seconds under the hypervisor, drives it
/// through the same `UTMQemuVirtualMachine` calls the app makes, and deletes it. The host
/// must be a signed build with its own bundle prefix (`scripts/test_utm.sh -v`): the
/// hypervisor and the app group need the signature, and the unsigned unit-test host skips
/// every test here.
@MainActor
final class VMLifecycleTests: XCTestCase {
    private static let hostPrefix = UTMTestSupport.testBundlePrefix + "vm."
    private static let drawTimeout: TimeInterval = 60
    private static let stopTimeout: TimeInterval = 60

    private var packageDirectory: URL!
    private var vm: UTMQemuVirtualMachine?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let identifier = Bundle.main.bundleIdentifier ?? ""
        try XCTSkipUnless(identifier.hasPrefix(Self.hostPrefix), "VM tests run in the signed host only (scripts/test_utm.sh -v), not in \(identifier)")
        try XCTSkipUnless(UTMQemuVirtualMachine.isSupported(systemArchitecture: .aarch64), "this host cannot run aarch64 virtual machines")
        packageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("VMLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let vm = vm, let logURL = vm.config.qemu.debugLogURL, let log = try? String(contentsOf: logURL, encoding: .utf8) {
            let attachment = XCTAttachment(string: log)
            attachment.name = "debug.log"
            add(attachment)
            if testRun?.hasSucceeded == false, !log.isEmpty {
                print("--- QEMU debug.log ---\n\(log.suffix(4000))\n--- end ---")
            }
        }
        if let vm = vm {
            if vm.state != .stopped {
                try? await vm.stop(usingMethod: .kill)
                _ = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
            }
            UTMRegistry.shared.remove(entry: vm.registryEntry)
            UTMRegistry.shared.sync()
        }
        vm = nil
        if let packageDirectory = packageDirectory {
            try? FileManager.default.removeItem(at: packageDirectory)
        }
        try await super.tearDown()
    }

    /// A QEMU aarch64 VM that boots the firmware shell: no drives, no network, no sound, the default display.
    private func makeShellVM(additionalArguments: [String] = []) async throws -> UTMQemuVirtualMachine {
        let config = UTMQemuConfiguration()
        config.system.architecture = .aarch64
        config.system.target = QEMUTarget_aarch64.virt
        config.reset(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.information.name = "lifecycle"
        config.drives = []
        config.networks = []
        config.sound = []
        config.qemu.additionalArguments = additionalArguments.map { QEMUArgument($0) }
        // QEMU's own output lands in Data/debug.log, which a failure attaches
        config.qemu.hasDebugLog = true
        let vm = try UTMQemuVirtualMachine(newForConfiguration: config, destinationUrl: packageDirectory)
        try await vm.save()
        self.vm = vm
        return vm
    }

    /// Polls the VM's state until it is `expected` or the timeout passes.
    private func waitForState(_ vm: UTMQemuVirtualMachine, _ expected: UTMVirtualMachineState, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if vm.state == expected {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return vm.state == expected
    }

    /// Whether every sampled pixel of the image has the same colour; nil for an image without pixels.
    private static func isUniform(_ image: NSImage) -> Bool? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let first = bitmap.colorAt(x: 0, y: 0)
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 40)) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 40)) where bitmap.colorAt(x: x, y: y) != first {
                return false
            }
        }
        return true
    }

    /// Takes screenshots until one shows more than a single colour or the timeout passes.
    private func waitForDrawnDisplay(_ vm: UTMQemuVirtualMachine, timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            _ = await vm.takeScreenshot()
            if let image = vm.screenshot?.image, try XCTUnwrap(Self.isUniform(image), "the screenshot has no pixels") == false {
                return true
            }
            if Date() >= deadline {
                return false
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    /// Start reaches `started`, the display shows something, a forced stop reaches `stopped`.
    func testStartShowsTheFirmwareAndStopsByForce() async throws {
        let vm = try await makeShellVM()
        XCTAssertEqual(vm.state, .stopped)
        try await vm.start()
        XCTAssertEqual(vm.state, .started)
        let drawn = try await waitForDrawnDisplay(vm, timeout: Self.drawTimeout)
        if let data = vm.screenshot?.pngData {
            add(XCTAttachment(data: data, uniformTypeIdentifier: "public.png"))
        }
        XCTAssertTrue(drawn, "the display stayed a single colour for \(Int(Self.drawTimeout)) s: the firmware did not draw")
        XCTAssertEqual(vm.state, .started, "the VM stopped on its own")
        try await vm.stop(usingMethod: .force)
        let stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
    }

    /// A VM can be started again after a forced stop.
    func testStartsAgainAfterAForcedStop() async throws {
        let vm = try await makeShellVM()
        for _ in 0..<2 {
            try await vm.start()
            XCTAssertEqual(vm.state, .started)
            try await vm.stop(usingMethod: .force)
            let stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
            XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
        }
    }

    /// A QEMU that exits at once (an unknown option) leaves the VM `stopped` with an error
    /// instead of stuck in `starting`.
    func testEarlyQemuExitReportsStopped() async throws {
        let vm = try await makeShellVM(additionalArguments: ["-bogus-option-for-the-test"])
        do {
            try await vm.start()
            XCTFail("starting with an unknown QEMU option did not fail")
        } catch {
            // the error names the option; a start that never returns is the regression
        }
        XCTAssertEqual(vm.state, .stopped)
    }

    /// A paused VM can be killed.
    func testStopByKillWhilePaused() async throws {
        let vm = try await makeShellVM()
        try await vm.start()
        try await vm.pause()
        let paused = await waitForState(vm, .paused, timeout: Self.stopTimeout)
        XCTAssertTrue(paused, "the VM is \(vm.state) after pause")
        try await vm.stop(usingMethod: .kill)
        let stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after kill")
    }
}
#endif
