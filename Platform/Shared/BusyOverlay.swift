//
// Copyright © 2020 osy. All rights reserved.
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

struct BusyOverlay: View {
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Group {
            if data.busy {
                BusyIndicator(progress: $data.busyProgress)
            } else {
                EmptyView()
            }
        }
        .alert(item: $data.alertItem) { item in
            switch item {
            case .downloadUrl(let url):
                return Alert(title: Text("Download VM"), message: Text("Do you want to download '\(url)'?"), primaryButton: .cancel(), secondaryButton: .default(Text("Download")) {
                    data.downloadUTMZip(from: url)
                })
            case .message(let message):
                return Alert(title: Text(message))
            }
        }
    }
}

struct BusyOverlay_Previews: PreviewProvider {
    static var previews: some View {
        BusyOverlay()
    }
}
