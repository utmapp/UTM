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

import WebKit

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

private enum JSCommand: String {
    case sendInput = "UTMSendInput"
    case debug = "UTMDebug"
    case sendGesture = "UTMSendGesture"
    case sendTerminalSize = "UTMSendTerminalSize"
}

class VMDisplayTerminalWindowController: VMDisplayWindowController {
    var webView: WKWebView!
    private var columns: Int?
    private var rows: Int?

    override func windowDidLoad() {
        super.windowDidLoad()
        let webConfig = WKWebViewConfiguration()
        webConfig.userContentController.add(self, name: JSCommand.sendInput.rawValue)
        webConfig.userContentController.add(self, name: JSCommand.debug.rawValue)
        webConfig.userContentController.add(self, name: JSCommand.sendGesture.rawValue)
        webConfig.userContentController.add(self, name: JSCommand.sendTerminalSize.rawValue)
        webView = WKWebView(frame: displayView.bounds, configuration: webConfig)
        webView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        displayView.addSubview(webView)
        
        // load terminal.html
        guard let resourceURL = Bundle.main.resourceURL else {
            showErrorAlert(NSLocalizedString("Cannot find bundle resources.", comment: "VMDisplayTerminalWindowController"))
            logger.critical("Cannot find system default Metal device.")
            return
        }
        let indexFile = resourceURL.appendingPathComponent("terminal.html")
        webView.navigationDelegate = self
        self.webView.loadFileURL(indexFile, allowingReadAccessTo: resourceURL)
        
        if vm.state == .vmStopped || vm.state == .vmSuspended {
            enterSuspended(isBusy: false)
            vm.startVM()
        } else {
            enterLive()
        }
        vm.ioDelegate = self
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let columns = self.columns else {
            logger.error("Did not get columns from page")
            return
        }
        guard let rows = self.rows else {
            logger.error("Did not get rows from page")
            return
        }
        let template = vmConfiguration?.consoleResizeCommand ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(columns))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        vm.sendInput(cmd)
    }
}

extension VMDisplayTerminalWindowController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateSettings()
    }
    
    func updateSettings() {
        if let consoleFont = vmConfiguration?.consoleFont {
            let consoleFontSize = vmConfiguration?.consoleFontSize?.intValue ?? 12
            webView.evaluateJavaScript("changeFont('\(consoleFont)', \(consoleFontSize));") { (_, err) in
                if let error = err {
                    logger.error("changeFont error: \(error)")
                }
            }
        }
        if let cursorBlink = vmConfiguration?.consoleCursorBlink {
            webView.evaluateJavaScript("setCursorBlink(\(cursorBlink ? "true" : "false"));") { (_, err) in
                if let error = err {
                    logger.error("setCursorBlink error: \(error)")
                }
            }
        }
    }
}

extension VMDisplayTerminalWindowController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let command = JSCommand.init(rawValue: message.name) else {
            logger.error("Unknown command: \(message.name)")
            return
        }
        switch command {
        case .sendInput:
            guard let body = message.body as? String else {
                logger.error("Body is not of string type")
                return
            }
            vm.sendInput(body)
        case .debug:
            logger.debug("JS debug: \(message.body)")
        case .sendGesture:
            logger.debug("Ignoring gesture")
        case .sendTerminalSize:
            guard let body = message.body as? [NSNumber], body.count == 2 else {
                logger.error("Body is not an array of two numbers")
                return
            }
            columns = body[0].intValue
            rows = body[1].intValue
        }
    }
}

extension VMDisplayTerminalWindowController: UTMTerminalDelegate {
    func terminal(_ terminal: UTMTerminal, didReceive data: Data) {
        var dataString = "["
        for i in data.indices {
            dataString = dataString.appendingFormat("%u,", data[i])
        }
        dataString = dataString + "]"
        let jsString = "writeData(new Uint8Array(\(dataString)));"
        webView.evaluateJavaScript(jsString) { (_, err) in
            if let error = err {
                logger.error("JS evaluation failed: \(error)")
            }
        }
    }
}
