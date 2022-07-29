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

struct VMExternalWindowView: View {
    @State private var session: VMSessionState?
    
    private let vmSessionCreatedNotification = NotificationCenter.default.publisher(for: .vmSessionCreated)
    private let vmSessionEndedNotification = NotificationCenter.default.publisher(for: .vmSessionEnded)
    
    var body: some View {
        ZStack {
            if let session = session {
                VMWindowView(isInteractive: false).environmentObject(session)
            } else {
                VStack {
                    Text("Waiting for VM to connect to display...")
                        .font(.headline)
                    BusyIndicator()
                }
            }
        }
        .onAppear {
            session = VMSessionState.currentSession
        }
        .onReceive(vmSessionCreatedNotification) { output in
            let newSession = output.userInfo!["Session"] as! VMSessionState
            session = newSession
        }
        .onReceive(vmSessionEndedNotification) { output in
            let endedSession = output.userInfo!["Session"] as! VMSessionState
            if endedSession == session {
                session = nil
            }
        }
    }
}

struct VMExternalWindowView_Previews: PreviewProvider {
    static var previews: some View {
        VMExternalWindowView()
    }
}
