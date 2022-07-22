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

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

@objc class VMDisplayTerminalViewController: VMDisplayViewController {
    private var terminalView: TerminalView!
    private var vmSerialPort: CSPort?
    
    required init(vm: UTMQemuVirtualMachine, port: CSPort? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.vm = vm
        self.vmSerialPort = port
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        super.loadView()
        vm.delegate = self;
        terminalView = TerminalView(frame: .zero)
        view.insertSubview(terminalView, at: 0)
        terminalView.bindFrameToSuperviewBounds()
    }
    
    // FIXME: connect this to toolbar action
    func changeDisplayZoom(_ sender: UIButton) {
        let cols = terminalView.getTerminal().cols
        let rows = terminalView.getTerminal().rows
        let template = vmQemuConfig.qemuConsoleResizeCommand ?? kVMDefaultResizeCmd
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

extension VMDisplayTerminalViewController: TerminalViewDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
    }
    
    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
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
    
    func bell(source: TerminalView) {
    }
}

extension VMDisplayTerminalViewController: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
    }
    
    func port(_ port: CSPort, didError error: String) {
        showAlert(error, actions: nil)
    }
    
    func port(_ port: CSPort, didRecieveData data: Data) {
        if let terminalView = terminalView {
            let arr = [UInt8](data)[...]
            DispatchQueue.main.async {
                terminalView.feed(byteArray: arr)
            }
        }
    }
}
