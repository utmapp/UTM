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
    case usbDevice = "usb device"
    case virtualMachine = "virtual machine"
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

// MARK: UTMScriptingSaveOptions
@objc public enum UTMScriptingSaveOptions : AEKeyword {
    case yes = 0x79657320 /* 'yes ' */
    case no = 0x6e6f2020 /* 'no  ' */
    case ask = 0x61736b20 /* 'ask ' */
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

// MARK: UTMScriptingQemuDirectoryShareMode
@objc public enum UTMScriptingQemuDirectoryShareMode : AEKeyword {
    case none = 0x536d4f66 /* 'SmOf' */
    case webDAV = 0x536d5776 /* 'SmWv' */
    case virtFS = 0x536d5673 /* 'SmVs' */
}

// MARK: UTMScriptingQemuDriveInterface
@objc public enum UTMScriptingQemuDriveInterface : AEKeyword {
    case none = 0x5164494e /* 'QdIN' */
    case ide = 0x51644969 /* 'QdIi' */
    case scsi = 0x51644973 /* 'QdIs' */
    case sd = 0x51644964 /* 'QdId' */
    case mtd = 0x5164496d /* 'QdIm' */
    case floppy = 0x51644966 /* 'QdIf' */
    case pFlash = 0x51644970 /* 'QdIp' */
    case virtIO = 0x51644976 /* 'QdIv' */
    case nvMe = 0x5164496e /* 'QdIn' */
    case usb = 0x51644975 /* 'QdIu' */
}

// MARK: UTMScriptingQemuNetworkMode
@objc public enum UTMScriptingQemuNetworkMode : AEKeyword {
    case emulated = 0x456d5564 /* 'EmUd' */
    case shared = 0x53685264 /* 'ShRd' */
    case host = 0x486f5374 /* 'HoSt' */
    case bridged = 0x42724764 /* 'BrGd' */
}

// MARK: UTMScriptingNetworkProtocol
@objc public enum UTMScriptingNetworkProtocol : AEKeyword {
    case tcp = 0x54635070 /* 'TcPp' */
    case udp = 0x55645070 /* 'UdPp' */
}

// MARK: UTMScriptingQemuScaler
@objc public enum UTMScriptingQemuScaler : AEKeyword {
    case linear = 0x51734c69 /* 'QsLi' */
    case nearest = 0x51734e65 /* 'QsNe' */
}

// MARK: UTMScriptingAppleNetworkMode
@objc public enum UTMScriptingAppleNetworkMode : AEKeyword {
    case shared = 0x53685264 /* 'ShRd' */
    case bridged = 0x42724764 /* 'BrGd' */
}

// MARK: UTMScriptingGenericMethods
@objc public protocol UTMScriptingGenericMethods {
    @objc optional func closeSaving(_ saving: UTMScriptingSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ in_: URL!, as: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: UTMScriptingApplication
@objc public protocol UTMScriptingApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: UTMScriptingSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func importNew(_ new_: NSNumber!, from: URL!) -> SBObject // Import a new virtual machine from a file.
    @objc optional func virtualMachines() -> SBElementArray
    @objc optional var autoTerminate: Bool { get } // Auto terminate the application when all windows are closed?
    @objc optional func setAutoTerminate(_ autoTerminate: Bool) // Auto terminate the application when all windows are closed?
    @objc optional func usbDevices() -> SBElementArray
}
extension SBApplication: UTMScriptingApplication {}

// MARK: UTMScriptingDocument
@objc public protocol UTMScriptingDocument: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: UTMScriptingDocument {}

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
    @objc optional var document: UTMScriptingDocument { get } // The document whose contents are displayed in the window.
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
    @objc optional var backend: UTMScriptingBackend { get } // Emulation/virtualization engine used.
    @objc optional var status: UTMScriptingStatus { get } // Current running status.
    @objc optional func startSaving(_ saving: Bool) // Start a virtual machine or resume a suspended virtual machine.
    @objc optional func suspendSaving(_ saving: Bool) // Suspend a running virtual machine to memory.
    @objc optional func stopBy(_ by: UTMScriptingStopMethod) // Shuts down a running virtual machine.
    @objc optional func delete() // Delete a virtual machine. All data will be deleted, there is no confirmation!
    @objc optional func duplicateWithProperties(_ withProperties: [AnyHashable : Any]!) // Copy an virtual machine and all its data.
    @objc optional func exportTo(_ to: URL!) // Export a virtual machine to a specified location.
    @objc optional func openFileAt(_ at: String!, for for_: UTMScriptingOpenMode, updating: Bool) -> UTMScriptingGuestFile // Open a file on the guest. You must close the file when you are done to prevent leaking guest resources.
    @objc optional func executeAt(_ at: String!, withArguments: [String]!, withEnvironment: [String]!, usingInput: String!, base64Encoding: Bool, outputCapturing: Bool) -> UTMScriptingGuestProcess // Execute a command or script on the guest.
    @objc optional func queryIp() -> [Any] // Query the guest for all IP addresses on its network interfaces (excluding loopback).
    @objc optional func updateConfigurationWith(_ with: Any!) // Update the configuration of the virtual machine. The VM must be in the stopped state.
    @objc optional func guestFiles() -> SBElementArray
    @objc optional func guestProcesses() -> SBElementArray
    @objc optional var configuration: Any { get } // The configuration of the virtual machine.
    @objc optional func usbDevices() -> SBElementArray
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

// MARK: UTMScriptingUsbDevice
@objc public protocol UTMScriptingUsbDevice: SBObjectProtocol, UTMScriptingGenericMethods {
    @objc optional func id() -> Int // A unique identifier corrosponding to the USB bus and port number.
    @objc optional var name: String { get } // The name of the USB device.
    @objc optional var manufacturerName: String { get } // The product name described by the iManufacturer descriptor.
    @objc optional var productName: String { get } // The product name described by the iProduct descriptor.
    @objc optional var vendorId: Int { get } // The vendor ID described by the idVendor descriptor.
    @objc optional var productId: Int { get } // The product ID described by the idProduct descriptor.
    @objc optional func connectTo(_ to: UTMScriptingVirtualMachine!) // Connect a USB device to a running VM and remove it from the host.
    @objc optional func disconnect() // Disconnect a USB device from the guest and re-assign it to the host.
}
extension SBObject: UTMScriptingUsbDevice {}

