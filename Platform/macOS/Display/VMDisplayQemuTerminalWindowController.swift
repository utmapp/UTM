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

class VMDisplayQemuTerminalWindowController: VMDisplayQemuWindowController, VMDisplayTerminal {
    private var terminalView: TerminalView!
    private var vmSerialPort: CSPort?
    
    private var serialConfig: UTMQemuConfigurationSerial? {
        vmQemuConfig?.serials[id]
    }
    
    override var defaultTitle: String {
        if isSecondary {
            return String.localizedStringWithFormat(NSLocalizedString("%@ (Terminal %lld)", comment: "VMDisplayQemuTerminalWindowController"), vmQemuConfig.information.name, id + 1)
        } else {
            return super.defaultTitle
        }
    }
    
    private var isSizeChangeIgnored: Bool = true
    @Setting("OptionAsMetaKey") var isOptionAsMetaKey: Bool = false
    
    convenience init(secondaryFromSerialPort serialPort: CSPort, vm: UTMQemuVirtualMachine, id: Int) {
        self.init(vm: vm, id: id)
        self.vmSerialPort = serialPort
    }

    override func windowDidLoad() {
        terminalView = TerminalView(frame: displayView.bounds)
        terminalView.terminalDelegate = self
        terminalView.autoresizingMask = [.width, .height]
        terminalView.allowMouseReporting = false
        displayView.addSubview(terminalView)
        vmSerialPort?.delegate = self // can be nil for primary window
        super.windowDidLoad()
    }
    
    override func enterLive() {
        super.enterLive()
        isSizeChangeIgnored = true
        setupTerminal(terminalView, using: serialConfig!.terminal!, id: id, for: window!)
        isSizeChangeIgnored = false
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if vm.state == .stopped {
            vmSerialPort = nil
        }
        super.enterSuspended(isBusy: busy)
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        let cmd = resizeCommand(for: terminalView, using: serialConfig!.terminal!)
        vmSerialPort?.write(cmd.data(using: .nonLossyASCII)!)
    }
    
    override func captureMouseButtonPressed(_ sender: Any) {
        terminalView.allowMouseReporting = !terminalView.allowMouseReporting
        captureMouseToolbarButton.state = terminalView.allowMouseReporting ? .on : .off
    }
    
    override func spiceDidCreateSerial(_ serial: CSPort) {
        if !isSecondary, vmSerialPort == nil {
            vmSerialPort = serial
            serial.delegate = self
        } else {
            super.spiceDidCreateSerial(serial)
        }
    }
    
    override func spiceDidDestroySerial(_ serial: CSPort) {
        if vmSerialPort == serial {
            if isSecondary {
                DispatchQueue.main.async {
                    self.close()
                }
            }
            serial.delegate = nil
            vmSerialPort = nil
        } else {
            super.spiceDidDestroySerial(serial)
        }
    }
}

extension VMDisplayQemuTerminalWindowController: TerminalViewDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        if !isSizeChangeIgnored {
            sizeChanged(id: id, newCols: newCols, newRows: newRows)
        }
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
    
    func sendString(_ string: String) {
        if let vmSerialPort = vmSerialPort, let data = string.data(using: .nonLossyASCII) {
            vmSerialPort.write(data)
        } else {
            logger.error("failed to send: \(string)")
        }
    }
    
    func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
        if let str = String(bytes: content, encoding: .utf8) {
            let pasteBoard = NSPasteboard.general
            pasteBoard.clearContents()
            pasteBoard.writeObjects([str as NSString])
        }
    }
    
    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
    }
}

extension VMDisplayQemuTerminalWindowController: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
    }
    
    func port(_ port: CSPort, didError error: String) {
        Task { @MainActor in
            showErrorAlert(error)
        }
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
