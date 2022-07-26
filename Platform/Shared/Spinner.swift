//
// Copyright © 2021 osy. All rights reserved.
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

#if os(macOS)
@available(macOS 11, *)
struct Spinner: NSViewRepresentable {
    enum Size: RawRepresentable {
        case regular
        case large
        
        var rawValue: NSControl.ControlSize {
            switch self {
            case .regular: return .regular
            case .large: return .large
            }
        }
        
        init?(rawValue: NSControl.ControlSize) {
            switch rawValue {
            case .regular:
                self = .regular
            case .large:
                self = .large
            default:
                return nil
            }
        }
    }
    
    let size: Size
    
    func makeNSView(context: Context) -> NSProgressIndicator {
        let view = NSProgressIndicator()
        view.controlSize = size.rawValue
        view.style = .spinning
        view.startAnimation(self)
        return view
    }
    
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {
    }
}
#else // iOS
struct Spinner: UIViewRepresentable {
    enum Size: RawRepresentable {
        case regular
        case large
        
        var rawValue: UIActivityIndicatorView.Style {
            switch self {
            case .regular: return .medium
            case .large: return .large
            }
        }
        
        init?(rawValue: UIActivityIndicatorView.Style) {
            switch rawValue {
            case .medium:
                self = .regular
            case .large:
                self = .large
            default:
                return nil
            }
        }
    }
    
    let size: Size
    
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: size.rawValue)
        view.color = .white
        view.startAnimating()
        return view
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
    }
}
#endif

struct Spinner_Previews: PreviewProvider {
    static var previews: some View {
        Spinner(size: .large)
    }
}
