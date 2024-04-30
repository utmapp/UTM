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

struct BusyIndicator: View {
    @Binding var progress: Float?

    init(progress: Binding<Float?> = .constant(nil)) {
        _progress = progress
    }

    var body: some View {
        progressView
            .frame(width: 100, height: 100, alignment: .center)
            .foregroundColor(.white)
            .background(Color.gray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
    }

    #if os(macOS)
    @ViewBuilder
    private var progressView: some View {
        if let progress = progress {
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .controlSize(.large)
        } else {
            Spinner(size: .large)
        }
    }
    #else
    // TODO: implement progress spinner for iOS
    @ViewBuilder
    private var progressView: some View {
        Spinner(size: .large)
    }
    #endif
}

struct BusyIndicator_Previews: PreviewProvider {
    static var previews: some View {
        BusyIndicator()
    }
}
