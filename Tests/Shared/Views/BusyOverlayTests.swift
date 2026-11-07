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

/// Inspection of an `@EnvironmentObject`-driven view and of the alert it presents.
@MainActor
final class BusyOverlayTests: XCTestCase {
    private var data: UTMData!

    override func setUp() {
        // UTMData reads and writes the VM list in UserDefaults; under the test host that is
        // the com.utmapp.test.UTM container, never the installed app's.
        data = UTMData()
    }

    override func tearDown() {
        data = nil
    }

    private func inspect() throws -> InspectableView<ViewType.Group> {
        try BusyOverlay().environmentObject(data!).inspect().group()
    }

    func testIndicatorIsShownOnlyWhileBusy() throws {
        data.busy = false
        XCTAssertThrowsError(try inspect().find(ViewType.View<BusyIndicator>.self))
        data.busy = true
        XCTAssertNoThrow(try inspect().find(ViewType.View<BusyIndicator>.self))
    }

    func testNoAlertWithoutAnAlertItem() throws {
        data.alertItem = nil
        XCTAssertThrowsError(try inspect().alert())
    }

    func testMessageAlertItemPresentsTheMessage() throws {
        data.alertItem = .message("Something went wrong")
        let alert = try inspect().alert()
        XCTAssertEqual(try alert.title().string(), "Something went wrong")
    }

    func testDownloadAlertItemOffersCancelAndDownload() throws {
        data.alertItem = .downloadUrl(URL(string: "https://example.com/vm.zip")!)
        let alert = try inspect().alert()
        XCTAssertEqual(try alert.title().string(), "Download VM")
        XCTAssertEqual(try alert.primaryButton().style(), .cancel)
        XCTAssertEqual(try alert.secondaryButton().labelView().string(), "Download")
    }
}
