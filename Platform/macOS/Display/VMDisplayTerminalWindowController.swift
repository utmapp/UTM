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

import SwiftTerm

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

class VMDisplayTerminalWindowController: VMDisplayQemuWindowController {
    private var terminalView: TerminalView!
    private weak var vmSerialPort: CSPort?

    override func windowDidLoad() {
        terminalView = TerminalView(frame: displayView.bounds)
        terminalView.terminalDelegate = self
        terminalView.autoresizingMask = [.width, .height]
        displayView.addSubview(terminalView)
        super.windowDidLoad()
    }
    
    override func enterLive() {
        super.enterLive()
        captureMouseToolbarItem.isEnabled = false
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        let cols = terminalView.getTerminal().cols
        let rows = terminalView.getTerminal().rows
        let template = vmQemuConfig?.serials.first?.terminal?.resizeCommand ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(cols))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        vmSerialPort?.write(cmd.data(using: .nonLossyASCII)!)
    }
    
    override func spiceDidCreateSerial(_ serial: CSPort) {
        if vmSerialPort == nil {
            vmSerialPort = serial
            serial.delegate = self
        }
    }
    
    override func spiceDidDestroySerial(_ serial: CSPort) {
        if vmSerialPort == serial {
            serial.delegate = nil
            vmSerialPort = nil
        }
    }
}

extension VMDisplayTerminalWindowController: TerminalViewDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
        window!.subtitle = title
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        if let vmSerialPort = vmSerialPort {
            vmSerialPort.write(Data(data))
        }
    }
    
    func scrolled(source: TerminalView, position: Double) {
    }
}

extension VMDisplayTerminalWindowController: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
    }
    
    func port(_ port: CSPort, didError error: String) {
        showErrorAlert(error)
    }
    
    func port(_ port: CSPort, didRecieveData data: Data) {
        if let terminalView = terminalView {
            let arr = [UInt8](data)[...]
            DispatchQueue.main.async {
                terminalView.feed(byteArray: arr)
            }
        }
    }
    
    func defaultSerialWrite(data: Data) {
        if let vmSerialPort = vmSerialPort {
            vmSerialPort.write(data)
        }
    }
}
