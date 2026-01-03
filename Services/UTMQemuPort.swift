//
// Copyright © 2023 osy. All rights reserved.
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

import QEMUKitInternal
#if !WITH_USB
import CocoaSpiceNoUsb
#else
import CocoaSpice
#endif

@objc class UTMQemuPort: NSObject, QEMUPort {
    var readDataHandler: readDataHandler_t? {
        didSet {
            portDataQueue.async { [self] in
                if let _cachedData = cachedData {
                    readDataHandler?(_cachedData)
                    cachedData = nil
                }
            }
        }
    }
    
    var errorHandler: errorHandler_t? {
        didSet {
            portDataQueue.async { [self] in
                if let _cachedError = cachedError {
                    errorHandler?(_cachedError)
                    cachedError = nil
                }
            }
        }
    }
    
    var disconnectHandler: disconnectHandler_t? {
        didSet {
            portDataQueue.async { [self] in
                if !isOpen {
                    disconnectHandler?()
                }
            }
        }
    }
    
    var isOpen: Bool = true
    
    private let port: CSPort

    private let portDataQueue = DispatchQueue(label: "UTM Port Data Queue")
    private var cachedError: String?
    private var cachedData: Data?

    func write(_ data: Data) {
        port.write(data)
    }
    
    @objc init(from port: CSPort) {
        self.port = port
        super.init()
        port.delegate = self
    }
}

extension UTMQemuPort: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
        portDataQueue.async { [self] in
            isOpen = false
            disconnectHandler?()
        }
    }
    
    func port(_ port: CSPort, didError error: String) {
        portDataQueue.async { [self] in
            if let errorHandler = errorHandler {
                errorHandler(error)
            } else {
                cachedError = error
            }
        }
    }
    
    func port(_ port: CSPort, didRecieveData data: Data) {
        portDataQueue.async { [self] in
            if let readDataHandler = readDataHandler {
                readDataHandler(data)
            } else {
                cachedData = data
            }
        }
    }
}
