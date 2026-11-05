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
import AppKit
import SwiftUI
import XCTest

/// Renders a SwiftUI view offscreen at 1x and compares it with a reference image
/// bundled under `Tests/Fixtures/snapshots/`.
///
/// References are per OS version: `<name>.<platform><major>.<minor>.png`, such as
/// `wizard-summary-linux.macOS27.2.png`, because SwiftUI's layout metrics shift by a pixel
/// or two between releases. A test with no reference for the OS it runs on is skipped, so a
/// runner on another version never fails on it. macOS only until the iOS
/// bundle has references of its own. The host app is sandboxed
/// and cannot read the source tree, which is why the references are bundle resources and
/// a mismatch attaches the rendered image to the test result instead of writing a diff
/// next to the reference. To record references, run with `TEST_RUNNER_UTM_RECORD_SNAPSHOTS=1`
/// in the environment: each test writes its image under the host's temporary directory
/// and skips with the path.
@MainActor
enum SnapshotSupport {
    /// The channel difference above which a pixel counts as changed (out of 255).
    static let pixelTolerance = 24
    /// The share of changed pixels above which the images differ.
    static let changedPixelTolerance = 0.005

    static let platform = "macOS"

    /// The reference's name for this OS version.
    static func referenceName(_ name: String) -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(name).\(platform)\(version.majorVersion).\(version.minorVersion)"
    }

    /// Renders the view at the given size in points, 1 pixel per point, light appearance,
    /// a fixed accent colour (the system accent would otherwise tint symbols and controls).
    ///
    /// The language comes from the host process: `scripts/test_utm.sh` runs the tests in
    /// English, which the `NSLocalizedString` calls in the views follow.
    static func render<V: View>(_ view: V, size: CGSize) -> CGImage? {
        let content = view
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .accentColor(.blue)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        window.contentView = nil
        return bitmap.cgImage
    }

    static func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    static func image(from data: Data) -> CGImage? {
        NSBitmapImageRep(data: data)?.cgImage
    }

    /// Both images as 8-bit RGBA rows, premultiplied, in the sRGB space.
    static func rgba(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }

    /// The share of pixels that differ by more than the tolerance, or nil when the sizes differ.
    static func changedPixelShare(_ actual: CGImage, _ reference: CGImage) -> Double? {
        guard actual.width == reference.width, actual.height == reference.height,
              let a = rgba(actual), let r = rgba(reference) else {
            return nil
        }
        var changed = 0
        for pixel in stride(from: 0, to: a.count, by: 4) {
            for channel in 0..<4 where abs(Int(a[pixel + channel]) - Int(r[pixel + channel])) > pixelTolerance {
                changed += 1
                break
            }
        }
        return Double(changed) / Double(actual.width * actual.height)
    }
}

extension XCTestCase {
    /// Renders the view and compares it with the reference named `name` for this OS.
    @MainActor
    func assertSnapshot<V: View>(of view: V, named name: String, size: CGSize, file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try XCTUnwrap(SnapshotSupport.render(view, size: size), "the view did not render", file: file, line: line)
        let png = try XCTUnwrap(SnapshotSupport.pngData(actual), "the image could not be encoded", file: file, line: line)
        let referenceName = SnapshotSupport.referenceName(name)
        if ProcessInfo.processInfo.environment["UTM_RECORD_SNAPSHOTS"] != nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("utm-snapshots", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(referenceName).appendingPathExtension("png")
            try png.write(to: url)
            throw XCTSkip("recorded \(url.path)")
        }
        guard let url = Bundle(for: Self.self).url(forResource: referenceName, withExtension: "png") else {
            throw XCTSkip("no reference \(referenceName).png for this OS; record one with UTM_RECORD_SNAPSHOTS")
        }
        let reference = try XCTUnwrap(SnapshotSupport.image(from: try Data(contentsOf: url)), "\(referenceName).png is not an image", file: file, line: line)
        let attach = {
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "\(referenceName).actual.png"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        guard let share = SnapshotSupport.changedPixelShare(actual, reference) else {
            attach()
            XCTFail("\(referenceName): rendered \(actual.width)x\(actual.height), the reference is \(reference.width)x\(reference.height)", file: file, line: line)
            return
        }
        if share > SnapshotSupport.changedPixelTolerance {
            attach()
            XCTFail("\(referenceName): \(String(format: "%.2f", share * 100))% of the pixels differ from the reference (the rendered image is attached)", file: file, line: line)
        }
    }
}
#endif
