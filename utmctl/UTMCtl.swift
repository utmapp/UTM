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
import AppKit
import ArgumentParser
import ScriptingBridge

@main
struct UTMCtl: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "utmctl",
        abstract: "CLI tool for controlling UTM virtual machines.",
        subcommands: [
            List.self,
            Status.self,
            Start.self,
            Suspend.self,
            Stop.self,
            Attach.self,
            File.self,
            Exec.self,
            IPAddress.self,
            Clone.self,
            Delete.self,
            USB.self
        ]
    )
}

/// Common interface for all subcommands
protocol UTMAPICommand: ParsableCommand {
    var environment: UTMCtl.EnvironmentOptions { get }
    
    func run(with application: UTMScriptingApplication) throws
}

extension UTMAPICommand {
    /// Entry point for all subcommands
    func run() throws {
        guard let app = SBApplication(url: utmAppUrl) else {
            throw UTMCtl.APIError.applicationNotFound
        }
        app.launchFlags = [.defaults, .andHide]
        app.delegate = UTMCtl.EventErrorHandler.shared
        let utmApp = app as UTMScriptingApplication
        if environment.hide {
            utmApp.setAutoTerminate!(false)
            if let windows = utmApp.windows!() as? [UTMScriptingWindow] {
                for window in windows {
                    if window.name == "UTM" {
                        window.closeSaving!(.no, savingIn: nil)
                        break
                    }
                }
            }
        }
        try run(with: utmApp)
    }
    
    /// Get a virtual machine from an identifier
    /// - Parameters:
    ///   - identifier: Identifier
    ///   - application: Scripting bridge application
    /// - Returns: Virtual machine for identifier
    func virtualMachine(forIdentifier identifier: UTMCtl.VMIdentifier, in application: UTMScriptingApplication) throws -> UTMScriptingVirtualMachine {
        let list = application.virtualMachines!()
        return try withErrorsSilenced(application) {
            if let vm = list.object(withID: identifier.identifier) as? UTMScriptingVirtualMachine, vm.id!() == identifier.identifier {
                return vm
            } else if let vm = list.object(withName: identifier.identifier) as? UTMScriptingVirtualMachine, vm.name! == identifier.identifier {
                return vm
            } else {
                throw UTMCtl.APIError.virtualMachineNotFound
            }
        }
    }
    
    /// Find the path to UTM.app
    private var utmAppUrl: URL {
        if let executableURL = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            let utmURL = executableURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if utmURL.pathExtension == "app" {
                return utmURL
            }
        }
        return URL(fileURLWithPath: "/Applications/UTM.app")
    }
    
    func withErrorsSilenced<Result>(_ application: UTMScriptingApplication, body: () throws -> Result) rethrows -> Result {
        let delegate = application.delegate
        application.delegate = nil
        let result = try body()
        application.delegate = delegate
        return result
    }
}

extension UTMCtl {
    @objc class EventErrorHandler: NSObject, SBApplicationDelegate {
        static let shared = EventErrorHandler()
        
        /// Error handler for scripting events
        /// - Parameters:
        ///   - event: Event that caused the error
        ///   - error: Error
        /// - Returns: nil
        func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
            let error = error as NSError
            FileHandle.standardError.write("Error from event: \(error.localizedDescription)")
            if let user = error.userInfo["ErrorString"] as? String {
                FileHandle.standardError.write(user)
            }
            if error.domain == NSOSStatusErrorDomain && error.code == errAEEventNotPermitted {
                FileHandle.standardError.write("NOTE: utmctl does not work from SSH sessions or before logging in.")
            }
            return nil
        }
    }
}

extension UTMCtl {
    enum APIError: Error, LocalizedError {
        case applicationNotFound
        case virtualMachineNotFound
        case invalidIdentifier(String)
        case deviceNotFound
        
        var errorDescription: String? {
            switch self {
            case .applicationNotFound: return "Application not found."
            case .virtualMachineNotFound: return "Virtual machine not found."
            case .invalidIdentifier(let identifier): return "Identifier '\(identifier)' is invalid."
            case .deviceNotFound: return "Device not found."
            }
        }
    }
}

