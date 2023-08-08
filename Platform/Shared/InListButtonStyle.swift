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

struct InListButtonStyle: ButtonStyle {
    fileprivate struct InListButtonView: View {
        let configuration: InListButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled: Bool
        #if os(macOS)
        let defaultColor = Color(NSColor.controlColor)
        let pressedColor = Color(NSColor.controlAccentColor)
        let foregroundColor = Color(NSColor.controlTextColor)
        let foregroundDisabledColor = Color(NSColor.disabledControlTextColor)
        let foregroundPressedColor = Color(NSColor.selectedControlTextColor)
        #else
        let defaultColor = Color(UIColor.systemBackground)
        let pressedColor = Color(UIColor.systemFill)
        let foregroundColor = Color(UIColor.label)
        let foregroundDisabledColor = Color(UIColor.systemGray)
        let foregroundPressedColor = Color(UIColor.secondaryLabel)
        #endif
        
        var body: some View {
            #if os(macOS)
            ZStack {
                RoundedRectangle(cornerRadius: 10.0)
                    .fill(configuration.isPressed ? pressedColor : defaultColor)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .shadow(color: .gray, radius: 1, x: 0, y: 0)
                    .padding(5)
                configuration.label
                    .foregroundColor(isEnabled ? (configuration.isPressed ? foregroundPressedColor : foregroundColor) : foregroundDisabledColor)
            }
            
            
            #else
            HStack {
                configuration.label
                Spacer()
            }
            .foregroundColor(isEnabled ? (configuration.isPressed ? foregroundPressedColor : foregroundColor) : foregroundDisabledColor)
            .contentShape(RoundedRectangle(cornerRadius: 10.0))
            .listRowBackground(configuration.isPressed ? pressedColor : defaultColor)
            .hoverEffect()
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            #endif
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        InListButtonView(configuration: configuration)
    }
}

extension ButtonStyle where Self == InListButtonStyle {
    static var inList: InListButtonStyle {
        InListButtonStyle()
    }
}
