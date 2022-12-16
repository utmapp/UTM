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
    @objc optional func startSaving(_ saving: Bool)
    @objc optional func suspendSaving(_ saving: Bool)
    @objc optional func stopBy(_ by: UTMScriptingStopMethod)
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

