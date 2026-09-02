//
// Copyright © 2020 osy. All rights reserved.
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

import Logging
import TipKit

let logger = Logger(label: "com.utmapp.UTM") { label in
    var utmLogger = UTMLoggingSwift(label: label)
    var stdOutLogger = StreamLogHandler.standardOutput(label: label)
    #if DEBUG
    utmLogger.logLevel = .debug
    stdOutLogger.logLevel = .debug
    #endif
    return MultiplexLogHandler([
        utmLogger,
        stdOutLogger
    ])
}

func readChannelLines(buf: DispatchData, channel: DispatchIO, handleMsg: @escaping (String) -> (), eof: @escaping () -> ()) {
    channel.read(offset: 0, length: 1, queue: .global()) { _, data, error in
        if(error != 0) { return print(error) }
        // this will be what e.g. ^D will send.
        if(data!.isEmpty) {
            return eof()
        }
        let char = data!.withUnsafeBytes { $0[0] as Int8 }
        var buf_ = buf
        // \r or \n
        if(char == 10 || char == 13) {
            if(!buf_.isEmpty) {
                let msg = buf_.withUnsafeBytes { String(utf8String: $0) }
                handleMsg(msg!)
                buf_ = DispatchData.empty
            }
        } else {
            buf_.append(data!)
        }
        readChannelLines(buf: buf_, channel: channel, handleMsg: handleMsg, eof: eof)
    }
}

@main
class Main {
    static var jitAvailable = true
    
    static func main() {
        #if (os(iOS) || os(visionOS)) && WITH_JIT
        // check if we have jailbreak
        if jb_spawn_ptrace_child(CommandLine.argc, CommandLine.unsafeArgv) {
            logger.info("JIT: ptrace() child spawn trick")
        } else if jb_has_jit_entitlement() {
            logger.info("JIT: found entitlement")
        } else if jb_has_cs_disabled() {
            logger.info("JIT: CS_KILL disabled")
        } else if jb_has_cs_execseg_allow_unsigned() {
            logger.info("JIT: CS_EXECSEG_ALLOW_UNSIGNED set")
        } else if jb_enable_ptrace_hack() {
            logger.info("JIT: ptrace() hack supported")
        } else {
            logger.info("JIT: ptrace() hack failed")
            jitAvailable = false
        }
        // raise memlimits on jailbroken devices
        if jb_increase_memlimit() {
            logger.info("MEM: successfully removed memory limits")
        }
        #endif
        // do patches
        UTMPatches.patchAll()
        #if os(iOS) || os(visionOS)
        // register defaults
        registerDefaultsFromSettingsBundle()
        // register tips
        if #available(iOS 17, macOS 14, *) {
            try? Tips.configure()
        }
        #endif
        if CommandLine.arguments.contains("--with-socket") {
            let socketQueue = DispatchQueue(label: "socket", qos: .background, attributes: .concurrent)
            let prompt = "UTM> "
            func writeMsg(channel: DispatchIO, msg: String) {
                channel.write(offset: 0, data: msg.data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }, queue: socketQueue, ioHandler: { done, data, error in })
            }
            func writeLine(channel: DispatchIO, msg: String) {
                writeMsg(channel: channel, msg: msg.appending("\n"))
            }
            func writePrompt(channel: DispatchIO) {
                writeMsg(channel: channel, msg: prompt)
            }
            socketQueue.async {
                let sock = "utm.socket"
                print(URL(fileURLWithPath: sock))
                try? FileManager.default.removeItem(atPath: sock)
                let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                addr.sun_len = UInt8(sock.utf8CString.count)
                _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                    strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), sock, sock.utf8CString.count)
                }
                var ret: Int32 = 0
                withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ar in
                        ret = bind(fd, ar, socklen_t(MemoryLayout<sockaddr_un>.size))
                    }
                }
                guard ret == 0 else { print("Failed to bind to address"); return }
                listen(fd,1)
                let data: UTMData = UTMData()
                while(true) {
                    var clientaddr = sockaddr_un()
                    var clientlen = socklen_t(MemoryLayout<sockaddr_un>.size)
                    let clientfd = withUnsafeMutablePointer(to: &clientaddr) { addrptr in
                        withUnsafeMutablePointer(to: &clientlen) { lenptr in
                            return accept(fd, UnsafeMutableRawPointer(addrptr).assumingMemoryBound(to: sockaddr.self), lenptr)
                        }
                    }
                    let channel = DispatchIO(type: .stream, fileDescriptor: clientfd, queue: .global()) { error in
                        print("channel error: \(error)")
                    }
                    writePrompt(channel: channel)
                    readChannelLines(buf: DispatchData.empty, channel: channel, handleMsg: { msg in
                        socketQueue.async {
                            let tokens = msg.split(separator: " ")
//                            print("[Debug] \(tokens)")
                            if(!tokens.isEmpty) {
                                let resp: String
                                switch tokens.first! {
                                case "list":
                                    let header = "UUID                                 Status   Name"
                                    let lines = [header] + data.virtualMachines.map {
                                        let status = $0.stateLabel.padding(toLength: 8, withPad: " ", startingAt: 0)
                                        return "\($0.id) \(status) \($0.config.name)"
                                    }
                                    resp = lines.joined(separator: "\n")
                                case "start":
                                    if let vm: UTMVirtualMachine = data.virtualMachines.first(where: { "\($0.id)" == tokens[1] }) {
                                        vm.requestVmStart()
                                        let status = vm.stateLabel.padding(toLength: 8, withPad: " ", startingAt: 0)
                                        resp = "\(vm.id) \(status) \(vm.config.name)"
                                    } else {
                                        resp = "Uknown UUID: \(tokens[1])"
                                    }
                                case "stop":
                                    if let vm: UTMVirtualMachine = data.virtualMachines.first(where: { "\($0.id)" == tokens[1] }) {
                                        vm.requestVmStop()
                                        let status = vm.stateLabel.padding(toLength: 8, withPad: " ", startingAt: 0)
                                        resp = "\(vm.id) \(status) \(vm.config.name)"
                                    } else {
                                        resp = "Uknown UUID: \(tokens[1])"
                                    }
                                default:
                                    resp = "Unknown command: \(tokens.first!)"
                                }
                                writeLine(channel: channel, msg: resp)
                            }
                            writePrompt(channel: channel)
                        }
                    }, eof: { close(clientfd) })
                }
            }
        }
        UTMApp.main()
    }
    
    // https://stackoverflow.com/a/44675628
    static private func registerDefaultsFromSettingsBundle() {
        let userDefaults = UserDefaults.standard

        if let settingsURL = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
            let settings = NSDictionary(contentsOf: settingsURL),
            let preferences = settings["PreferenceSpecifiers"] as? [NSDictionary] {

            var defaultsToRegister = [String: AnyObject]()
            for prefSpecification in preferences {
                if let key = prefSpecification["Key"] as? String,
                    let value = prefSpecification["DefaultValue"] {

                    defaultsToRegister[key] = value as AnyObject
                    logger.debug("registerDefaultsFromSettingsBundle: (\(key), \(value)) \(type(of: value))")
                }
            }
            
            // register version numbers
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
                userDefaults.set(version, forKey: "LastBootedVersion")
            }
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] {
                userDefaults.set(build, forKey: "LastBootedBuild")
            }

            userDefaults.register(defaults: defaultsToRegister)
        } else {
            logger.debug("registerDefaultsFromSettingsBundle: Could not find Settings.bundle")
        }
    }
}
