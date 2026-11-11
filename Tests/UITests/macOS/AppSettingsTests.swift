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

#if UTM_UI_TESTS
/// Geometry of the app-wide settings panes in the running macOS app.
final class AppSettingsTests: UTMUITestCase {
    /// Waits until the window's frame has been the same for three samples in a row, as it is
    /// once a pane has been swapped in and the window resized to it.
    private func waitForSettledFrame(of window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var frame = window.frame
        var same = 0
        for _ in 0..<40 {
            Thread.sleep(forTimeInterval: 0.25)
            let next = window.frame
            same = next == frame ? same + 1 : 0
            frame = next
            if same >= 2 {
                return
            }
        }
        XCTFail("the settings window kept changing its frame", file: file, line: line)
    }

    /// Every element of the snapshot, depth first.
    private func elements(of snapshot: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [snapshot] + snapshot.children.flatMap { elements(of: $0) }
    }

    /// Every element of every pane of the app settings window lies within the window (#7117,
    /// #7319: a pane larger than the window had its edges cut off).
    func testEveryAppSettingsPaneFitsItsWindow() throws {
        app.typeKey(",", modifierFlags: .command)
        // SwiftUI's Settings scene names its window
        let window = app.windows["com_apple_SwiftUI_Settings_window"].firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "the settings window did not open")
        let toolbar = window.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10), "the settings toolbar did not appear")
        let tabs = toolbar.buttons.allElementsBoundByIndex
        XCTAssertEqual(tabs.count, 7, "the settings toolbar does not contain every pane")
        for tab in tabs {
            let pane = tab.label
            tab.click()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "title == %@", pane), object: window)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, "\(pane) did not become selected")
            waitForSettledFrame(of: window)
            // kept with a failure, so that the cut-off pane can be seen
            let shot = XCTAttachment(screenshot: window.screenshot())
            shot.name = "settings-\(pane)"
            add(shot)
            let bounds = window.frame.insetBy(dx: -1, dy: -1)
            for element in elements(of: try window.snapshot()) where !element.frame.isEmpty {
                XCTAssertTrue(bounds.contains(element.frame), "\(pane): \(element.elementType.rawValue) '\(element.label)' at \(element.frame) lies outside the window \(window.frame)")
            }
        }
        window.buttons[XCUIIdentifierCloseWindow].click()
    }
}
#else
import AppKit
import SwiftUI
@testable import UTM

@MainActor
final class AppSettingsTests: XCTestCase {
    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    private func checkLatestClick(_ destination: Int) async throws {
        _ = NSApplication.shared
        let panes = (0..<3).map { index in
            let host = NSHostingController(rootView: Text("Pane \(index)").frame(width: 400, height: CGFloat(100 + index * 80)))
            let item = NSTabViewItem(viewController: host)
            item.identifier = "pane\(index)"
            item.label = "Pane \(index)"
            return item
        }
        let controller = SettingsTabViewController(panes: panes)
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 400, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.close() }
        let ready = await waitUntil { window.toolbar?.items.count == panes.count && window.title == panes[0].label }
        XCTAssertTrue(ready, "The settings toolbar did not appear")
        let toolbar = try XCTUnwrap(window.toolbar)
        let first = try XCTUnwrap(toolbar.items.first { $0.itemIdentifier.rawValue == "pane1" })
        let last = try XCTUnwrap(toolbar.items.first { $0.itemIdentifier.rawValue == "pane\(destination)" })
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(first.action), to: first.target, from: first))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(last.action), to: last.target, from: last))
        let intermediate = await waitUntil { controller.selectedTabViewItemIndex == 1 }
        XCTAssertTrue(intermediate, "The first transition did not run")
        let finished = await waitUntil { controller.selectedTabViewItemIndex == destination && window.title == panes[destination].label }
        XCTAssertTrue(finished, "The most recent toolbar click was lost")
    }

    func testReturningToCurrentPaneDuringTransitionUsesLatestClick() async throws {
        try await checkLatestClick(0)
    }

    func testThirdPaneDuringTransitionUsesLatestClick() async throws {
        try await checkLatestClick(2)
    }

    private func picker(in view: NSView) -> NSPopUpButton? {
        (view as? NSPopUpButton) ?? view.subviews.lazy.compactMap { self.picker(in: $0) }.first
    }

    func testUnavailablePickerValuesDoNotDisplayAnotherChoice() async throws {
        _ = NSApplication.shared
        var selection = 3
        let options = [("Default", 0), ("Disabled", 1), ("MoltenVK", 2)]
        let makePicker = { options in
            NativeSettingsPicker(title: "Vulkan Driver", selection: Binding(get: { selection }, set: { selection = $0 }), options: options)
        }
        let host = NSHostingView(rootView: makePicker(options))
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        host.layoutSubtreeIfNeeded()
        _ = await waitUntil { self.picker(in: host) != nil }
        let button = try XCTUnwrap(picker(in: host))
        XCTAssertNil(button.selectedItem, "An unavailable value must not appear as Default")
        XCTAssertEqual(selection, 3, "Rendering must preserve the stored setting")
        selection = 2
        for (items, index) in [(options, 2), (Array(options.prefix(2)), -1), (options, 2)] {
            host.rootView = makePicker(items)
            let updated = await waitUntil {
                host.layoutSubtreeIfNeeded()
                return button.numberOfItems == items.count && button.indexOfSelectedItem == index
            }
            XCTAssertTrue(updated, "Expected selection \(index) with \(items.count) options")
            XCTAssertEqual(selection, 2)
        }
        button.selectItem(at: 0)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(button.action), to: button.target, from: button))
        XCTAssertEqual(selection, 0, "The user must still be able to choose a supported value")
    }
}
#endif
