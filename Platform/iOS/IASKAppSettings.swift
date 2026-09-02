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

import SwiftUI
import InAppSettingsKit
import UIKit

class UTMSettingsDelegate: NSObject, IASKSettingsDelegate {
    
    override init() {
        super.init()
    }
    
    deinit {
    }
    
    func settingsViewControllerDidEnd(_ sender: IASKAppSettingsViewController) {
        // Settings view ended
    }
    
    func settingsViewController(_ sender: IASKAppSettingsViewController, buttonTappedFor specifier: IASKSpecifier) {
        if specifier.key == "CheckForUpdatesButton" {
            Task { @MainActor in
                do {
                    let installMethod = UTMUpdateiOSHandler.detectInstallationMethod()
                    guard UTMUpdateiOSHandler.shouldShowUpdatePrompt(for: installMethod) else {
                        let alert = UIAlertController(
                            title: "Updates",
                            message: "Updates for App Store installations are handled automatically by iOS.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        
                        sender.present(alert, animated: true)
                        return
                    }
                    
                    await UTMUpdateManager.shared.checkForUpdates(force: true)
                    
                    if let updateInfo = UTMUpdateManager.shared.updateInfo {
                        let alert = UIAlertController(
                            title: "Update Available",
                            message: "A new version of UTM (\(updateInfo.version)) is available. Since you're using a sideloaded version, please update manually using your preferred sideloading method.",
                            preferredStyle: .alert
                        )
                        
                        alert.addAction(UIAlertAction(title: "View Release", style: .default) { _ in
                            Task {
                                if let url = URL(string: "https://github.com/utmapp/UTM/releases/latest") {
                                    await UIApplication.shared.open(url)
                                }
                            }
                        })
                        
                        if let ipaAsset = updateInfo.assets.first(where: { $0.name.hasSuffix(".ipa") }) {
                            alert.addAction(UIAlertAction(title: "Copy IPA URL", style: .default) { _ in
                                UIPasteboard.general.string = ipaAsset.downloadURL.absoluteString
                            })
                        }
                        
                        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
                        
                        sender.present(alert, animated: true)
                    } else {
                        let alert = UIAlertController(
                            title: "No Updates",
                            message: "You are using the latest version of UTM.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        
                        sender.present(alert, animated: true)
                    }
                    
                }
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
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
}

struct IASKAppSettings: UIViewControllerRepresentable {
    private let delegate = UTMSettingsDelegate()
    
    func makeUIViewController(context: Context) -> IASKAppSettingsViewController {
        let controller = IASKAppSettingsViewController()
        controller.delegate = delegate
        return controller
    }
    
    func updateUIViewController(_ uiViewController: IASKAppSettingsViewController, context: Context) {
        uiViewController.neverShowPrivacySettings = !context.environment.showPrivacyLink
        uiViewController.showCreditsFooter = false
        uiViewController.delegate = delegate
    }
}

private struct AppSettingsShowPrivacyLinkKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var showPrivacyLink: Bool {
        get { self[AppSettingsShowPrivacyLinkKey.self] }
        set { self[AppSettingsShowPrivacyLinkKey.self] = newValue }
    }
}

extension View {
    func appSettingsShowPrivacyLink(_ showPrivacyLink: Bool) -> some View {
        environment(\.showPrivacyLink, showPrivacyLink)
    }
}

struct IASKAppSettings_Previews: PreviewProvider {
    static var previews: some View {
        IASKAppSettings()
    }
}
