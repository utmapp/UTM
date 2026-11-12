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

/// The error shown when a macOS install fails because the disk holding the VM is full (#7958).
final class AppleVMInstallErrorTests: XCTestCase {
    /// What `VZMacOSInstaller` returned when the VM's volume filled up during a macOS 14.6.1 restore
    /// on a macOS 27.2 host: no POSIX error, only the generic installation failure.
    private let installationFailed: NSError = {
        let restore = NSError(domain: "com.apple.MobileDevice.MobileRestore", code: 9, userInfo: [
            NSLocalizedDescriptionKey: "RestoreOS device removed before restored completed",
        ])
        return NSError(domain: "VZErrorDomain", code: 10007, userInfo: [
            NSLocalizedFailureErrorKey: "An error occurred during installation.",
            NSLocalizedFailureReasonErrorKey: "Installation failed.",
            NSUnderlyingErrorKey: restore,
        ])
    }()

    func testFullDiskIsReported() throws {
        let error = try XCTUnwrap(UTMAppleVirtualMachine.installNotEnoughDiskSpaceError(for: installationFailed, availableCapacity: 32 << 20))
        guard case .installNotEnoughDiskSpace(let available, let reason) = error else {
            return XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(available, ByteCountFormatter.string(fromByteCount: 32 << 20, countStyle: .file))
        XCTAssertEqual(reason, installationFailed.localizedDescription, "Virtualization's own message is kept")
        let message = try XCTUnwrap(error.errorDescription)
        XCTAssertTrue(message.contains(available), "the free space is not in the message: \(message)")
        XCTAssertTrue(message.contains(installationFailed.localizedDescription), "the original error is not in the message: \(message)")
    }

    func testEnoughSpaceKeepsTheOriginalError() {
        XCTAssertNil(UTMAppleVirtualMachine.installNotEnoughDiskSpaceError(for: installationFailed, availableCapacity: 100 << 30))
        XCTAssertNil(UTMAppleVirtualMachine.installNotEnoughDiskSpaceError(for: installationFailed, availableCapacity: UTMAppleVirtualMachine.installMinimumAvailableCapacity))
    }

    func testUnknownSpaceKeepsTheOriginalError() {
        XCTAssertNil(UTMAppleVirtualMachine.installNotEnoughDiskSpaceError(for: installationFailed, availableCapacity: nil))
    }

    /// Only the installer's generic failure is replaced: errors UTM raised itself, a cancelled
    /// install and errors from before the installer ran already say what is wrong.
    func testOtherErrorsAreNotReplaced() {
        let others: [Error] = [
            UTMAppleVirtualMachineError.ipswNotReadable,
            NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError),
            CancellationError(),
            NSError(domain: "VZErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid virtual machine configuration."]),
            NSError(domain: "VZErrorDomain", code: 10006),
        ]
        for error in others {
            XCTAssertNil(UTMAppleVirtualMachine.installNotEnoughDiskSpaceError(for: error, availableCapacity: 0), "\(error) was replaced")
        }
    }

    func testAvailableCapacityIsRead() throws {
        let capacity = try XCTUnwrap(UTMAppleVirtualMachine.availableCapacity(ofVolumeAt: FileManager.default.temporaryDirectory))
        XCTAssertGreaterThan(capacity, 0)
    }
}
#endif
