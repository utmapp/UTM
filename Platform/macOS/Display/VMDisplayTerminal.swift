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

import Combine
import SwiftTerm
import SwiftUI

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

/// Releases the terminal's renderer, retrying while GPU work is still in flight
@MainActor private func closeWhenIdle(_ terminalView: TerminalView) {
    guard !terminalView.updateUiClosed() else {
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        closeWhenIdle(terminalView)
    }
}

protocol VMDisplayTerminal {
    var vm: (any UTMVirtualMachine)! { get }
    var isOptionAsMetaKey: Bool { get }
    @MainActor func setupTerminal(_ terminalView: TerminalView, using config: UTMConfigurationTerminal, id: Int, for window: NSWindow)
    func resizeCommand(for terminal: TerminalView, using config: UTMConfigurationTerminal) -> String
    func sizeChanged(id: Int, newCols: Int, newRows: Int)
    func sendString(_ string: String)
    @MainActor func enableMetalRenderer(for terminalView: TerminalView)
    @MainActor func closeTerminal(_ terminalView: TerminalView)
    @MainActor func openLink(_ link: String)
}

extension VMDisplayTerminal {
    @MainActor func setupTerminal(_ terminalView: TerminalView, using config: UTMConfigurationTerminal, id: Int, for window: NSWindow) {
        let fontSize = config.fontSize
        let fontName = config.font.rawValue
        let windowConfig = vm.registryEntry.terminalSettings[id] ?? UTMRegistryEntry.Terminal()
        if fontName != "" {
            let orig = terminalView.font
            let new = NSFont(name: fontName, size: CGFloat(fontSize)) ?? orig
            terminalView.font = new
        } else {
            let orig = terminalView.font
            let new = NSFont(descriptor: orig.fontDescriptor, size: CGFloat(fontSize)) ?? orig
            terminalView.font = new
        }
        if let consoleTextColor = config.foregroundColor,
           let textColor = Color(hexString: consoleTextColor),
           let consoleBackgroundColor = config.backgroundColor,
           let backgroundColor = Color(hexString: consoleBackgroundColor) {
            terminalView.nativeForegroundColor = NSColor(textColor)
            terminalView.nativeBackgroundColor = NSColor(backgroundColor)
        }
        if terminalView.terminalDimensions != TerminalDimensions(cols: windowConfig.columns, rows: windowConfig.rows) {
            terminalView.resize(cols: windowConfig.columns, rows: windowConfig.rows)
        }
        terminalView.setCursorStyle(config.hasCursorBlink ? .blinkBlock : .steadyBlock)
        let size = window.frameRect(forContentRect: terminalView.getOptimalFrameSize()).size
        let frame = CGRect(origin: window.frame.origin, size: size)
        window.setFrame(frame, display: false, animate: true)
        terminalView.optionAsMetaKey = isOptionAsMetaKey
    }
    
    func resizeCommand(for terminalView: TerminalView, using config: UTMConfigurationTerminal) -> String {
        let cols = terminalView.terminalDimensions.cols
        let rows = terminalView.terminalDimensions.rows
        let template = config.resizeCommand ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(cols))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        return cmd
    }
    
    @MainActor func enableMetalRenderer(for terminalView: TerminalView) {
        do {
            try terminalView.setUseMetal(true)
        } catch {
            logger.debug("Metal terminal renderer unavailable, using CoreGraphics: \(error)")
        }
    }
    
    @MainActor func closeTerminal(_ terminalView: TerminalView) {
        closeWhenIdle(terminalView)
    }
    
    /// Only web links are opened so that guest output cannot open host files or apps
    @MainActor func openLink(_ link: String) {
        guard let url = URL(string: link), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    func sizeChanged(id: Int, newCols: Int, newRows: Int) {
        Task { @MainActor in
            let windowConfig = UTMRegistryEntry.Terminal(columns: newCols, rows: newRows)
            if let vm = vm {
                vm.registryEntry.terminalSettings[id] = windowConfig
            }
        }
    }
}