fileprivate extension UTMScriptingStatus {
    var asString: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .started: return "started"
        case .pausing: return "pausing"
        case .paused: return "paused"
        case .resuming: return "resuming"
        case .stopping: return "stopping"
        @unknown default: return "unknown"
        }
    }
}

extension UTMCtl {
    struct List: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Enumerate all registered virtual machines."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        func run(with application: UTMScriptingApplication) throws {
            if let list = application.virtualMachines!() as? [UTMScriptingVirtualMachine] {
                printResponse(list)
            }
        }
        
        func printResponse(_ response: [UTMScriptingVirtualMachine]) {
            print("UUID                                 Status   Name")
            for entry in response {
                let status = entry.status!.asString.padding(toLength: 8, withPad: " ", startingAt: 0)
                print("\(entry.id!()) \(status) \(entry.name!)")
            }
        }
    }
}

extension UTMCtl {
    struct Status: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Query the status of a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            printResponse(vm)
            
        }
        
        func printResponse(_ vm: UTMScriptingVirtualMachine) {
            print(vm.status!.asString)
        }
    }
}

extension UTMCtl {
    struct Start: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Start a virtual machine or resume a suspended virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Flag(name: .shortAndLong, help: "Attach to the first serial port after start.")
        var attach: Bool = false
        
        @Flag(help: "Run VM as a snapshot and do not save changes to disk.")
        var disposable: Bool = false
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            vm.startSaving!(!disposable)
            if attach {
                print("WARNING: attach command is not implemented yet!")
            }
        }
    }
}

extension UTMCtl {
    struct Suspend: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Suspend running a virtual machine to memory."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Flag(name: .shortAndLong, help: "Save the VM state to disk after suspending.")
        var saveState: Bool = false
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            vm.suspendSaving!(saveState)
        }
    }
}

extension UTMCtl {
    struct Stop: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Shuts down a running virtual machine."
        )
        
        struct Style: ParsableArguments {
            @Flag(name: .long, help: "Force stop by sending a power off event (default)")
            var force: Bool = false
            
            @Flag(name: .long, help: "Force kill the VM process")
            var kill: Bool = false
            
            @Flag(name: .long, help: "Request power down from guest operating system")
            var request: Bool = false
            
            struct InvalidStyleError: LocalizedError {
                var errorDescription: String? {
                    "You can only specify one of: --force, --kill, or --request"
                }
            }
            
            mutating func validate() throws {
                let count = [force, kill, request].filter({ $0 }).count
                guard count <= 1 else {
                    throw InvalidStyleError()
                }
                if count == 0 {
                    force = true
                }
            }
        }
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @OptionGroup var style: Style
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            var stopMethod: UTMScriptingStopMethod = .force
            if style.request {
                stopMethod = .request
            } else if style.force {
                stopMethod = .force
            } else if style.kill {
                stopMethod = .kill
            }
            vm.stopBy!(stopMethod)
        }
    }
}

extension UTMCtl {
    struct Attach: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Redirect the serial input/output to this terminal."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Option(help: "Index of the serial device to attach to.")
        var index: Int?
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            guard let serialPorts = vm.serialPorts!() as? [UTMScriptingSerialPort] else {
                return
            }
            for serialPort in serialPorts {
                if let index = index {
                    if index != serialPort.id!() {
                        continue
                    }
                }
                print("WARNING: attach command is not implemented yet!")
                if let interface = serialPort.interface, interface != .unavailable {
                    printResponse(serialPort)
                    return
                }
            }
        }
        
        func printResponse(_ serialPort: UTMScriptingSerialPort) {
            // TODO: spawn a terminal emulator
            if serialPort.interface == .ptty {
                print("PTTY: \(serialPort.address!)")
            } else if serialPort.interface == .tcp {
                print("TCP: \(serialPort.address!):\(serialPort.port!)")
            }
        }
    }
}

