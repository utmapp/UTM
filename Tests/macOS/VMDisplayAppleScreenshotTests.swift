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

/// An Apple virtual machine's screenshot is a capture of its display window's content view,
/// taken every minute while it runs and when it pauses. AppleScript can shrink that window
/// until the view has no area (#7650), and the capture then has nothing to draw into.
@MainActor
final class VMDisplayAppleScreenshotTests: XCTestCase {
    private var packageDirectory: URL!
    private var vm: UTMAppleVirtualMachine?

    override func setUpWithError() throws {
        try super.setUpWithError()
        packageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("VMDisplayAppleScreenshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vm = vm {
            UTMRegistry.shared.remove(entry: vm.registryEntry)
            UTMRegistry.shared.sync()
        }
        vm = nil
        if let packageDirectory = packageDirectory {
            try? FileManager.default.removeItem(at: packageDirectory)
        }
        try super.tearDownWithError()
    }

    func testImageOfEmptyViewIsNil() {
        let view = NSView(frame: .zero)
        XCTAssertNil(view.cachedDisplayImage())
    }

    func testImageOfViewWithNoHeightIsNil() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 0))
        XCTAssertNil(view.cachedDisplayImage())
    }

    /// `set bounds of window … to {0, 0, 0, 0}` sets the window's frame to an empty rectangle.
    func testImageOfWindowShrunkToNothingIsNil() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: true)
        window.isReleasedWhenClosed = false
        defer {
            window.close()
        }
        window.setFrame(.zero, display: false)
        XCTAssertNil(window.contentView!.cachedDisplayImage())
    }

    func testImageOfViewHasItsSize() throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 64, height: 48))
        let image = try XCTUnwrap(view.cachedDisplayImage())
        XCTAssertEqual(image.size, NSSize(width: 64, height: 48))
    }

    /// When the window is shrunk to nothing, the VM keeps the screenshot it took before, so
    /// its thumbnail and paused view are not cleared.
    func testVirtualMachineKeepsScreenshotWhenWindowIsEmpty() async throws {
        let config = UTMAppleConfiguration()
        config.information.name = "screenshot"
        let package = packageDirectory.appendingPathComponent("screenshot.utm", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let vm = try UTMAppleVirtualMachine(packageUrl: package, configuration: config)
        self.vm = vm
        let window = ViewScreenshotProvider(view: NSView(frame: NSRect(x: 0, y: 0, width: 64, height: 48)))
        vm.screenshotDelegate = window
        await vm.takeScreenshot()
        let screenshot = try XCTUnwrap(vm.screenshot, "the window was not captured")
        window.view.frame = .zero
        await vm.takeScreenshot()
        XCTAssertTrue(vm.screenshot?.image === screenshot.image, "the screenshot was replaced by an empty capture")
    }
}

/// Stands in for the display window: captures a view the way `VMDisplayAppleWindowController` does.
private final class ViewScreenshotProvider: UTMScreenshotProvider {
    let view: NSView

    init(view: NSView) {
        self.view = view
    }

    var screenshot: UTMVirtualMachineScreenshot? {
        view.cachedDisplayImage().map { UTMVirtualMachineScreenshot(wrapping: $0) }
    }
}
