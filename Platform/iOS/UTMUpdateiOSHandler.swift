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

#if os(iOS)
import UIKit
import StoreKit

class UTMUpdateiOSHandler {
    
    enum iOSUpdateMethod {
        case appStore
        case sideloaded
    }
    
    static func detectInstallationMethod() -> iOSUpdateMethod {
        // Check if app was installed from App Store
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path) {
            return .appStore
        }
        
        // Default to sideloaded
        return .sideloaded
    }
    
    static func handleiOSUpdate(method: iOSUpdateMethod, updateInfo: UTMUpdateManager.UpdateInfo) async throws {
        switch method {
        case .appStore:
            try await handleAppStoreUpdate()
        case .sideloaded:
            try await handleSideloadedUpdate(updateInfo: updateInfo)
        }
    }
    
    private static func handleAppStoreUpdate() async throws {
        // For App Store versions, redirect to App Store for update
        if let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id1538878817") {
            if await UIApplication.shared.canOpenURL(appStoreURL) {
                await UIApplication.shared.open(appStoreURL)
            }
        }
        
        // Also show in-app App Store review controller if available
        if #available(iOS 14.0, *) {
            if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
                await SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    private static func handleSideloadedUpdate(updateInfo: UTMUpdateManager.UpdateInfo) async throws {
        // For sideloaded apps, provide instructions for manual update
        let alertController = await UIAlertController(
            title: NSLocalizedString("Update Available", comment: "UTMUpdateiOSHandler"),
            message: String.localizedStringWithFormat(NSLocalizedString("A new version of UTM (%@) is available. Since you're using a sideloaded version, please update manually using your preferred sideloading method.", comment: "UTMUpdateiOSHandler"), updateInfo.version),
            preferredStyle: .alert
        )
        
        // Add action to open GitHub releases page
        await alertController.addAction(UIAlertAction(title: NSLocalizedString("View Release", comment: "UTMUpdateiOSHandler"), style: .default) { _ in
            Task {
                if let url = URL(string: "https://github.com/utmapp/UTM/releases/latest") {
                    await UIApplication.shared.open(url)
                }
            }
        })
        
        // Add action to copy IPA download URL
        if let ipaAsset = updateInfo.assets.first(where: { $0.name.hasSuffix(".ipa") }) {
            await alertController.addAction(UIAlertAction(title: NSLocalizedString("Copy IPA URL", comment: "UTMUpdateiOSHandler"), style: .default) { _ in
                UIPasteboard.general.string = ipaAsset.downloadURL.absoluteString
            })
        }
        
        await alertController.addAction(UIAlertAction(title: NSLocalizedString("Later", comment: "UTMUpdateiOSHandler"), style: .cancel))
        
        // Present the alert
        if let topViewController = getTopViewController() {
            await topViewController.present(alertController, animated: true)
        }
    }
    
    private static func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topViewController = window.rootViewController
        while let presented = topViewController?.presentedViewController {
            topViewController = presented
        }
        
        return topViewController
    }
    
    static func shouldShowUpdatePrompt(for method: iOSUpdateMethod) -> Bool {
        switch method {
        case .appStore:
            // Don't show custom update prompts for App Store versions
            // Let iOS handle App Store updates
            return false
        case .sideloaded:
            // Show custom update prompts for sideloaded versions
            return true
        }
    }
    
    static func getUpdateInstructions(for method: iOSUpdateMethod) -> String {
        switch method {
        case .appStore:
            return "Updates will be delivered through the App Store automatically."
        case .sideloaded:
            return "To update your sideloaded version:\n\n1. Download the new IPA from GitHub\n2. Install using your preferred sideloading method (AltStore, Sideloadly, etc.)\n3. The new version will replace the current installation"
        }
    }
}

#endif
