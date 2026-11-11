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

/// SPICE reads and writes the shared pasteboard from its own thread while the main thread
/// polls it for changes. `NSPasteboard` does not allow that by itself, so `UTMPasteboard`
/// has to serialize the two.
///
/// The test uses a pasteboard of its own, so the general pasteboard is never touched.
final class UTMPasteboardTests: XCTestCase {
    private var systemPasteboard: NSPasteboard!
    private var pasteboard: UTMPasteboard!

    override func setUp() {
        systemPasteboard = NSPasteboard(name: NSPasteboard.Name("UTMPasteboardTests." + UUID().uuidString))
        pasteboard = UTMPasteboard(for: systemPasteboard)
    }

    override func tearDown() {
        pasteboard = nil
        systemPasteboard.releaseGlobally()
        systemPasteboard = nil
    }

    /// Without the lock, AppKit's type cache is changed under the reading thread and the
    /// host ends with an uncaught exception (or a crash) within a few thousand rounds.
    func testReadsFromAnotherThreadWhileTheMainThreadPollsAndWrites() {
        let rounds = 50_000
        pasteboard.setString("0")
        let finished = expectation(description: "the other thread finished reading")
        let pasteboard = self.pasteboard!
        Thread.detachNewThread {
            for _ in 0..<rounds {
                _ = pasteboard.data(for: .string)
            }
            finished.fulfill()
        }
        for round in 0..<rounds {
            _ = pasteboard.canReadItem(for: .png)
            _ = pasteboard.hasContents()
            if round % 50 == 0 {
                pasteboard.setString("\(round)")
            }
        }
        wait(for: [finished], timeout: 120)
        XCTAssertEqual(pasteboard.string(), "\(rounds - 50)")
    }
}
