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

import Foundation

/// Writes small ZIP archives with stored (uncompressed) entries, so a test can
/// name entries exactly as a crafted download would: directories, symbolic links,
/// and paths that climb out of the package.
struct ZipArchiveBuilder {
    private struct Entry {
        let name: String
        let data: Data
        let mode: UInt32
    }

    private var entries: [Entry] = []

    mutating func addFile(_ name: String, contents: String) {
        entries.append(Entry(name: name, data: Data(contents.utf8), mode: 0o100644))
    }

    mutating func addDirectory(_ name: String) {
        entries.append(Entry(name: name.hasSuffix("/") ? name : name + "/", data: Data(), mode: 0o040755))
    }

    mutating func addSymlink(_ name: String, target: String) {
        entries.append(Entry(name: name, data: Data(target.utf8), mode: 0o120777))
    }

    func write(to url: URL) throws {
        var archive = Data()
        var central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = ZipArchiveBuilder.crc32(entry.data)
            let offset = UInt32(archive.count)
            // local file header
            archive.append(le32(0x04034b50)); archive.append(le16(20)); archive.append(le16(0)); archive.append(le16(0))
            archive.append(le16(0)); archive.append(le16(0)); archive.append(le32(crc))
            archive.append(le32(UInt32(entry.data.count))); archive.append(le32(UInt32(entry.data.count)))
            archive.append(le16(UInt16(name.count))); archive.append(le16(0)); archive.append(name); archive.append(entry.data)
            // central directory header, made by a Unix host so the mode carries the entry type
            central.append(le32(0x02014b50)); central.append(le16(0x031e)); central.append(le16(20)); central.append(le16(0)); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le32(crc))
            central.append(le32(UInt32(entry.data.count))); central.append(le32(UInt32(entry.data.count)))
            central.append(le16(UInt16(name.count))); central.append(le16(0)); central.append(le16(0)); central.append(le16(0)); central.append(le16(0))
            central.append(le32(entry.mode << 16)); central.append(le32(offset)); central.append(name)
        }
        let centralOffset = UInt32(archive.count)
        archive.append(central)
        // end of central directory
        archive.append(le32(0x06054b50)); archive.append(le16(0)); archive.append(le16(0))
        archive.append(le16(UInt16(entries.count))); archive.append(le16(UInt16(entries.count)))
        archive.append(le32(UInt32(central.count))); archive.append(le32(centralOffset)); archive.append(le16(0))
        try archive.write(to: url)
    }

    private func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
