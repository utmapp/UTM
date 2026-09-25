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
import SwiftTerm
import SwiftUI

@objc class VMDisplayTerminalViewController: VMDisplayViewController {
    private var terminalView: TerminalView!
    var vmSerialPort: CSPort {
        willSet {
            vmSerialPort.delegate = nil
            newValue.delegate = self
            terminalView.resetToInitialState()
            terminalView.softReset()
        }
    }
    
    private var style: UTMConfigurationTerminal?
    
    required init(port: CSPort, style: UTMConfigurationTerminal? = nil) {
        self.vmSerialPort = port
        super.init(nibName: nil, bundle: nil)
        port.delegate = self
        self.style = style
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
    
    override func loadView() {
        super.loadView()
        terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = self
        view.insertSubview(terminalView, at: 0)
        styleTerminal()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutTerminal()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if !os(visionOS) // SwiftTerm's Metal renderer draws at the wrong scale on visionOS
        do {
            try terminalView.setUseMetal(true)
        } catch {
            logger.debug("Metal terminal renderer unavailable, using CoreGraphics: \(error)")
        }
        #endif
    }
    
    override func enterLive() {
        super.enterLive()
        DispatchQueue.main.async {
            let dimensions = self.terminalView.terminalDimensions
            let terminalSize = CGSize(width: dimensions.cols, height: dimensions.rows)
            self.delegate.displayViewSize = terminalSize
        }
    }
    
    override func showKeyboard() {
        super.showKeyboard()
        _ = terminalView.becomeFirstResponder()
    }
    
    override func hideKeyboard() {
        super.hideKeyboard()
        _ = terminalView.resignFirstResponder()
    }
    
    func closeTerminal() {
        if let terminalView = terminalView {
            Self.closeWhenIdle(terminalView)
        }
    }
    
    /// Releases the terminal's renderer, retrying while GPU work is still in flight
    private static func closeWhenIdle(_ terminalView: TerminalView) {
        guard !terminalView.updateUiClosed() else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            closeWhenIdle(terminalView)
        }
    }
}

// MARK: - Layout terminal
extension VMDisplayTerminalViewController {
    /// The safe area is not enough to keep the first line of text out of the rounded corners while
    /// the status bar is hidden, so the system's corner-adapted region is used where it exists.
    private var contentLayoutGuide: UILayoutGuide {
        if #available(iOS 26, visionOS 26, *) {
            return view.layoutGuide(for: .safeArea(cornerAdaptation: .vertical))
        } else {
            return view.safeAreaLayoutGuide
        }
    }

    private func layoutTerminal() {
        #if os(visionOS)
        let inputAccessoryHeight: CGFloat = 0
        #else
        let inputAccessoryHeight = terminalView.inputAccessoryView?.frame.height ?? 0
        #endif
        let guide = contentLayoutGuide
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: guide.topAnchor, constant: fallbackTopPadding),
            terminalView.leftAnchor.constraint(equalTo: guide.leftAnchor),
            terminalView.rightAnchor.constraint(equalTo: guide.rightAnchor),
            terminalView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -inputAccessoryHeight),
        ])
    }

    /// Before the corner-adapted region existed, an iPad kept the first line out of the rounded
    /// corners with the height of the bottom safe area, which the home indicator rounds alike.
    private var fallbackTopPadding: CGFloat {
        if #available(iOS 26, visionOS 26, *) {
            return 0
        }
        guard traitCollection.userInterfaceIdiom == .pad else {
            return 0
        }
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Style terminal
extension VMDisplayTerminalViewController {
    private func styleTerminal() {
        guard let style = style else {
            return
        }
        let fontSize = style.fontSize
        let fontName = style.font.rawValue
        if fontName != "" {
            let orig = terminalView.font
            let new = UIFont(name: fontName, size: CGFloat(fontSize)) ?? orig
            terminalView.font = new
        } else {
            let orig = terminalView.font
            let new = UIFont(descriptor: orig.fontDescriptor, size: CGFloat(fontSize))
            terminalView.font = new
        }
        if let consoleTextColor = style.foregroundColor,
           let textColor = Color(hexString: consoleTextColor),
           let consoleBackgroundColor = style.backgroundColor,
           let backgroundColor = Color(hexString: consoleBackgroundColor) {
            terminalView.nativeForegroundColor = UIColor(textColor)
            terminalView.nativeBackgroundColor = UIColor(backgroundColor)
        }
        terminalView.setCursorStyle(style.hasCursorBlink ? .blinkBlock : .steadyBlock)
        terminalView.optionAsMetaKey = boolForSetting("OptionAsMetaKey")
    }
}

// MARK: - TerminalViewDelegate
extension VMDisplayTerminalViewController: TerminalViewDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        delegate?.displayViewSize = CGSize(width: newCols, height: newRows)
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
    }
    
    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
        guard let url = URL(string: link), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        delegate?.displayDidAssertUserInteraction()
        vmSerialPort.write(Data(data))
    }
    
    func scrolled(source: TerminalView, position: Double) {
        delegate?.displayDidAssertUserInteraction()
    }
    
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
    }
    
    func clipboardCopy(source: TerminalView, content: Data) {
        if let str = String(bytes: content, encoding: .utf8) {
            UIPasteboard.general.string = str
        }
    }
}

// MARK: - CSPortDelegate
extension VMDisplayTerminalViewController: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
    }
    
    func port(_ port: CSPort, didError error: String) {
        delegate?.serialDidError(error)
    }
    
    func port(_ port: CSPort, didRecieveData data: Data) {
        if let terminalView = terminalView {
            terminalView.feed(byteArray: [UInt8](data)[...])
        }
    }
}
