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

/// The number-to-size rules behind the drive size field.
final class SizeTextFieldTests: XCTestCase {
    private let mibPerGib = SizeTextField.mibPerGib

    /// A GiB entry too large for an `Int` of MiB used to trap on overflow and crash
    /// the app (8c18e750, #7295); it is reported as 0 instead.
    func testGiBEntryThatOverflowsBecomesZero() {
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: Int.max, isGiB: true), 0)
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: Int.max / mibPerGib + 1, isGiB: true), 0)
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: Int.min, isGiB: true), 0)
    }

    /// A negative entry is scaled like any other and left for the minimum-size rule.
    func testNegativeEntryIsScaledNotRejected() {
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: -1, isGiB: true), -mibPerGib)
        XCTAssertEqual(SizeTextField.validSize(-mibPerGib, minSizeMib: 1), 1)
    }

    func testLargestGiBEntryThatFitsIsKept() {
        let largest = Int.max / mibPerGib
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: largest, isGiB: true), largest * mibPerGib)
    }

    func testGiBEntryIsScaledAndMiBEntryIsNot() {
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: 7, isGiB: true), 7 * mibPerGib)
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: 500, isGiB: false), 500)
        XCTAssertEqual(SizeTextField.mibValue(fromDisplay: Int.max, isGiB: false), Int.max)
    }

    func testDisplayTruncatesToWholeGiB() {
        XCTAssertEqual(SizeTextField.displayValue(fromMib: 1536, isGiB: true), 1)
        XCTAssertEqual(SizeTextField.displayValue(fromMib: 1536, isGiB: false), 1536)
        XCTAssertEqual(SizeTextField.displayValue(fromMib: 0, isGiB: true), 0)
    }

    func testWholeGiBRoundTrips() {
        for gib in [1, 7, 64, 2048] {
            let mib = SizeTextField.mibValue(fromDisplay: gib, isGiB: true)
            XCTAssertEqual(SizeTextField.displayValue(fromMib: mib, isGiB: true), gib)
        }
    }

    func testSizeBelowMinimumIsRaisedToMinimum() {
        XCTAssertEqual(SizeTextField.validSize(0, minSizeMib: 1), 1)
        XCTAssertEqual(SizeTextField.validSize(-5, minSizeMib: 1), 1)
        XCTAssertEqual(SizeTextField.validSize(10, minSizeMib: 1), 10)
        XCTAssertEqual(SizeTextField.validSize(100, minSizeMib: 512), 512)
    }
}
