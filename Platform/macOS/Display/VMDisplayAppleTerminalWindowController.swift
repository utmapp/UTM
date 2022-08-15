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

class VMDisplayAppleTerminalWindowController: VMDisplayAppleWindowController, VMDisplayTerminal {
    var terminalView: TerminalView! {
        mainView as? TerminalView
    }
    
    var serialConfig: UTMAppleConfigurationSerial! {
        appleConfig.serials[index]
    }
    
    var serialPort: UTMSerialPort! {
        serialConfig.interface
    }
    
    override var defaultTitle: String {
        if isSecondary {
            return String.localizedStringWithFormat(NSLocalizedString("%@ (Terminal %lld)", comment: "VMDisplayAppleTerminalWindowController"), super.defaultTitle, index + 1)
        } else {
            return super.defaultTitle
        }
    }
    
    private(set) var isPrimary: Bool = true
    private(set) var index: Int = 0
    
    convenience init(primaryForIndex index: Int, vm: UTMAppleVirtualMachine, onClose: ((Notification) -> Void)?) {
        self.init(vm: vm, onClose: onClose)
        self.index = index
    }
    
    convenience init(secondaryForIndex index: Int, vm: UTMAppleVirtualMachine) {
        self.init(vm: vm, onClose: nil)
        self.index = index
    }
    
    override func windowDidLoad() {
        mainView = TerminalView()
        terminalView!.terminalDelegate = self
        super.windowDidLoad()
    }
    
    override func updateWindowFrame() {
        setupTerminal(terminalView, using: serialConfig.terminal!, for: window!)
        super.updateWindowFrame()
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        let cmd = resizeCommand(for: terminalView, using: serialConfig!.terminal!)
        serialPort.write(data: cmd.data(using: .ascii)!)
        
    }
    
    override func enterLive() {
        serialPort.delegate = self
        super.enterLive()
    }
}

// MARK: - Terminal view delegate
extension VMDisplayAppleTerminalWindowController: TerminalViewDelegate, UTMSerialPortDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
        window!.subtitle = title
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        serialPort.write(data: Data(data))
    }
    
    func scrolled(source: TerminalView, position: Double) {
    }
    
    func serialPort(_ serialPort: UTMSerialPort, didRecieveData data: Data) {
        if let terminalView = terminalView {
            let arr = [UInt8](data)[...]
            DispatchQueue.main.async {
                terminalView.feed(byteArray: arr)
            }
        }
    }
}
