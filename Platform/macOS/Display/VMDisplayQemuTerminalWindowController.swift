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
    
    convenience init(secondaryFromSerialPort serialPort: CSPort, vm: UTMQemuVirtualMachine, id: Int) {
        self.init(vm: vm, id: id)
        self.vmSerialPort = serialPort
    }

    override func windowDidLoad() {
        terminalView = TerminalView(frame: displayView.bounds)
        terminalView.terminalDelegate = self
        terminalView.autoresizingMask = [.width, .height]
        displayView.addSubview(terminalView)
        vmSerialPort?.delegate = self // can be nil for primary window
        super.windowDidLoad()
    }
    
    override func enterLive() {
        super.enterLive()
        captureMouseToolbarItem.isEnabled = false
        setupTerminal(terminalView, using: serialConfig!.terminal!, for: window!)
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if vm.state == .vmStopped {
            vmSerialPort = nil
        }
        super.enterSuspended(isBusy: busy)
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        let cmd = resizeCommand(for: terminalView, using: serialConfig!.terminal!)
        vmSerialPort?.write(cmd.data(using: .nonLossyASCII)!)
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

extension VMDisplayQemuTerminalWindowController: CSPortDelegate {
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
