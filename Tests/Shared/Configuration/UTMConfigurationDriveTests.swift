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
}
