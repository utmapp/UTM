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
import CocoaSpice
@testable import UTM

/// The SPICE client reaches QEMU's Unix socket by a path relative to the socket's directory.
///
/// On macOS that directory can be the QEMU helper's container, which does not exist until the
/// helper launches for the first time, and the helper launches only after the SPICE client has
/// started. So starting the client must not need the directory; only connecting does. A
/// successful connection needs a running QEMU, which `VMLifecycleTests` covers.
final class UTMSpiceIOTests: XCTestCase {
    private static var savedModuleDirectory: String?
    private var savedDirectory: String!
    private var socketDirectory: URL!

    override class func setUp() {
        super.setUp()
        // GIO scans the module directory of the dependency build's install prefix when the SPICE
        // thread starts. The test host is not sandboxed, so when that prefix is in a protected
        // folder (such as Documents) the scan waits on a privacy prompt and the test hangs.
        let modules = FileManager.default.temporaryDirectory.appendingPathComponent("UTMSpiceIOTests-gio-modules", isDirectory: true)
        try? FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        savedModuleDirectory = ProcessInfo.processInfo.environment["GIO_MODULE_DIR"]
        setenv("GIO_MODULE_DIR", modules.path, 0)
    }

    override class func tearDown() {
        CSMain.shared.spiceStop()
        if let savedModuleDirectory {
            setenv("GIO_MODULE_DIR", savedModuleDirectory, 1)
        } else {
            unsetenv("GIO_MODULE_DIR")
        }
        super.tearDown()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedDirectory = FileManager.default.currentDirectoryPath
        socketDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("UTMSpiceIOTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(savedDirectory)
        try? FileManager.default.removeItem(at: socketDirectory)
        try super.tearDownWithError()
    }

    func testStartDoesNotNeedSocketDirectory() throws {
        let socketUrl = socketDirectory.appendingPathComponent("spice.sock")
        XCTAssertFalse(FileManager.default.fileExists(atPath: socketDirectory.path))
        let io = UTMSpiceIO(socketUrl: socketUrl, options: [])
        defer { io.disconnect() }
        XCTAssertNoThrow(try io.start())
        XCTAssertEqual(FileManager.default.currentDirectoryPath, savedDirectory)
    }

    func testConnectFailsWithoutSocketDirectory() throws {
        let socketUrl = socketDirectory.appendingPathComponent("spice.sock")
        let io = UTMSpiceIO(socketUrl: socketUrl, options: [])
        defer { io.disconnect() }
        try io.start()
        XCTAssertThrowsError(try io.connect()) { error in
            XCTAssertEqual(error.localizedDescription, NSLocalizedString("Failed to change current directory.", comment: "UTMSpiceIO"))
        }
        XCTAssertEqual(FileManager.default.currentDirectoryPath, savedDirectory)
    }

    /// A screenshot must not read the SPICE canvas after it is taken: SPICE frees the canvas when
    /// the guest changes resolution or the VM stops while the screenshot is still on screen (#7745).
    func testScreenshotOwnsItsPixels() throws {
        let width = 4, height = 2, stride = width * 4
        let canvas = UnsafeMutableRawPointer.allocate(byteCount: stride * height, alignment: 16)
        for i in 0..<(stride * height) {
            canvas.storeBytes(of: UInt8(truncatingIfNeeded: i), toByteOffset: i, as: UInt8.self)
        }
        let expected = Data(bytes: canvas, count: stride * height)
        // wrap the canvas without copying it, as CocoaSpice does for a non-GL display
        let provider = try XCTUnwrap(CGDataProvider(dataInfo: nil, data: canvas, size: stride * height, releaseData: { _, data, _ in data.deallocate() }))
        let wrapped = try XCTUnwrap(CGImage(width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bitsPerPixel: 32,
                                            bytesPerRow: stride,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue),
                                            provider: provider,
                                            decode: nil,
                                            shouldInterpolate: false,
                                            intent: .defaultIntent))
        #if os(macOS)
        let screenshot = CSScreenshot(image: NSImage(cgImage: wrapped, size: .zero))
        #else
        let screenshot = CSScreenshot(image: UIImage(cgImage: wrapped))
        #endif

        let owned = try XCTUnwrap(UTMSpiceIO.screenshotOwningPixels(screenshot))
        // SPICE reuses or frees the canvas
        canvas.initializeMemory(as: UInt8.self, repeating: 0xEE, count: stride * height)

        #if os(macOS)
        let image = try XCTUnwrap(owned.image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #else
        let image = try XCTUnwrap(owned.image.cgImage)
        #endif
        XCTAssertEqual(image.width, width)
        XCTAssertEqual(image.height, height)
        XCTAssertEqual(image.bytesPerRow, stride)
        XCTAssertEqual(image.bitmapInfo, wrapped.bitmapInfo)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(pixels, expected)
    }

    func testScreenshotOwningPixelsOfNothing() {
        XCTAssertNil(UTMSpiceIO.screenshotOwningPixels(nil))
    }
}
