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

import SwiftUI

struct RemoteContentView: View {
    @ObservedObject var remoteClientState: UTMRemoteClient.State
    @EnvironmentObject private var data: UTMRemoteData

    var body: some View {
        if remoteClientState.isConnected {
            ContentView()
                .environmentObject(data as UTMData)
        } else {
            UTMRemoteConnectView(remoteClientState: remoteClientState)
                .transition(.move(edge: .leading))
        }
    }
}
