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

import Foundation

/// Console mode settings.
@available(iOS 13, macOS 11, *)
class UTMConfigurationTerminal: Codable, Identifiable, ObservableObject {
    /// Terminal color scheme. Mutually exclusive with foreground/background colors.
    @Published var theme: QEMUTerminalTheme?
    
    /// Terminal foreground color if a theme is not used.
    @Published var foregroundColor: String? = "#ffffff"
    
    /// Terminal background color if a theme is not used.
    @Published var backgroundColor: String? = "#000000"
    
    /// Terminal text font.
    @Published var font: QEMUTerminalFont = .init(rawValue: "Menlo")
    
    /// Terminal text font size.
    @Published var fontSize: Int = 12
    
    /// Command to send when the console is resized.
    @Published var resizeCommand: String?
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case theme = "Theme"
        case foregroundColor = "ForegroundColor"
        case backgroundColor = "BackgroundColor"
        case font = "Font"
        case fontSize = "FontSize"
        case resizeCommand = "ResizeCommand"
    }
    
    init() {
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        theme = try values.decodeIfPresent(QEMUTerminalTheme.self, forKey: .theme)
        foregroundColor = try values.decodeIfPresent(String.self, forKey: .foregroundColor)
        backgroundColor = try values.decodeIfPresent(String.self, forKey: .backgroundColor)
        font = try values.decode(QEMUTerminalFont.self, forKey: .font)
        fontSize = try values.decode(Int.self, forKey: .fontSize)
        resizeCommand = try values.decodeIfPresent(String.self, forKey: .resizeCommand)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let theme = theme {
            try container.encode(theme, forKey: .theme)
        } else { // only save colors if no theme
            try container.encodeIfPresent(foregroundColor, forKey: .foregroundColor)
            try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        }
        try container.encode(font, forKey: .font)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(resizeCommand, forKey: .resizeCommand)
    }
}

// MARK: - Conversion of old config format

@available(iOS 13, macOS 11, *)
extension UTMConfigurationTerminal {
    convenience init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        foregroundColor = oldConfig.consoleTextColor
        backgroundColor = oldConfig.consoleBackgroundColor
        if let fontStr = oldConfig.consoleFont {
            font = QEMUTerminalFont(rawValue: fontStr)
        }
        if let fontSizeNum = oldConfig.consoleFontSize {
            fontSize = fontSizeNum.intValue
        }
        resizeCommand = oldConfig.consoleResizeCommand
    }
}
