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
import OSLog

extension Logger {
    static let updateManager = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UpdateManager")
    static let updateDownload = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UpdateDownload")
    static let updateInstaller = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UpdateInstaller")
    static let updateSecurity = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UpdateSecurity")
}

class UTMUpdateErrorHandler {
    
    enum ErrorRecoveryAction {
        case retry
        case skipVersion
        case manualUpdate
        case reportBug
        case none
    }
    
    static func handleError(_ error: Error, context: String) -> ErrorRecoveryAction {
        Logger.updateManager.error("\(context): \(error.localizedDescription)")
        
        switch error {
        case let updateError as UTMUpdateManager.UpdateError:
            return handleUpdateError(updateError, context: context)
        case let urlError as URLError:
            return handleNetworkError(urlError, context: context)
        case let securityError as UTMUpdateSecurity.SecurityError:
            return handleSecurityError(securityError, context: context)
        default:
            Logger.updateManager.error("Unhandled error type: \(type(of: error))")
            return .reportBug
        }
    }
    
    private static func handleUpdateError(_ error: UTMUpdateManager.UpdateError, context: String) -> ErrorRecoveryAction {
        switch error {
        case .networkUnavailable:
            Logger.updateManager.info("Network unavailable, user can retry later")
            return .retry
            
        case .downloadFailed:
            Logger.updateManager.warning("Download failed, user can retry or skip")
            return .retry
            
        case .verificationFailed:
            Logger.updateManager.error("Security verification failed - potential security issue")
            return .reportBug
            
        case .installationFailed:
            Logger.updateManager.error("Installation failed, suggest manual update")
            return .manualUpdate
            
        case .insufficientSpace:
            Logger.updateManager.warning("Insufficient disk space")
            return .none
            
        case .unsupportedVersion:
            Logger.updateManager.info("Update requires newer system version")
            return .skipVersion
            
        case .invalidResponse:
            Logger.updateManager.error("Invalid server response")
            return .retry
            
        case .noUpdateAvailable:
            Logger.updateManager.info("No update available")
            return .none
        }
    }
    
    private static func handleNetworkError(_ error: URLError, context: String) -> ErrorRecoveryAction {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            Logger.updateManager.info("Network connectivity issue")
            return .retry
            
        case .timedOut:
            Logger.updateManager.warning("Network timeout")
            return .retry
            
        case .cannotFindHost, .cannotConnectToHost:
            Logger.updateManager.error("Cannot reach update server")
            return .retry
            
        case .serverCertificateUntrusted, .clientCertificateRequired:
            Logger.updateManager.error("Certificate/security issue")
            return .reportBug
            
        default:
            Logger.updateManager.error("Network error: \(error.localizedDescription)")
            return .retry
        }
    }
    
    private static func handleSecurityError(_ error: UTMUpdateSecurity.SecurityError, context: String) -> ErrorRecoveryAction {
        switch error {
        case .untrustedHost, .invalidCertificate, .invalidSignature:
            Logger.updateSecurity.error("Security validation failed: \(error.localizedDescription)")
            return .reportBug
            
        case .checksumMismatch:
            Logger.updateSecurity.error("File integrity check failed")
            return .retry
            
        case .maliciousContent:
            Logger.updateSecurity.critical("Potential malicious content detected")
            return .reportBug
        }
    }
    
    static func createUserFriendlyMessage(for error: Error, recoveryAction: ErrorRecoveryAction) -> (title: String, message: String, buttonText: String) {
        switch recoveryAction {
        case .retry:
            return (
                title: "Update Failed",
                message: "The update could not be completed. This is usually a temporary issue with your network connection.",
                buttonText: "Try Again"
            )
            
        case .skipVersion:
            return (
                title: "Update Not Compatible",
                message: "This update requires a newer version of your operating system. You can skip this version and wait for the next update.",
                buttonText: "Skip Version"
            )
            
        case .manualUpdate:
            return (
                title: "Installation Failed",
                message: "The automatic installation failed. Please download and install the update manually from the UTM website.",
                buttonText: "Download Manually"
            )
            
        case .reportBug:
            return (
                title: "Update Error",
                message: "An unexpected error occurred. Please report this issue to help us improve UTM.",
                buttonText: "Report Issue"
            )
            
        case .none:
            return (
                title: "Update Issue",
                message: error.localizedDescription,
                buttonText: "OK"
            )
        }
    }
    
    static func logSystemInfo() {
        Logger.updateManager.info("System Info - OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        Logger.updateManager.info("System Info - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        Logger.updateManager.info("System Info - Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
        
        #if os(macOS)
        Logger.updateManager.info("System Info - Architecture: \(ProcessInfo.processInfo.processorCount) cores")
        #endif
        
        // Log available disk space
        #if os(macOS)
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        #else
        let homeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #endif
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: homeURL.path)
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let freeGB = freeSize.doubleValue / (1024 * 1024 * 1024)
                Logger.updateManager.info("System Info - Free Space: \(String(format: "%.2f", freeGB)) GB")
            }
        } catch {
            Logger.updateManager.warning("Could not determine free space: \(error.localizedDescription)")
        }
    }
}
