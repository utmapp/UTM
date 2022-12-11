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
import ArgumentParser
import Logging

var logger = Logger(label: "com.utmapp.utmctl") { label in
    StreamLogHandler.standardError(label: label)
}

@main
struct UTMCtl: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "utmctl",
        abstract: "CLI tool for controlling UTM virtual machines.",
        subcommands: [List.self, Status.self, Start.self, Suspend.self, Stop.self, Attach.self]
    )
}

/// Common interface for all subcommands
protocol UTMAPICommand: AsyncParsableCommand {
    associatedtype Request: UTMAPIRequest = UTMAPI.AnyRequest
    var environment: UTMCtl.EnvironmentOptions { get }
    
    func run(with client: UTMAPIClient) async throws
    func createRequest() -> Request
    func printResponse(_ response: Request.Response)
}

extension UTMAPICommand {
    /// Entry point for all subcommands
    func run() async throws {
        logger.logLevel = environment.debug ? .debug : .info
        let socketUrl = environment.socketPath?.asFileURL ?? defaultSocketUrl
        let client = UTMAPIClient(connectPathUrl: socketUrl)
        try await client.connect()
        try await run(with: client)
        try await client.disconnect()
    }
    
    /// Socket either in app group or app sandbox
    private var defaultSocketUrl: URL {
        let appGroup = Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String
        let appBundle = Bundle.main.infoDictionary?["AppBundleIdentifier"] as? String
        // default to unsigned sandbox path
        var parentURL: URL = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        parentURL.appendPathComponent("Containers")
        parentURL.appendPathComponent(appBundle ?? "com.utmapp.UTM")
        parentURL.appendPathComponent("Data")
        parentURL.appendPathComponent("tmp")
        if let appGroup = appGroup, !appGroup.hasPrefix("invalid.") {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
                parentURL = containerURL
            }
        }
        return parentURL.appendingPathComponent("api.sock")
    }
    
    /// Default implementation of run command
    /// - Parameter client: Connected client
    func run(with client: UTMAPIClient) async throws {
        let request = createRequest()
        let response = try await client.process(request: request)
        if environment.machineReadable {
            printJson(for: response)
        } else {
            printResponse(response)
        }
    }
    
    /// Default placeholder for createRequest
    /// - Returns: Nothing
    func createRequest() -> Request {
        fatalError("You must implement createRequest() if you use the default run(with:)!")
    }
    
    /// Prints the JSON response
    /// - Parameter response: Response from server
    func printJson(for response: Request.Response) {
        let data = try! UTMAPI.encode(response)
        let json = String(data: data, encoding: .utf8)!
        print(json)
    }
    
    /// Default placeholder for printResponse
    /// - Parameter response: Response to print
    func printResponse(_ response: Request.Response) {
        fatalError("You must implement printResponse() if you use the default run(with:)!")
    }
}

extension UTMCtl {
    struct List: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Enumerate all registered virtual machines."
        )
        
        @OptionGroup var environment: EnvironmentOptions
    }
}

extension UTMCtl {
    struct Status: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Query the status of a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
    }
}

extension UTMCtl {
    struct Start: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Start running a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
    }
}

extension UTMCtl {
    struct Suspend: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Suspend running a virtual machine."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
    }
}

extension UTMCtl {
    struct Stop: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Shuts down a virtual machine."
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
    }
}

extension UTMCtl {
    struct Attach: UTMAPICommand {
        static var configuration = CommandConfiguration(
            abstract: "Redirect the serial input/output to this terminal."
        )
        
        @OptionGroup var environment: EnvironmentOptions
        
        @OptionGroup var identifer: VMIdentifier
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
        
        @Flag(name: .shortAndLong, help: "Output results in JSON.")
        var machineReadable: Bool = false
        
        @Option(help: "Specify a custom path to the UTM API server socket.")
        var socketPath: String?
    }
}

private extension String {
    var asFileURL: URL {
        URL(fileURLWithPath: self, relativeTo: nil)
    }
}
