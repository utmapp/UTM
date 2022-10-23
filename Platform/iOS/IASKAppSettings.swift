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

struct IASKAppSettings: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> IASKAppSettingsViewController {
        return IASKAppSettingsViewController()
    }
    
    func updateUIViewController(_ uiViewController: IASKAppSettingsViewController, context: Context) {
        uiViewController.neverShowPrivacySettings = !context.environment.showPrivacyLink
        uiViewController.showCreditsFooter = false
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
