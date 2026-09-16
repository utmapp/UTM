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

class UTMExternalSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var window: UIWindow?
    var screen: UIScreen?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        if session.role.isExternalDisplay {
            let window = UIWindow(windowScene: windowScene)
            let viewController = UIHostingController(rootView: UTMSingleWindowView())
            window.rootViewController = viewController
            self.window = window
            window.isHidden = false
            setupDisplayLinkIfNecessary()
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        setupDisplayLinkIfNecessary()
    }

    weak var linkedScreen: UIScreen?

    func setupDisplayLinkIfNecessary() {
        let currentScreen = self.screen
        if currentScreen != linkedScreen {
            // Set up display link
            self.linkedScreen = currentScreen
        }
    }
}

private extension UISceneSession.Role {
    /// The external display role was renamed in iOS 16 and sessions report the new name.
    var isExternalDisplay: Bool {
        if #available(iOS 16, *) {
            return self == .windowExternalDisplayNonInteractive
        } else {
            return self == .windowExternalDisplay
        }
    }
}

extension View {
    /// Offers `UTMSingleWindowView` as the content of a connected external display.
    ///
    /// Apps built with the iOS 27 SDK are no longer offered `windowExternalDisplayNonInteractive`
    /// scenes from the Info.plist scene manifest; the content must be registered as a scene
    /// accessory instead. Older systems keep using the Info.plist configuration and
    /// `UTMExternalSceneDelegate`.
    @ViewBuilder
    func externalDisplayAccessory() -> some View {
        if #available(iOS 27, *) {
            sceneAccessory {
                ExternalNonInteractiveAccessory {
                    UTMSingleWindowView()
                }
            }
        } else {
            self
        }
    }
}
