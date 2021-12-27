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

import Foundation

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

@objc class UTMSerialPort: NSObject {
    let name: String
    private let readFileHandle: FileHandle
    private let writeFileHandle: FileHandle
    private let terminalFileHandle: FileHandle?
    
    public weak var delegate: UTMSerialPortDelegate? {
        didSet {
            if let delegate = delegate {
                readFileHandle.readabilityHandler = { handle in
                    delegate.serialPort(self, didRecieveData: handle.availableData)
                }
            } else {
                readFileHandle.readabilityHandler = nil
            }
        }
    }
    
    init(portNamed name: String, readFileHandle: FileHandle, writeFileHandle: FileHandle, terminalFileHandle: FileHandle? = nil) {
        self.name = name
        self.readFileHandle = readFileHandle
        self.writeFileHandle = writeFileHandle
        self.terminalFileHandle = terminalFileHandle
    }
    
    deinit {
        close()
    }
    
    public func write(data: Data) {
        try! writeFileHandle.write(contentsOf: data)
    }
    
    public func close() {
        try? readFileHandle.close()
        try? writeFileHandle.close()
        try? terminalFileHandle?.close()
    }
    
    public func writeResizeCommand(_ command: String?, columns: Int, rows: Int) {
        let template = command ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(columns))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        write(data: cmd.data(using: .ascii)!)
    }
}
