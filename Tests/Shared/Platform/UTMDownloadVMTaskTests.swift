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

/// Extracting a downloaded `.utm` from a ZIP: only the package is taken, and an
/// archive cannot write outside it (ed73d11d) or plant a symbolic link (34d48fec).
final class UTMDownloadVMTaskTests: XCTestCase {
    private var folder: URL!
    private let task = UTMDownloadVMTask(for: URL(string: "https://example.invalid/Test.zip")!)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("Download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func archive(_ build: (inout ZipArchiveBuilder) -> Void) throws -> URL {
        var builder = ZipArchiveBuilder()
        build(&builder)
        let url = folder.appendingPathComponent("download.zip")
        try builder.write(to: url)
        return url
    }

    private func extract(_ zip: URL) throws -> URL {
        try task.partialUnzipOnlyUtmVM(zipFileURL: zip, destinationFolder: folder, fileManager: .default)
    }

    private func contents(of directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    // MARK: Containment

    func testContainedPathsResolveInsideTheFolder() throws {
        let root = folder.appendingPathComponent("dest.utm", isDirectory: true)
        let inside = { (name: String) in root.appendingPathComponent(name).standardized.path }
        XCTAssertEqual(try task.containedDestination(for: "config.plist", in: root, isDirectory: false).path, inside("config.plist"))
        XCTAssertEqual(try task.containedDestination(for: "Data/disk.qcow2", in: root, isDirectory: false).path, inside("Data/disk.qcow2"))
        XCTAssertEqual(try task.containedDestination(for: "Data/", in: root, isDirectory: true).path, inside("Data"))
        XCTAssertEqual(try task.containedDestination(for: "Data/../config.plist", in: root, isDirectory: false).path, inside("config.plist"))
    }

    func testEscapingPathsAreRejected_ed73d11d() {
        let root = folder.appendingPathComponent("dest.utm", isDirectory: true)
        for relative in ["../elsewhere", "Data/../../elsewhere", "/../elsewhere", "Data//../../elsewhere", "../dest.utm-sibling/x"] {
            XCTAssertThrowsError(try task.containedDestination(for: relative, in: root, isDirectory: false), relative)
        }
    }

    // MARK: Extraction

    func testOnlyThePackageIsExtracted() throws {
        // The package is listed before its resource-fork folder, as Finder writes it.
        let zip = try archive { builder in
            builder.addFile("README.txt", contents: "ignored")
            builder.addDirectory("Test.utm/")
            builder.addFile("Test.utm/config.plist", contents: "plist")
            builder.addDirectory("Test.utm/Data/")
            builder.addFile("Test.utm/Data/disk.qcow2", contents: "disk")
            builder.addDirectory("__MACOSX/Test.utm/")
            builder.addFile("__MACOSX/Test.utm/._config.plist", contents: "resource fork")
        }
        let package = try extract(zip)
        XCTAssertEqual(package.lastPathComponent, "Test.utm")
        XCTAssertEqual(try contents(of: package), ["Data", "config.plist"])
        XCTAssertEqual(try contents(of: package.appendingPathComponent("Data")), ["disk.qcow2"])
        XCTAssertEqual(try String(contentsOf: package.appendingPathComponent("config.plist")), "plist")
        XCTAssertEqual(try contents(of: folder), ["Test.utm", "download.zip"])
    }

    func testExistingPackageNameGetsASuffix() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Test.utm"), withIntermediateDirectories: false)
        let zip = try archive { builder in
            builder.addDirectory("Test.utm/")
            builder.addFile("Test.utm/config.plist", contents: "plist")
        }
        XCTAssertEqual(try extract(zip).lastPathComponent, "Test (2).utm")
    }

    func testArchiveWithoutPackageIsRejected() throws {
        let zip = try archive { builder in
            builder.addFile("Test/config.plist", contents: "plist")
        }
        XCTAssertThrowsError(try extract(zip))
        XCTAssertEqual(try contents(of: folder), ["download.zip"])
    }

    /// An entry that climbs out of the package must stop the import and leave nothing behind (ed73d11d).
    func testTraversalEntryAbortsExtractionAndCleansUp_ed73d11d() throws {
        let zip = try archive { builder in
            builder.addDirectory("Test.utm/")
            builder.addFile("Test.utm/config.plist", contents: "plist")
            builder.addFile("Test.utm/../escaped.txt", contents: "outside")
        }
        XCTAssertThrowsError(try extract(zip))
        XCTAssertEqual(try contents(of: folder), ["download.zip"], "the partial package and the escaped file are both gone")
    }

    /// A symbolic link, even one the archive library accepts because its target
    /// stays inside the package, can be re-pointed after import (34d48fec).
    func testSymlinkEntryAbortsExtractionAndCleansUp_34d48fec() throws {
        let zip = try archive { builder in
            builder.addDirectory("Test.utm/")
            builder.addFile("Test.utm/config.plist", contents: "plist")
            builder.addSymlink("Test.utm/Data", target: "config.plist")
        }
        XCTAssertThrowsError(try extract(zip))
        XCTAssertEqual(try contents(of: folder), ["download.zip"])
    }
}
