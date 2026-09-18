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
import DiskImageKit
import Virtualization

/// Creates, inspects and resizes disk images for Apple Virtualization drives (ASIF and RAW).
///
/// On macOS 27 and later this uses DiskImageKit. On older hosts it falls back to the private
/// DiskImages2 framework through `UTMASIFImage`. Once the minimum supported host is macOS 27,
/// delete the legacy extension at the bottom of this file along with `UTMASIFImage.h/.m` and
/// its entry in `Swift-Bridging-Header.h`.
enum UTMAppleDiskImage {
    enum Format: Equatable {
        case asif
        case raw
        case layered
        case other(String)

        var localizedDescription: String {
            switch self {
            case .asif: return NSLocalizedString("ASIF", comment: "UTMAppleDiskImage")
            case .raw: return NSLocalizedString("RAW", comment: "UTMAppleDiskImage")
            case .layered: return NSLocalizedString("Layered", comment: "UTMAppleDiskImage")
            case .other(let name): return name
            }
        }
    }

    struct Info {
        let format: Format
        /// Size of the virtual disk in bytes
        let size: Int64
    }

    private static let bytesInMib = 1048576
    /// Block size used when creating images, matches the legacy DiskImages2 path
    private static let blockSize = 512

    /// True if ASIF images can be created on this host
    static var isASIFSupported: Bool {
        if #available(macOS 27, *) {
            return true
        } else if #available(macOS 26, *) {
            return UTMASIFImage.sharedInstance() != nil
        } else {
            return false
        }
    }

    /// Create a new blank ASIF image
    /// - Parameters:
    ///   - url: Location of the new image, must not exist
    ///   - sizeMib: Size of the virtual disk in MiB
    @available(macOS 13, *)
    static func createASIF(at url: URL, sizeMib: Int) throws {
        let blockCount = sizeMib * bytesInMib / blockSize
        if #available(macOS 27, *) {
            _ = try DiskImageKit.DiskImage(creating: .asif(url: url, blockCount: blockCount, blockSize: .bytes512))
        } else {
            try legacyCreateASIF(at: url, blockCount: blockCount)
        }
    }

    /// Read the format and size of an existing image
    /// - Parameter url: Location of the image
    @available(macOS 14, *)
    static func info(for url: URL) throws -> Info {
        if #available(macOS 27, *) {
            let image = try DiskImageKit.DiskImage(opening: .open(url: url, mode: .readOnly))
            let format: Format
            switch image.format {
            case .asif: format = .asif
            case .raw: format = .raw
            case .stack: format = .layered
            @unknown default: format = .other(String(describing: image.format))
            }
            return Info(format: format, size: Int64(image.size))
        } else {
            return try legacyInfo(for: url)
        }
    }

    /// Change the size of the virtual disk of an existing image
    /// - Parameters:
    ///   - url: Location of the image
    ///   - sizeMib: New size of the virtual disk in MiB
    @available(macOS 14, *)
    static func resize(_ url: URL, toSizeMib sizeMib: Int) throws {
        if #available(macOS 27, *) {
            let image = try DiskImageKit.DiskImage(opening: .open(url: url, mode: .readWrite))
            try image.truncate(blockCount: sizeMib * bytesInMib / image.blockSize.rawValue)
        } else {
            try legacyResize(url, toSizeMib: sizeMib)
        }
    }
}

// MARK: - Layered images (macOS 27+)

@available(macOS 27, *)
extension UTMAppleDiskImage {
    /// Create an attachment whose guest writes land in a new copy-on-write layer
    ///
    /// The image at `url` is opened read-only and is never modified. Any existing file at `overlayURL` is replaced.
    /// - Parameters:
    ///   - url: Location of the base image
    ///   - overlayURL: Location of the overlay layer to create
    ///   - cachingMode: Caching mode of the attachment
    ///   - synchronizationMode: Synchronization mode of the attachment
    static func attachment(for url: URL, ephemeralOverlayAt overlayURL: URL, cachingMode: VZDiskImageCachingMode = .automatic, synchronizationMode: VZDiskImageSynchronizationMode = .full) throws -> VZDiskImageStorageDeviceAttachment {
        try? FileManager.default.removeItem(at: overlayURL)
        let base = try DiskImageKit.DiskImage(opening: .open(url: url, mode: .readOnly))
        let stack = try base.appending(ASIFCreationConfiguration.layer(url: overlayURL, type: .overlay))
        return try VZDiskImageStorageDeviceAttachment(diskImage: stack, cachingMode: cachingMode, synchronizationMode: synchronizationMode)
    }
}

// MARK: - Legacy DiskImages2 (macOS 13 to 26)

/// Remove this extension together with `UTMASIFImage` when the minimum host is macOS 27.
private extension UTMAppleDiskImage {
    @available(macOS 13, *)
    static func legacyCreateASIF(at url: URL, blockCount: Int) throws {
        guard let asif = UTMASIFImage.sharedInstance() else {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        try asif.createBlank(with: url, numBlocks: blockCount)
    }

    @available(macOS 14, *)
    static func legacyInfo(for url: URL) throws -> Info {
        guard let asif = UTMASIFImage.sharedInstance() else {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        let info = try asif.retrieveInfo(url)
        guard let sizeInfo = info["Size Info"] as? [String: Any], let totalBytes = sizeInfo["Total Bytes"] as? Int64 else {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        let format: Format
        switch info["Image Format"] as? String {
        case "ASIF": format = .asif
        case "RAW", "RAW*": format = .raw
        case .some(let name): format = .other(name)
        case .none: format = .other(NSLocalizedString("Unknown", comment: "UTMAppleDiskImage"))
        }
        return Info(format: format, size: totalBytes)
    }

    @available(macOS 14, *)
    static func legacyResize(_ url: URL, toSizeMib sizeMib: Int) throws {
        guard let asif = UTMASIFImage.sharedInstance() else {
            throw UTMAppleConfigurationError.featureNotSupported
        }
        try asif.resize(with: url, size: sizeMib * bytesInMib)
    }
}