extension UTMCtl {
    struct File: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Guest agent file operations.",
            subcommands: [FilePull.self, FilePush.self]
        )
    }
    
    struct FilePull: UTMAPICommand {
        static var configuration = CommandConfiguration(
            commandName: "pull",
            abstract: "Fetches a file from the guest and output it to stdout."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Argument(help: "Path of the file to pull on the guest.")
        var path: String
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            let file = vm.openFileAt!(path, for: .reading, updating: false)
            var data: Data
            repeat {
                let text = file.readAtOffset!(0, from: .currentPosition, forLength: 4096, base64Encoding: true, closing: false)
                data = Data(base64Encoded: text) ?? Data()
                try FileHandle.standardOutput.write(contentsOf: data)
            } while !data.isEmpty
            file.close!()
        }
    }
    
    struct FilePush: UTMAPICommand {
        static var configuration = CommandConfiguration(
            commandName: "push",
            abstract: "Uploads the contents of stdin to the guest."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Argument(help: "Destination path on the guest.")
        var path: String
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            let file = vm.openFileAt!(path, for: .writing, updating: false)
            var data: Data
            repeat {
                data = try FileHandle.standardInput.read(upToCount: 4096) ?? Data()
                file.writeWithData!(data.base64EncodedString(), atOffset: 0, from: .currentPosition, base64Encoding: true, closing: false)
            } while !data.isEmpty
            file.close!()
        }
    }
}

extension UTMCtl {
    struct Exec: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Execute an application on the guest.",
            discussion: "The return value of the command will be returned from this tool."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Flag(name: .long, help: "Read in standard input and forward it to the guest.")
        var input: Bool = false
        
        @Option(name: .long, parsing: .singleValue, help: "Set a single environment variable in the format NAME=VALUE")
        var env: [String] = []
        
        @Option(parsing: .remaining, help: "Command line to execute on the guest.")
        var cmd: [String]
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            let path = cmd.first!
            let args = Array(cmd.dropFirst())
            let data: Data
            if input {
                data = try FileHandle.standardInput.readToEnd() ?? Data()
            } else {
                data = Data()
            }
            let process = vm.executeAt!(path, withArguments: args, withEnvironment: env, usingInput: data.base64EncodedString(), base64Encoding: true, outputCapturing: true)
            var result: [AnyHashable: Any]
            repeat {
                result = process.getResult!()
            } while result["hasExited"] as? Bool == false
            let exitCode = result["exitCode"] as? Int ?? 0
            let outputData = result["outputData"] as? String ?? ""
            let errorData = result["errorData"] as? String ?? ""
            try FileHandle.standardOutput.write(contentsOf: Data(base64Encoded: outputData) ?? Data())
            try FileHandle.standardError.write(contentsOf: Data(base64Encoded: errorData) ?? Data())
            if exitCode != 0 {
                Darwin.exit(Int32(exitCode))
            }
        }
    }
}

extension UTMCtl {
    struct IPAddress: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "List all IP addresses associated with network interfaces on the guest.",
            discussion: "IPv4 addresses (if available) will be listed before any IPv6 address."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            let addresses = vm.queryIp!()
            for address in addresses {
                print(address)
            }
        }
    }
}

extension UTMCtl {
    struct Clone: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Clone an existing virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Option var name: String?
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            var properties = ["configuration": [:]]
            if let name = name {
                properties["configuration"] = ["name": name]
            }
            vm.duplicateTo!(nil, withProperties: properties)
        }
    }
}

extension UTMCtl {
    struct Delete: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Delete a virtual machine (there is no confirmation)."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            vm.delete!()
        }
    }
}

