//
// Copyright © 2022 osy. All rights reserved.
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
import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
/// Represent a shared directory. This is no longer saved to config.plist in latest versions.
struct UTMAppleConfigurationSharedDirectory: Codable, Hashable, Identifiable {
    var directoryURL: URL?
    var isReadOnly: Bool
    
    let id = UUID()
    
    private enum CodingKeys: String, CodingKey {
        case bookmark = "Bookmark"
        case isReadOnly = "ReadOnly"
    }
    
    init(directoryURL: URL, isReadOnly: Bool = false) {
        self.directoryURL = directoryURL
        self.isReadOnly = isReadOnly
    }
    
    @available(macOS 12, *)
    init(from config: VZSharedDirectory) {
        self.isReadOnly = config.isReadOnly
        self.directoryURL = config.url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
        let bookmark = try container.decode(Data.self, forKey: .bookmark)
        var stale: Bool = false
        directoryURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isReadOnly, forKey: .isReadOnly)
        var options = NSURL.BookmarkCreationOptions.withSecurityScope
        if isReadOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        _ = directoryURL?.startAccessingSecurityScopedResource()
        defer {
            directoryURL?.stopAccessingSecurityScopedResource()
        }
        let bookmark = try directoryURL?.bookmarkData(options: options)
        try container.encodeIfPresent(bookmark, forKey: .bookmark)
    }
    
    @available(macOS 12, *)
    func vzSharedDirectory() -> VZSharedDirectory? {
        if let directoryURL = directoryURL {
            return VZSharedDirectory(url: directoryURL, readOnly: isReadOnly)
        } else {
            return nil
        }
    }
    
    @available(macOS 12, *)
    static func makeDirectoryShare(from sharedDirectories: [UTMAppleConfigurationSharedDirectory]) -> VZDirectoryShare {
        let vzSharedDirectories = sharedDirectories.compactMap { sharedDirectory in
            sharedDirectory.vzSharedDirectory()
        }
        let directories = vzSharedDirectories.reduce(into: [String: VZSharedDirectory]()) { (dict, share) in
            let lastPathComponent = share.url.lastPathComponent
            var name = lastPathComponent
            var i = 2
            while dict.keys.contains(name) {
                name = "\(lastPathComponent) (\(i))"
                i += 1
            }
            dict[name] = share
        }
        return VZMultipleDirectoryShare(directories: directories)
    }
}

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationSharedDirectory {
    init(migrating oldShare: SharedDirectory) {
        directoryURL = oldShare.directoryURL
        isReadOnly = oldShare.isReadOnly
    }
}
