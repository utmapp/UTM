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

/// Comma handling in QEMU argument fragments. Inside an option list QEMU reads
/// "," as a separator, so a path merged after "file=" must double its commas
/// (e65ad0b8), while a path that is the whole argument must not (a2552606).
/// Arguments are written the way `UTMQemuConfiguration+Arguments.swift` does:
/// a final fragment opens an argument, plain fragments join it with commas,
/// and an empty final fragment closes it.
final class QEMUArgumentFragmentTests: XCTestCase {
    private let commaPath = URL(fileURLWithPath: "/tmp/disk,one.qcow2")

    private func build(@QEMUArgumentBuilder _ content: () -> [QEMUArgument]) -> [QEMUArgument] {
        content()
    }

    private func f(_ string: String = "") -> QEMUArgumentFragment {
        QEMUArgumentFragment(final: string)
    }

    func testDrivePathWithCommaIsDoubled() throws {
        let args = build {
            f("-drive")
            "if=none"
            "file="
            commaPath
            "format=qcow2"
            f()
        }
        XCTAssertEqual(args.map(\.string), ["-drive", "if=none,file=/tmp/disk,,one.qcow2,format=qcow2"])
        XCTAssertEqual(try XCTUnwrap(args.last).fileUrls, [commaPath])
    }

    func testSingleUrlArgumentIsNotEscaped_a2552606() throws {
        let args = build {
            f("-kernel")
            commaPath
            f()
        }
        XCTAssertEqual(args.map(\.string), ["-kernel", "/tmp/disk,one.qcow2"], "a bare path is not an option list, so QEMU must see its commas as-is")
        XCTAssertEqual(try XCTUnwrap(args.last).fileUrls, [commaPath])
    }

    func testPlainFragmentsAreNotEscaped() throws {
        let args = build {
            f("-device")
            "virtio-net-pci"
            "mac=00:11:22:33:44:55"
            f()
        }
        XCTAssertEqual(args.map(\.string), ["-device", "virtio-net-pci,mac=00:11:22:33:44:55"])
        XCTAssertNil(try XCTUnwrap(args.last).fileUrls)
    }

    func testUrlJoinsPreviousFragmentWithoutSeparator() throws {
        let args = build {
            f("-drive")
            "file="
            commaPath
            f()
        }
        XCTAssertEqual(args.map(\.string), ["-drive", "file=/tmp/disk,,one.qcow2"])
        XCTAssertEqual(try XCTUnwrap(args.last).fileUrls, [commaPath])
    }

    func testFinalFragmentsEndArguments() {
        let args = build {
            f("-m")
            512
            f()
            f("-smp")
            f("cpus=4")
        }
        XCTAssertEqual(args.map(\.string), ["-m", "512", "-smp", "cpus=4"])
    }
}