extension UTMCtl {
    struct USB: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "USB device handling.",
            subcommands: [USBList.self, USBConnect.self, USBDisconnect.self]
        )
        
        /// Find a USB device using an identifier
        /// - Parameters:
        ///   - identifier: Either VID:PID or a location
        ///   - application: Scripting application
        /// - Returns: USB device
        static func usbDevice(forIdentifier identifier: String, in application: UTMScriptingApplication) throws -> UTMScriptingUsbDevice {
            let parts = identifier.split(separator: ":")
            if parts.count == 2 {
                let vid = Int(parts[0], radix: 16)
                let pid = Int(parts[1], radix: 16)
                if let vid = vid, let pid = pid {
                    return try usbDevice(forVid: vid, pid: pid, in: application)
                }
            }
            if let location = Int(identifier, radix: 10) {
                return try usbDevice(forLocation: location, in: application)
            }
            throw APIError.invalidIdentifier(identifier)
        }
        
        static private func usbDevice(forVid vid: Int, pid: Int, in application: UTMScriptingApplication) throws -> UTMScriptingUsbDevice {
            if let list = application.usbDevices!() as? [UTMScriptingUsbDevice] {
                if let device = list.first(where: { $0.vendorId == vid && $0.productId == pid }) {
                    return device
                }
            }
            throw APIError.deviceNotFound
        }
        
        static private func usbDevice(forLocation location: Int, in application: UTMScriptingApplication) throws -> UTMScriptingUsbDevice {
            if let list = application.usbDevices!() as? [UTMScriptingUsbDevice] {
                if let device = list.first(where: { $0.id!() == location }) {
                    return device
                }
            }
            throw APIError.deviceNotFound
        }
    }
    
    struct USBList: UTMAPICommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List connected devices."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        func run(with application: UTMScriptingApplication) throws {
            if let list = application.usbDevices!() as? [UTMScriptingUsbDevice] {
                printResponse(list)
            }
        }
        
        func printResponse(_ response: [UTMScriptingUsbDevice]) {
            guard !response.isEmpty else {
                print("No devices found. Make sure a USB sharing enabled VM is running.")
                return
            }
            print("Name                             VID :PID  Location")
            for entry in response {
                let name = entry.name!.padding(toLength: 32, withPad: " ", startingAt: 0)
                let vid = String(format: "%04X", entry.vendorId!)
                let pid = String(format: "%04X", entry.productId!)
                print("\(name) \(vid):\(pid) \(entry.id!())")
            }
        }
    }
    
    struct USBConnect: UTMAPICommand {
        static var configuration = CommandConfiguration(
            commandName: "connect",
            abstract: "Connect a USB device to a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
        
        @Argument(help: "Device identifier either as a VID:PID pair (e.g. DEAD:BEEF) or a location (e.g. 4).")
        var device: String
        
        func run(with application: UTMScriptingApplication) throws {
            let vm = try virtualMachine(forIdentifier: identifer, in: application)
            let device = try USB.usbDevice(forIdentifier: device, in: application)
            device.connectTo!(vm)
        }
    }
    
    struct USBDisconnect: UTMAPICommand {
        static var configuration = CommandConfiguration(
            commandName: "disconnect",
            abstract: "Disconnect a USB device from a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @Argument(help: "Device identifier either as a VID:PID pair (e.g. DEAD:BEEF) or a location (e.g. 4).")
        var device: String
        
        func run(with application: UTMScriptingApplication) throws {
            let device = try USB.usbDevice(forIdentifier: device, in: application)
            device.disconnect!()
        }
    }
}

extension UTMCtl {
    struct VMIdentifier: ParsableArguments {
        @Argument(help: "Either the UUID or the complete name of the virtual machine.")
        var identifier: String
    }
    
    struct EnvironmentOptions: ParsableArguments {
        @Flag(name: .shortAndLong, help: "Show debug logging.")
        var debug: Bool = false
        
        @Flag(help: "Hide the main UTM window.")
        var hide: Bool = false
    }
}

private extension String {
    var asFileURL: URL {
        URL(fileURLWithPath: self, relativeTo: nil)
    }
}

extension FileHandle: TextOutputStream {
    private static var newLine = Data("\n".utf8)
    
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
        self.write(Self.newLine)
    }
}
