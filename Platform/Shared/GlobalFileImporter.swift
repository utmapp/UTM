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
import UniformTypeIdentifiers

/// Workaround a SwiftUI bug on iOS which prevents .fileImporter() from
/// working when multiple are declared in a single view.
///
/// Need to set an EnvironmentObject to an instance of GlobalFileImporterShim
/// and then add a .fileImporter() on its instance variables.
class GlobalFileImporterShim: ObservableObject {
    @Published var isPresented: Bool = false
    
    @Published var allowedContentTypes: [UTType] = []
    
    @Published var onCompletion: (Result<URL, Error>) -> Void = { _ in }
}

struct GlobalFileImporterViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let onCompletion: (Result<URL, Error>) -> Void
    #if os(iOS)
    @EnvironmentObject private var globalFileImporterShim: GlobalFileImporterShim
    #endif
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onChange(of: isPresented) { newValue in
                if newValue {
                    globalFileImporterShim.allowedContentTypes = allowedContentTypes
                    globalFileImporterShim.onCompletion = onCompletion
                    globalFileImporterShim.isPresented = newValue
                }
            }
            .onChange(of: globalFileImporterShim.isPresented) { newValue in
                if !newValue {
                    isPresented = newValue
                }
            }
        #else
        content.fileImporter(isPresented: $isPresented, allowedContentTypes: allowedContentTypes, onCompletion: onCompletion)
        #endif
    }
}

extension View {
    func globalFileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (_ result: Result<URL, Error>) -> Void) -> some View {
        self.modifier(GlobalFileImporterViewModifier(isPresented: isPresented, allowedContentTypes: allowedContentTypes, onCompletion: onCompletion))
    }
}
