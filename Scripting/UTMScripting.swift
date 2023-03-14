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

// !! THIS FILE IS GENERATED FROM bridge-gen.sh, DO NOT MODIFY MANUALLY !!

public enum UTMScripting: String {
    case application = "application"
    case guestFile = "guest file"
    case guestProcess = "guest process"
    case serialPort = "serial port"
    case virtualMachine = "virtual machine"
    case window = "window"
}

import AppKit
import ScriptingBridge

@objc public protocol SBObjectProtocol: NSObjectProtocol {
    func get() -> Any!
}

@objc public protocol SBApplicationProtocol: SBObjectProtocol {
    func activate()
    var delegate: SBApplicationDelegate! { get set }
    var isRunning: Bool { get }
}

// MARK: UTMScriptingPrintingErrorHandling
@objc public enum UTMScriptingPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* 'lwst' */
    case detailed = 0x6c776474 /* 'lwdt' */
}

// MARK: UTMScriptingBackend
@objc public enum UTMScriptingBackend : AEKeyword {
    case apple = 0x4170506c /* 'ApPl' */
    case qemu = 0x51654d75 /* 'QeMu' */
    case unavailable = 0x556e4176 /* 'UnAv' */
}

// MARK: UTMScriptingStatus
@objc public enum UTMScriptingStatus : AEKeyword {
    case stopped = 0x53745361 /* 'StSa' */
    case starting = 0x53745362 /* 'StSb' */
    case started = 0x53745363 /* 'StSc' */
    case pausing = 0x53745364 /* 'StSd' */
    case paused = 0x53745365 /* 'StSe' */
    case resuming = 0x53745366 /* 'StSf' */
    case stopping = 0x53745367 /* 'StSg' */
}

// MARK: UTMScriptingStopMethod
@objc public enum UTMScriptingStopMethod : AEKeyword {
    case force = 0x466f5263 /* 'FoRc' */
    case kill = 0x4b694c6c /* 'KiLl' */
    case request = 0x52655175 /* 'ReQu' */
}

// MARK: UTMScriptingSerialInterface
@objc public enum UTMScriptingSerialInterface : AEKeyword {
    case ptty = 0x50745479 /* 'PtTy' */
    case tcp = 0x54635020 /* 'TcP ' */
    case unavailable = 0x49556e41 /* 'IUnA' */
}

// MARK: UTMScriptingOpenMode
@objc public enum UTMScriptingOpenMode : AEKeyword {
    case reading = 0x4f70526f /* 'OpRo' */
    case writing = 0x4f70576f /* 'OpWo' */
    case appending = 0x4f704170 /* 'OpAp' */
}

// MARK: UTMScriptingWhence
@objc public enum UTMScriptingWhence : AEKeyword {
    case startPosition = 0x53745274 /* 'StRt' */
    case currentPosition = 0x43755272 /* 'CuRr' */
    case endPosition = 0x556e4176 /* 'UnAv' */
}

// MARK: UTMScriptingGenericMethods
@objc public protocol UTMScriptingGenericMethods {
    @objc optional func close() // Close a document.
}

// MARK: UTMScriptingApplication
@objc public protocol UTMScriptingApplication: SBApplicationProtocol {
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func quit() // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func virtualMachines() -> SBElementArray
    @objc optional var autoTerminate: Bool { get } // Auto terminate the application when all windows are closed?
    @objc optional func setAutoTerminate(_ autoTerminate: Bool) // Auto terminate the application when all windows are closed?
}
extension SBApplication: UTMScriptingApplication {}

// MARK: UTMScriptingWindow
@objc public protocol UTMScriptingWindow: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional var name: String { get } // The title of the window.
    @objc optional func id() -> Int // The unique identifier of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Does the window have a close button?
    @objc optional var miniaturizable: Bool { get } // Does the window have a minimize button?
    @objc optional var miniaturized: Bool { get } // Is the window minimized right now?
    @objc optional var resizable: Bool { get } // Can the window be resized?
    @objc optional var visible: Bool { get } // Is the window visible right now?
    @objc optional var zoomable: Bool { get } // Does the window have a zoom button?
    @objc optional var zoomed: Bool { get } // Is the window zoomed right now?
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: UTMScriptingWindow {}

// MARK: UTMScriptingVirtualMachine
@objc public protocol UTMScriptingVirtualMachine: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional func serialPorts() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the VM.
    @objc optional var name: String { get } // The name of the VM.
    @objc optional var notes: String { get } // User specified notes.
    @objc optional var machine: String { get } // Target machine name.
    @objc optional var architecture: String { get } // Target architecture name.
    @objc optional var memory: String { get } // RAM size.
    @objc optional var backend: UTMScriptingBackend { get } // Emulation/virtualization engine used.
    @objc optional var status: UTMScriptingStatus { get } // Current running status.
    @objc optional func startSaving(_ saving: Bool) // Start a virtual machine or resume a suspended virtual machine.
    @objc optional func suspendSaving(_ saving: Bool) // Suspend a running virtual machine to memory.
    @objc optional func stopBy(_ by: UTMScriptingStopMethod) // Shuts down a running virtual machine.
    @objc optional func openFileAt(_ at: String!, for for_: UTMScriptingOpenMode, updating: Bool) -> UTMScriptingGuestFile // Open a file on the guest. You must close the file when you are done to prevent leaking guest resources.
    @objc optional func executeAt(_ at: String!, withArguments: [String]!, withEnvironment: [String]!, usingInput: String!, base64Encoding: Bool, outputCapturing: Bool) -> UTMScriptingGuestProcess // Execute a command or script on the guest.
    @objc optional func queryIp() -> [Any] // Query the guest for all IP addresses on its network interfaces (excluding loopback).
    @objc optional func guestFiles() -> SBElementArray
    @objc optional func guestProcesses() -> SBElementArray
}
extension SBObject: UTMScriptingVirtualMachine {}

// MARK: UTMScriptingSerialPort
@objc public protocol UTMScriptingSerialPort: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional func id() -> Int // The unique identifier of the tag.
    @objc optional var interface: UTMScriptingSerialInterface { get } // The type of serial interface on the host.
    @objc optional var address: String { get } // Host address of the serial port (determined by the interface type).
    @objc optional var port: Int { get } // Port number of the serial port (not used in some interface types).
}
extension SBObject: UTMScriptingSerialPort {}

// MARK: UTMScriptingGuestFile
@objc public protocol UTMScriptingGuestFile: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional func id() -> Int // The handle for the file.
    @objc optional func readAtOffset(_ atOffset: Int, from: UTMScriptingWhence, forLength: Int, base64Encoding: Bool, closing: Bool) -> String // Reads text data from a guest file.
    @objc optional func pullTo(_ to: URL!, closing: Bool) // Pulls a file from the guest to the host.
    @objc optional func writeWithData(_ withData: String!, atOffset: Int, from: UTMScriptingWhence, base64Encoding: Bool, closing: Bool) // Writes text data to a guest file.
    @objc optional func pushFrom(_ from: URL!, closing: Bool) // Pushes a file from the host to the guest and closes it.
    @objc optional func close() // Closes the file and prevent further operations.
}
extension SBObject: UTMScriptingGuestFile {}

// MARK: UTMScriptingGuestProcess
@objc public protocol UTMScriptingGuestProcess: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional func id() -> Int // The PID of the process.
    @objc optional func getResult() -> [AnyHashable : Any] // Fetch execution result from the guest.
}
extension SBObject: UTMScriptingGuestProcess {}

