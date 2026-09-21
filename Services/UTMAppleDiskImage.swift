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
    fileprivate static let layerFileExtension = "asif"
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

    /// Files beside an image that its snapshots stacked on it, found by name so that this works
    /// where the layers themselves cannot be read
    static func layerFileURLs(of imageURL: URL) -> [URL] {
        let prefix = imageURL.lastPathComponent + "."
        // an image outside of the bundle may be in a directory that cannot be read
        let siblings = (try? FileManager.default.contentsOfDirectory(at: imageURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        return siblings.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == layerFileExtension }
    }

    /// Change the size of the virtual disk of an existing image
    /// - Parameters:
    ///   - url: Location of the image
    ///   - sizeMib: New size of the virtual disk in MiB
    @available(macOS 14, *)
    static func resize(_ url: URL, toSizeMib sizeMib: Int) throws {
        // every layer stacked on the image was built on it as it is
        guard layerFileURLs(of: url).isEmpty else {
            throw UTMAppleDiskImageError.hasSnapshots
        }
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
    /// Copy-on-write layer stacked on the image of a drive.
    ///
    /// Layers are kept next to the image as `<image>.<name>.asif`. Each one only holds what was
    /// written while it was on top, so it depends on the layers below it.
    struct Layer: Equatable {
        /// Name of the layer that guest writes go to
        static let currentName = "current"

        fileprivate static let fileExtension = layerFileExtension
        fileprivate static let unlinkedMarker = "unlinked"

        let url: URL

        /// `currentName` or the snapshot the layer was frozen as
        let name: String

        /// Not a snapshot anymore but still below other layers
        let isUnlinked: Bool

        let uuid: UUID

        /// Layer right below this one, `nil` if that is the image itself
        let parentUUID: UUID?

        var isCurrent: Bool {
            name == Self.currentName
        }

        fileprivate static func url(for imageURL: URL, name: String, isUnlinked: Bool = false) -> URL {
            var url = imageURL.appendingPathExtension(name)
            if isUnlinked {
                url.appendPathExtension(unlinkedMarker)
            }
            return url.appendingPathExtension(fileExtension)
        }
    }

    /// Find the layers of an image.
    ///
    /// The current layer is left out while it cannot be opened because a VM is using it.
    static func layers(of imageURL: URL) throws -> [Layer] {
        let prefix = imageURL.lastPathComponent + "."
        let candidates = layerFileURLs(of: imageURL)
        guard !candidates.isEmpty else {
            // most images have no layers, leave them alone
            return []
        }
        let baseUUID = try DiskImageKit.DiskImage(opening: .open(url: imageURL, mode: .readOnly)).layerUUID
        return candidates.compactMap { url -> Layer? in
            var name = String(url.deletingPathExtension().lastPathComponent.dropFirst(prefix.count))
            let isUnlinked = name.hasSuffix("." + Layer.unlinkedMarker)
            if isUnlinked {
                name.removeLast(Layer.unlinkedMarker.count + 1)
            }
            guard !name.isEmpty, let image = try? DiskImageKit.DiskImage(opening: .open(url: url, mode: .readOnly)), let uuid = image.layerUUID else {
                return nil
            }
            // an image without an identifier cannot be told apart from no layer
            let parentUUID = image.parentUUID == baseUUID ? nil : image.parentUUID
            return Layer(url: url, name: name, isUnlinked: isUnlinked, uuid: uuid, parentUUID: parentUUID)
        }
    }

    /// Layers from the one right above the image up to `top`
    ///
    /// - Throws: `UTMAppleDiskImageError.layerMissing` when a layer below `top` cannot be read,
    ///   because opening the rest without it would hide everything that layer holds.
    private static func chain(endingAt top: Layer?, in layers: [Layer]) throws -> [Layer] {
        var chain = [Layer]()
        var next = top
        while let layer = next, !chain.contains(layer) {
            chain.insert(layer, at: 0)
            next = layers.first { $0.uuid == layer.parentUUID }
            guard next != nil || layer.parentUUID == nil else {
                throw UTMAppleDiskImageError.layerMissing
            }
        }
        return chain
    }

    /// Open an image along with some of its layers, all of them read-only unless `isTopWritable`.
    private static func open(_ imageURL: URL, chain: [Layer], isTopWritable: Bool = false) throws -> DiskImageKit.DiskImage {
        var image = try DiskImageKit.DiskImage(opening: .open(url: imageURL, mode: chain.isEmpty && isTopWritable ? .readWrite : .readOnly))
        for layer in chain {
            let isWritable = isTopWritable && layer == chain.last
            image = try image.appending(DiskImageKit.DiskImage(opening: .open(url: layer.url, mode: isWritable ? .readWrite : .readOnly)))
        }
        return image
    }

    /// Put a new layer on top of `chain` that guest writes go to from now on.
    private static func createCurrentLayer(of imageURL: URL, above chain: [Layer]) throws {
        let fileManager = FileManager.default
        let url = Layer.url(for: imageURL, name: Layer.currentName)
        // built under a name that is not taken for a layer, so the one it replaces stays until it exists
        let pendingURL = imageURL.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).\(Layer.fileExtension)")
        do {
            _ = try open(imageURL, chain: chain).appending(ASIFCreationConfiguration.layer(url: pendingURL, type: .overlay))
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: pendingURL)
            } else {
                try fileManager.moveItem(at: pendingURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: pendingURL)
            throw error
        }
    }

    /// Create an attachment for an image that has layers or that should not be modified.
    ///
    /// Any existing file at `overlayURL` is replaced.
    /// - Parameters:
    ///   - url: Location of the image
    ///   - includesLayers: Look for layers, which snapshots only stack on the images in the bundle
    ///   - overlayURL: If set, guest writes land in a new layer created here and nothing else is modified
    ///   - isReadOnly: The drive may not be written to, which a stack cannot be attached as
    ///   - cachingMode: Caching mode of the attachment
    ///   - synchronizationMode: Synchronization mode of the attachment
    /// - Returns: `nil` if the image has no layers and can be attached by itself
    static func attachment(for url: URL, includesLayers: Bool, ephemeralOverlayAt overlayURL: URL? = nil, isReadOnly: Bool = false, cachingMode: VZDiskImageCachingMode = .automatic, synchronizationMode: VZDiskImageSynchronizationMode = .full) throws -> VZDiskImageStorageDeviceAttachment? {
        let layers = includesLayers ? try layers(of: url) : []
        let current = layers.first { $0.isCurrent }
        // writing to the image itself is only safe while nothing is stacked on it, otherwise it
        // would change what every layer above it was built on
        guard current != nil || !includesLayers || layerFileURLs(of: url).isEmpty else {
            throw UTMAppleDiskImageError.layerMissing
        }
        let chain = try chain(endingAt: current, in: layers)
        if let overlayURL = overlayURL {
            try? FileManager.default.removeItem(at: overlayURL)
            let stack = try open(url, chain: chain).appending(ASIFCreationConfiguration.layer(url: overlayURL, type: .overlay))
            return try VZDiskImageStorageDeviceAttachment(diskImage: stack, cachingMode: cachingMode, synchronizationMode: synchronizationMode)
        } else if chain.isEmpty {
            return nil
        } else if isReadOnly {
            // the image alone is the drive as it was before the first snapshot
            throw UTMAppleDiskImageError.readOnlyWithSnapshots
        } else {
            return try VZDiskImageStorageDeviceAttachment(diskImage: try open(url, chain: chain, isTopWritable: true), cachingMode: cachingMode, synchronizationMode: synchronizationMode)
        }
    }

    /// Freeze what has been written to an image so far and direct further writes to a new layer.
    ///
    /// The image must not be in use.
    /// - Parameters:
    ///   - imageURL: Location of the image
    ///   - name: Name of the snapshot
    static func createSnapshot(of imageURL: URL, name: String) throws {
        let fileManager = FileManager.default
        let snapshotURL = Layer.url(for: imageURL, name: name)
        let current = try layers(of: imageURL).first(where: { $0.isCurrent })
        // once there are layers only the one being written to may be frozen, or they would be lost
        guard current != nil || layerFileURLs(of: imageURL).isEmpty else {
            throw UTMAppleDiskImageError.layerMissing
        }
        if let current = current {
            try fileManager.moveItem(at: current.url, to: snapshotURL)
            // the date of a snapshot is when its layer was frozen, not when the guest last wrote to it
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: snapshotURL.path)
        } else {
            // so far everything was written to the image itself
            _ = try open(imageURL, chain: []).appending(ASIFCreationConfiguration.layer(url: snapshotURL, type: .overlay))
        }
        do {
            let layers = try self.layers(of: imageURL)
            try createCurrentLayer(of: imageURL, above: try chain(endingAt: layers.first { $0.name == name }, in: layers))
        } catch {
            // without a layer to write to the drive could not be used anymore
            if let current = current {
                try? fileManager.moveItem(at: snapshotURL, to: current.url)
            } else {
                try? fileManager.removeItem(at: snapshotURL)
            }
            throw error
        }
    }

    /// Discard what was written to an image since a snapshot was created.
    ///
    /// The image must not be in use.
    static func restoreSnapshot(of imageURL: URL, name: String) throws {
        try createCurrentLayer(of: imageURL, above: try snapshotChain(of: imageURL, name: name))
        try removeUnusedLayers(of: imageURL)
    }

    /// Make sure that a snapshot can be restored, without changing anything.
    static func validateSnapshot(of imageURL: URL, name: String) throws {
        _ = try snapshotChain(of: imageURL, name: name)
    }

    private static func snapshotChain(of imageURL: URL, name: String) throws -> [Layer] {
        let layers = try layers(of: imageURL)
        guard let snapshot = layers.first(where: { $0.name == name && !$0.isUnlinked }) else {
            throw UTMAppleDiskImageError.snapshotNotFound(name)
        }
        return try chain(endingAt: snapshot, in: layers)
    }

    /// Delete a snapshot. Its layer stays for as long as there are layers above it.
    static func deleteSnapshot(of imageURL: URL, name: String) throws {
        guard let snapshot = try layers(of: imageURL).first(where: { $0.name == name && !$0.isUnlinked }) else {
            throw UTMAppleDiskImageError.snapshotNotFound(name)
        }
        try FileManager.default.moveItem(at: snapshot.url, to: Layer.url(for: imageURL, name: name, isUnlinked: true))
        try removeUnusedLayers(of: imageURL)
    }

    /// Delete the layers of deleted snapshots that no other layer needs anymore
    private static func removeUnusedLayers(of imageURL: URL) throws {
        var layers = try layers(of: imageURL)
        // the current layer is not found while it is in use so keep what may be below it
        guard layers.contains(where: { $0.isCurrent }) || layers.isEmpty else {
            return
        }
        while let unused = layers.first(where: { layer in layer.isUnlinked && !layers.contains { $0.parentUUID == layer.uuid } }) {
            try FileManager.default.removeItem(at: unused.url)
            layers.removeAll { $0 == unused }
        }
    }
}

enum UTMAppleDiskImageError: Error {
    case snapshotNotFound(String)
    case layerMissing
    case hasSnapshots
    case snapshotsRequireNewerOS
    case readOnlyWithSnapshots
}

extension UTMAppleDiskImageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .snapshotNotFound(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The disk image has no snapshot '%@'.", comment: "UTMAppleDiskImage"), name)
        case .layerMissing:
            return NSLocalizedString("The disk image is incomplete because some of its data could not be read.", comment: "UTMAppleDiskImage")
        case .hasSnapshots:
            return NSLocalizedString("A drive cannot be resized once a snapshot has been taken of it.", comment: "UTMAppleDiskImage")
        case .snapshotsRequireNewerOS:
            return NSLocalizedString("This drive holds snapshots and can only be used on macOS 27 or later.", comment: "UTMAppleDiskImage")
        case .readOnlyWithSnapshots:
            return NSLocalizedString("A drive cannot be read only once a snapshot has been taken of it.", comment: "UTMAppleDiskImage")
        }
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
