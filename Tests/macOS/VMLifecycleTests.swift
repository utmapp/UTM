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

    /// A QEMU aarch64 VM that boots the firmware shell: no drives, no network, no sound, the default
    /// display, and whatever `configure` adds.
    private func makeShellVM(additionalArguments: [String] = [], configure: (UTMQemuConfiguration) -> Void = { _ in }) async throws -> UTMQemuVirtualMachine {
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
        configure(config)
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

    /// A free TCP port on the loopback interface.
    private static func freePort() throws -> Int {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        defer { close(socket) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socket, $0, length) == 0 && getsockname(socket, $0, &length) == 0 }
        }
        guard bound else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return Int(in_port_t(bigEndian: address.sin_port))
    }

    /// A connection to the serial port QEMU serves on the loopback interface.
    private final class SerialConsole {
        private let socket: Int32
        private(set) var text = ""

        /// Connects, retrying until QEMU listens or the timeout passes.
        init(port: Int, timeout: TimeInterval) async throws {
            let deadline = Date().addingTimeInterval(timeout)
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(port).bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            while true {
                let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
                let connected = withUnsafePointer(to: &address) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 }
                }
                if connected {
                    _ = fcntl(socket, F_SETFL, fcntl(socket, F_GETFL) | O_NONBLOCK)
                    self.socket = socket
                    return
                }
                let error = errno
                close(socket)
                guard Date() < deadline else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(error), userInfo: [NSLocalizedDescriptionKey: "no connection to the serial port \(port) within \(Int(timeout)) s: \(String(cString: strerror(error)))"])
                }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        deinit {
            close(socket)
        }

        func send(_ string: String) {
            _ = string.withCString { write(socket, $0, strlen($0)) }
        }

        /// Reads until the text read so far contains `marker` or the timeout passes; a closed
        /// console throws.
        @discardableResult
        func read(until marker: String, timeout: TimeInterval) async throws -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            var buffer = [UInt8](repeating: 0, count: 4096)
            while Date() < deadline {
                let count = Darwin.read(socket, &buffer, buffer.count)
                if count > 0 {
                    text += String(decoding: buffer[0..<count], as: UTF8.self)
                    if text.contains(marker) {
                        return true
                    }
                } else if count == 0 || errno != EAGAIN {
                    let error = count == 0 ? ECONNRESET : errno
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(error), userInfo: [NSLocalizedDescriptionKey: "the serial console closed: \(String(cString: strerror(error)))"])
                } else {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            return false
        }
    }

    private static let shellPrompt = "Shell>"
    private static let firmwareBanner = "UEFI Interactive Shell"

    /// Adds a serial port served over TCP on a free port to the configuration.
    private static func addSerialPort(to config: UTMQemuConfiguration) throws -> Int {
        let port = try freePort()
        var serial = UTMQemuConfigurationSerial()
        serial.mode = .tcpServer
        serial.tcpPort = port
        config.serials = [serial]
        return port
    }

    /// The firmware console reaches a serial port served over TCP.
    func testSerialPortCarriesTheFirmwareConsole() async throws {
        var port = 0
        let vm = try await makeShellVM { config in
            port = (try? Self.addSerialPort(to: config)) ?? 0
        }
        XCTAssertNotEqual(port, 0, "no free port")
        try await vm.start()
        let console = try await SerialConsole(port: port, timeout: Self.drawTimeout)
        let prompt = try await console.read(until: Self.shellPrompt, timeout: Self.drawTimeout)
        add(XCTAttachment(string: console.text))
        XCTAssertTrue(prompt, "no shell prompt on the serial port within \(Int(Self.drawTimeout)) s")
        try await vm.stop(usingMethod: .force)
        let stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
    }

    /// A saved state marks the VM suspended and the next start resumes it: the shell answers
    /// on the serial port without the firmware booting again.
    func testSuspendedStateIsRestoredOnTheNextStart() async throws {
        var port = 0
        let vm = try await makeShellVM { config in
            port = (try? Self.addSerialPort(to: config)) ?? 0
            // a save needs a disk image to keep the state in
            var drive = UTMQemuConfigurationDrive(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
            drive.sizeMib = 32
            config.drives = [drive]
        }
        XCTAssertNotEqual(port, 0, "no free port")
        try await vm.start()
        let booted = try await SerialConsole(port: port, timeout: Self.drawTimeout)
        let prompt = try await booted.read(until: Self.shellPrompt, timeout: Self.drawTimeout)
        XCTAssertTrue(prompt, "no shell prompt before the save")
        try await vm.saveSnapshot()
        XCTAssertTrue(vm.registryEntry.isSuspended, "the VM is not marked suspended after a save")
        // iOS can suspend the app as soon as the save returns, so the mark must be stored by then
        let stored = UserDefaults.standard.dictionary(forKey: "Registry")?[vm.id.uuidString] as? [String: Any]
        XCTAssertEqual(stored?["Suspended"] as? Bool, true, "the suspended mark is not in the stored registry when the save returns")
        try await vm.stop(usingMethod: .force)
        var stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
        try await vm.start()
        XCTAssertEqual(vm.state, .started)
        XCTAssertFalse(vm.registryEntry.isSuspended, "the saved state was not consumed by the start")
        // a resumed shell answers a newline with a new prompt; a fresh boot prints its banner first
        let resumed = try await SerialConsole(port: port, timeout: Self.drawTimeout)
        resumed.send("\r")
        let answered = try await resumed.read(until: Self.shellPrompt, timeout: Self.drawTimeout)
        add(XCTAttachment(string: resumed.text))
        XCTAssertTrue(answered, "the shell did not answer on the serial port after the resume")
        XCTAssertFalse(resumed.text.contains(Self.firmwareBanner), "the firmware booted again instead of resuming the saved state")
        try await vm.stop(usingMethod: .force)
        stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
    }

    /// A restart resets the guest, which boots the firmware again, and leaves the VM started.
    func testRestartBootsTheFirmwareAgain() async throws {
        var port = 0
        let vm = try await makeShellVM { config in
            port = (try? Self.addSerialPort(to: config)) ?? 0
        }
        XCTAssertNotEqual(port, 0, "no free port")
        try await vm.start()
        let console = try await SerialConsole(port: port, timeout: Self.drawTimeout)
        let prompt = try await console.read(until: Self.shellPrompt, timeout: Self.drawTimeout)
        XCTAssertTrue(prompt, "no shell prompt before the restart")
        let before = console.text.components(separatedBy: Self.firmwareBanner).count - 1
        try await vm.restart()
        XCTAssertEqual(vm.state, .started)
        let deadline = Date().addingTimeInterval(Self.drawTimeout)
        var banners = before
        while banners <= before && Date() < deadline {
            try await console.read(until: Self.shellPrompt, timeout: 1)
            banners = console.text.components(separatedBy: Self.firmwareBanner).count - 1
        }
        add(XCTAttachment(string: console.text))
        XCTAssertGreaterThan(banners, before, "the firmware did not boot again after the restart")
        try await vm.stop(usingMethod: .force)
        let stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
    }

    /// A VM whose display was removed after a run starts again without one.
    func testStartsHeadlessAfterItsDisplayIsRemoved() async throws {
        let vm = try await makeShellVM()
        try await vm.start()
        try await vm.stop(usingMethod: .force)
        var stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
        vm.config.displays = []
        try await vm.save()
        try await vm.start()
        XCTAssertEqual(vm.state, .started)
        try await vm.stop(usingMethod: .force)
        stopped = await waitForState(vm, .stopped, timeout: Self.stopTimeout)
        XCTAssertTrue(stopped, "the VM is \(vm.state) after a forced stop")
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
