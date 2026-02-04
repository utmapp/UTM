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
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

class UTMInstaller {
    enum InstallationError: Error, LocalizedError {
        case notAuthorized
        case invalidBundle
        case installationFailed(String)
        case backupFailed
        case platformNotSupported
        case insufficientDiskSpace
        case mountFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return NSLocalizedString("Installation not authorized", comment: "UTMInstaller")
            case .invalidBundle:
                return NSLocalizedString("Invalid application bundle", comment: "UTMInstaller")
            case .installationFailed(let reason):
                return String.localizedStringWithFormat(NSLocalizedString("Installation failed: %@", comment: "UTMInstaller"), reason)
            case .backupFailed:
                return NSLocalizedString("Failed to create backup", comment: "UTMInstaller")
            case .platformNotSupported:
                return NSLocalizedString("Platform not supported for automatic updates", comment: "UTMInstaller")
            case .insufficientDiskSpace:
                return NSLocalizedString("Insufficient disk space for installation", comment: "UTMInstaller")
            case .mountFailed:
                return NSLocalizedString("Failed to mount DMG file", comment: "UTMInstaller")
            }
        }
    }
    
    func installUpdate(from downloadURL: URL) async throws {
        #if os(macOS)
        try await openDMGAndShowInstructions(from: downloadURL)
        #elseif os(iOS)
        try await installiOSUpdate(from: downloadURL)
        #else
        throw InstallationError.platformNotSupported
        #endif
    }
    
    #if os(macOS)
    private func openDMGAndShowInstructions(from downloadURL: URL) async throws {
        // Try to mount the DMG
        do {
            _ = try await mountDMG(downloadURL)
        } catch {
            NSWorkspace.shared.open(downloadURL)
        }
        
        // Show installation instructions to the user
        await showInstallationInstructions()
    }
    
    private func showInstallationInstructions() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Installation Instructions", comment: "UTMInstaller")
                alert.informativeText = NSLocalizedString("Please follow these steps to complete the update:\n\n1. Save any unsaved work in your virtual machines\n2. Quit UTM completely\n3. Drag the new UTM.app from the DMG to your Applications folder (replace the existing version)\n4. Restart UTM\n\nThe DMG file has been mounted and is ready for installation.", comment: "UTMInstaller")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "UTMInstaller"))
                alert.addButton(withTitle: NSLocalizedString("Quit UTM Now", comment: "UTMInstaller"))
                alert.alertStyle = .informational
                
                let response = alert.runModal()
                
                if response == .alertSecondButtonReturn {
                    // close any existing alerts and quit
                    DispatchQueue.main.async {
                        // Close all open modal windows/alerts
                        for window in NSApplication.shared.windows {
                            window.close()
                        }
                        
                        NSApplication.shared.terminate(nil)
                    }
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    private func mountDMG(_ dmgURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // macOS will mount automatically
                let success = NSWorkspace.shared.open(dmgURL)
                
                if success {
                    // wait a moment for the mount to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        let volumeName = dmgURL.deletingPathExtension().lastPathComponent
                        let possiblePaths = [
                            "/Volumes/\(volumeName)",
                            "/Volumes/UTM",
                            "/Volumes/UTM SE"
                        ]
                        
                        for path in possiblePaths {
                            if FileManager.default.fileExists(atPath: path) {
                                continuation.resume(returning: URL(fileURLWithPath: path))
                                return
                            }
                        }
                        
                        // if we can't find a specific volume, check all volumes
                        let volumesURL = URL(fileURLWithPath: "/Volumes")
                        if let contents = try? FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil) {
                            for volumeURL in contents {
                                let appURL = volumeURL.appendingPathComponent("UTM.app")
                                if FileManager.default.fileExists(atPath: appURL.path) {
                                    continuation.resume(returning: volumeURL)
                                    return
                                }
                            }
                        }
                        
                        continuation.resume(throwing: InstallationError.mountFailed)
                    }
                } else {
                    continuation.resume(throwing: InstallationError.mountFailed)
                }
            }
        }
    }
    
    #endif
    
    #if os(iOS)
    private func installiOSUpdate(from downloadURL: URL) async throws {
        // iOS automatic installation is limited due to App Store restrictions
        // Different approaches based on distribution method:
        
        if isAppStoreVersion() {
            // Redirect to App Store
            try await redirectToAppStore()
        } else if isTestFlightVersion() {
            // Show TestFlight update notification
            try await showTestFlightUpdate()
        } else {
            // Side-loaded version - guide user through re-installation
            try await guideSideloadedUpdate(from: downloadURL)
        }
    }
    
    private func isAppStoreVersion() -> Bool {
        // Check if app was installed from App Store
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }
    
    private func isTestFlightVersion() -> Bool {
        // Check for TestFlight installation
        return Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }
    
    private func redirectToAppStore() async throws {
        guard let appID = Bundle.main.infoDictionary?["UTMAppStoreID"] as? String,
              let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)") else {
            throw InstallationError.installationFailed(NSLocalizedString("Cannot construct App Store URL", comment: "UTMInstaller"))
        }
        
        await UIApplication.shared.open(url)
    }
    
    private func showTestFlightUpdate() async throws {
        guard let url = URL(string: "itms-beta://") else {
            throw InstallationError.installationFailed(NSLocalizedString("Cannot open TestFlight", comment: "UTMInstaller"))
        }
        
        await UIApplication.shared.open(url)
    }
    
    private func guideSideloadedUpdate(from downloadURL: URL) async throws {
        // For side-loaded apps, we can only guide the user through manual installation
        // This would typically involve showing instructions to re-sign and install the IPA
        throw InstallationError.platformNotSupported
    }
    #endif
}
