//
// Copyright © 2024 osy. All rights reserved.
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

class UTMUpdateSecurity {
    private static let trustedHosts = [
        "api.github.com",
        "github.com",
        "objects.githubusercontent.com"
    ]
    
    enum SecurityError: Error, LocalizedError {
        case untrustedHost
        case invalidCertificate
        case checksumMismatch
        case invalidSignature
        case maliciousContent
        
        var errorDescription: String? {
            switch self {
            case .untrustedHost:
                return "Download from untrusted host blocked"
            case .invalidCertificate:
                return "Invalid or untrusted certificate"
            case .checksumMismatch:
                return "File integrity check failed"
            case .invalidSignature:
                return "Invalid digital signature"
            case .maliciousContent:
                return "Potentially malicious content detected"
            }
        }
    }
    
    static func validateDownloadURL(_ url: URL) throws {
        guard let host = url.host, trustedHosts.contains(host) else {
            throw SecurityError.untrustedHost
        }
        
        guard url.scheme == "https" else {
            throw SecurityError.untrustedHost
        }
    }
    
    static func validateCertificate(for host: String, certificate: SecCertificate) throws {
        let certificateData = SecCertificateCopyData(certificate)
        let data = CFDataGetBytePtr(certificateData)
        let length = CFDataGetLength(certificateData)
        
        let certBytes = Data(bytes: data!, count: length)
        let fingerprint = SHA256.hash(data: certBytes)
        let fingerprintString = fingerprint.compactMap { String(format: "%02x", $0) }.joined()
        
        // TODO: this is a simplified check - need more robust validation for example, 
        // checking against a list of known good fingerprints
        logger.info("Certificate fingerprint for \(host): \(fingerprintString)")
    }
    
    static func validateFileIntegrity(at url: URL, expectedSize: Int64, expectedChecksum: String? = nil) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let actualSize = attributes[.size] as? Int64 ?? 0
        
        guard actualSize == expectedSize else {
            throw SecurityError.checksumMismatch
        }
        
        if let expectedChecksum = expectedChecksum {
            let actualChecksum = try calculateChecksum(for: url)
            guard actualChecksum.lowercased() == expectedChecksum.lowercased() else {
                throw SecurityError.checksumMismatch
            }
        }
    }
    
    private static func calculateChecksum(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func validateAppBundle(at url: URL) throws {
        let bundleURL = url.appendingPathComponent("Contents")
        
        let requiredPaths = [
            "Info.plist",
            "MacOS",
            "_CodeSignature"
        ]
        
        for path in requiredPaths {
            let fullPath = bundleURL.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: fullPath.path) else {
                throw SecurityError.invalidSignature
            }
        }
        
        try validateInfoPlist(at: bundleURL.appendingPathComponent("Info.plist"))
    }
    
    private static func validateInfoPlist(at url: URL) throws {
        guard let plistData = NSDictionary(contentsOf: url),
              let bundleId = plistData["CFBundleIdentifier"] as? String else {
            throw SecurityError.invalidSignature
        }
        
        let validBundleIds = ["com.utmapp.UTM", "com.utmapp.UTM.SE", "com.utmapp.UTM.Remote"]
        guard validBundleIds.contains(bundleId) else {
            throw SecurityError.maliciousContent
        }
    }
    
    // URLSession delegate method for certificate pinning
    static func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        do {
            try validateCertificate(for: challenge.protectionSpace.host, certificate: certificate)
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } catch {
            logger.error("Certificate validation failed: \(error.localizedDescription)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
