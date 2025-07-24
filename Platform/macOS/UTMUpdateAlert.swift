//
// Copyright © 2025 osy. All rights reserved.
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

struct UTMUpdateAlert: View {
    @StateObject private var updateChecker = UTMUpdateChecker()
    
    var body: some View {
        EmptyView()
            .onAppear {
                Task {
                    await updateChecker.checkForUpdates()
                }
            }
            .alert(isPresented: $updateChecker.isUpdateAvailable) {
                Alert(
                    title: Text("Update Available"),
                    message: Text("Version \(updateChecker.latestVersion ?? "") is now available"),
                    primaryButton: .default(Text("Download")) {
                        if let url = updateChecker.updateURL {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("Later"))
                )
            }
    }
}
