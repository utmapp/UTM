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
import XCTest
@testable import UTM

/// The whole command line of a few canonical configurations, compared with a recorded
/// copy under `Tests/Fixtures/expected/`.
///
/// The targeted tests in `QemuArgumentsTests` check the arguments a fix changed; these
/// catch every other change to the command line, intended or not. Each configuration is
/// built in code with a fixed UUID, CPU model and count, the host state the generator reads
/// is pinned, the firmware images exist so the UEFI drives are on the line, and the one
/// path that differs per machine (the resources) is masked. Hypervisor and JIT are off so
/// the line is the same on every Mac; the goldens are macOS command lines, which differ
/// from the iOS ones in their sockets, audio and serial backends.
///
/// To record new goldens, run the class with `TEST_RUNNER_UTM_RECORD_GOLDENS=1` in the
/// environment: each test writes `<name>.argv` under the host's temporary directory and
/// skips with the path. Copy the files into `Tests/Fixtures/expected/` and review the diff.
@MainActor final class QemuArgumentGoldenTests: QemuArgumentTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        UTMCapabilities.current = []
        setDefaults(["UseFileLock": true, "QEMURendererBackend": 0, "QEMUVulkanDriver": 0, "QEMUDirectXDriver": 0, "QEMUSoundBackend": 0])
        stageFirmware("edk2-aarch64-code.fd")
        stageFirmware("edk2-x86_64-code.fd")
    }

    /// The defaults for the architecture and target with everything that would vary
    /// between runs or hosts fixed.
    private func goldenConfiguration(architecture: QEMUArchitecture, target: any QEMUTarget) -> UTMQemuConfiguration {
        let config = configuration(architecture: architecture, target: target)
        config.information.name = "Golden"
        config.information.uuid = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        config.qemu.hasHypervisor = false
        if architecture == .x86_64 {
            // the default model is picked for the host's CPU
            config.system.cpu = QEMUCPU_x86_64.Skylake_Client
        }
        // the same network on every platform, with a fixed address
        for index in config.networks.indices {
            config.networks[index].mode = .emulated
            config.networks[index].macAddress = "02:00:00:00:00:0\(index + 1)"
        }
        return config
    }

    /// The command line with the resources path and the per-drive identifiers (a drive's
    /// id is a UUID chosen when it is created) replaced by placeholders.
    private func maskedArguments(_ config: UTMQemuConfiguration) -> [String] {
        arguments(config).strings.map { argument in
            var masked = argument.replacingOccurrences(of: resources.path, with: "$RESOURCES")
            for (index, drive) in config.drives.enumerated() {
                masked = masked.replacingOccurrences(of: drive.serial, with: "$SERIAL\(index)")
                    .replacingOccurrences(of: drive.id, with: "$DRIVE\(index)")
            }
            return masked
        }
    }

    private func compare(_ config: UTMQemuConfiguration, with name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = maskedArguments(config)
        let text = actual.joined(separator: "\n") + "\n"
        if ProcessInfo.processInfo.environment["UTM_RECORD_GOLDENS"] != nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("utm-goldens", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name).appendingPathExtension("argv")
            try text.write(to: url, atomically: true, encoding: .utf8)
            throw XCTSkip("recorded \(url.path)")
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "argv"), "no golden named \(name)", file: file, line: line)
        // one argument per line, the file ending with a newline; an empty argument is an empty line
        let expected = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
        guard actual != expected else {
            return
        }
        let index = (0..<min(actual.count, expected.count)).first { actual[$0] != expected[$0] } ?? min(actual.count, expected.count)
        let got = actual.indices.contains(index) ? actual[index] : "<end>"
        let wanted = expected.indices.contains(index) ? expected[index] : "<end>"
        XCTFail("\(name).argv differs at argument \(index): got \"\(got)\", expected \"\(wanted)\". Whole command line:\n\(text)", file: file, line: line)
    }

    func testAarch64VirtWithAVirtioDisk() throws {
        let config = goldenConfiguration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = [drive(config, interface: .virtio)]
        try compare(config, with: "aarch64-virt-virtio-disk")
    }

    func testAarch64VirtHeadlessWithASerialPort() throws {
        let config = goldenConfiguration(architecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.displays = []
        config.serials = [UTMQemuConfigurationSerial()]
        config.drives = [drive(config, interface: .virtio)]
        try compare(config, with: "aarch64-virt-headless-serial")
    }

    func testX86_64Q35WithAnIdeCdAndDisk() throws {
        let config = goldenConfiguration(architecture: .x86_64, target: QEMUTarget_x86_64.q35)
        config.drives = [drive(config, interface: .ide, type: .cd, imageURL: nil), drive(config, interface: .ide)]
        try compare(config, with: "x86_64-q35-ide-cd-disk")
    }

    func testX86_64PcWithAnIdeDisk() throws {
        let config = goldenConfiguration(architecture: .x86_64, target: QEMUTarget_x86_64.pc)
        config.drives = [drive(config, interface: .ide)]
        try compare(config, with: "x86_64-pc-ide-disk")
    }
}
#endif
