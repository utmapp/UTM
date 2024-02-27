//
// Copyright © 2023 osy. All rights reserved.
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
import Security
import CryptoKit
#if os(macOS)
import SystemConfiguration
#endif

class UTMRemoteKeyManager {
    let isClient: Bool
    private(set) var isLoaded: Bool = false
    private(set) var identity: SecIdentity!
    private(set) var fingerprint: [UInt8]?

    init(forClient client: Bool) {
        self.isClient = client
    }

    private var certificateCommonNamePrefix: String {
        "UTM Remote \(isClient ? "Client" : "Server")"
    }

    private lazy var certificateCommonName: String = {
        #if os(macOS)
        let deviceName = SCDynamicStoreCopyComputerName(nil, nil) as? String ?? "macOS"
        #else
        let deviceName = UIDevice.current.name
        #endif
        return "\(certificateCommonNamePrefix) (\(deviceName))"
    }()

    private func generateKey() throws -> SecIdentity {
        let commonName = certificateCommonName as CFString
        let organizationName = "UTM" as CFString
        let serialNumber = Int.random(in: 1..<CLong.max) as CFNumber
        let days = 3650 as CFNumber
        guard let data = GenerateRSACertificate(commonName, organizationName, serialNumber, days, isClient as CFBoolean)?.takeUnretainedValue() as? [CFData] else {
            throw UTMRemoteKeyManagerError.generateKeyFailure
        }
        let importOptions = [ kSecImportExportPassphrase as String: "password" ] as CFDictionary
        var rawItems: CFArray?
        try withSecurityThrow(SecPKCS12Import(data[0], importOptions, &rawItems))
        guard let items = (rawItems! as! [[String: Any]]).first else {
            throw UTMRemoteKeyManagerError.parseKeyFailure
        }
        return items[kSecImportItemIdentity as String] as! SecIdentity
    }

    private func importIdentity(_ identity: SecIdentity) throws {
        let attributes = [
            kSecValueRef as String: identity,
        ] as CFDictionary
        try withSecurityThrow(SecItemAdd(attributes, nil))
    }

    private func loadIdentity() throws -> SecIdentity? {
        var query = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecMatchPolicy as String: SecPolicyCreateSSL(!isClient, nil),
        ] as [String : Any]
        #if os(macOS)
        query[kSecMatchSubjectStartsWith as String] = certificateCommonNamePrefix
        #endif
        var copyResult: AnyObject? = nil
        let result = SecItemCopyMatching(query as CFDictionary, &copyResult)
        if result == errSecItemNotFound {
            return nil
        }
        try withSecurityThrow(result)
        return (copyResult as! SecIdentity)
    }

    private func deleteIdentity(_ identity: SecIdentity) throws {
        let query = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchItemList as String: [identity],
        ] as CFDictionary
        try withSecurityThrow(SecItemDelete(query))
    }

    private func withSecurityThrow(_ block: @autoclosure () -> OSStatus) throws {
        let err = block()
        if err != errSecSuccess && err != errSecDuplicateItem {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
        }
    }
}

extension UTMRemoteKeyManager {
    func load() async throws {
        guard !isLoaded else {
            return
        }
        let identity = try await Task.detached { [self] in
            if let identity = try loadIdentity() {
                return identity
            } else {
                let identity = try generateKey()
                try importIdentity(identity)
                return identity
            }
        }.value
        var certificate: SecCertificate?
        try withSecurityThrow(SecIdentityCopyCertificate(identity, &certificate))
        self.identity = identity
        self.fingerprint = certificate!.fingerprint()
        self.isLoaded = true
    }

    func reset() async throws {
        try await Task.detached { [self] in
            if let identity = try loadIdentity() {
                try deleteIdentity(identity)
            }
        }.value
        if isLoaded {
            isLoaded = false
            try await load()
        }
    }
}

extension SecCertificate {
    func fingerprint() -> [UInt8] {
        let data = SecCertificateCopyData(self)
        return SHA256.hash(data: data as Data).map({ $0 })
    }
}

extension Array where Element == UInt8 {
    func hexString() -> String {
        self.map({ String(format: "%02X", $0) }).joined(separator: ":")
    }

    init?(hexString: String) {
        let cleanString = hexString.replacingOccurrences(of: ":", with: "")
        guard cleanString.count % 2 == 0 else {
            return nil
        }

        var byteArray = [UInt8]()
        var index = cleanString.startIndex

        while index < cleanString.endIndex {
            let nextIndex = cleanString.index(index, offsetBy: 2)
            if let byte = UInt8(cleanString[index..<nextIndex], radix: 16) {
                byteArray.append(byte)
            } else {
                return nil // Invalid hex character
            }
            index = nextIndex
        }
        self = byteArray
    }

    static func ^(lhs: Self, rhs: Self) -> Self {
        let length = Swift.min(lhs.count, rhs.count)
        return (0..<length).map({ lhs[$0] ^ rhs[$0] })
    }
}

enum UTMRemoteKeyManagerError: Error {
    case generateKeyFailure
    case parseKeyFailure
    case importKeyFailure
}

extension UTMRemoteKeyManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .generateKeyFailure:
            return NSLocalizedString("Failed to generate a key pair.", comment: "UTMRemoteKeyManager")
        case .parseKeyFailure:
            return NSLocalizedString("Failed to parse generated key pair.", comment: "UTMRemoteKeyManager")
        case .importKeyFailure:
            return NSLocalizedString("Failed to import generated key.", comment: "UTMRemoteKeyManager")
        }
    }
}
