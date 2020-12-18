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

#if canImport(UIKit)
import UIKit
import MobileCoreServices
typealias SystemPasteboard = UIPasteboard
typealias SystemPasteboardType = String
#elseif canImport(AppKit)
import AppKit
typealias SystemPasteboard = NSPasteboard
typealias SystemPasteboardType = NSPasteboard.PasteboardType
#else
#error("Neither UIKit nor AppKit found!")
#endif

@objc class UTMPasteboard: NSObject {
    @objc(UTMPasteboardType) enum PasteboardType: Int {
        case URL
        case bmp
        case fileURL
        case font
        case html
        case jpg
        case pdf
        case png
        case rtf
        case rtfd
        case sound
        case string
        case tabularText
        case tiff
    }
    
    @objc(generalPasteboard)
    static let general = UTMPasteboard(for: SystemPasteboard.general)
    
    private(set) var changeCount: Int
    fileprivate let systemPasteboard: SystemPasteboard
    private var timer: Timer?
    private var listeners = Set<AnyHashable>()
    
    private init(for systemPasteboard: SystemPasteboard) {
        self.systemPasteboard = systemPasteboard
        self.changeCount = systemPasteboard.changeCount
    }
    
    @nonobjc func requestPollingMode<T>(forHashable hashable: T) where T: Hashable {
        if listeners.isEmpty {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.onTimerTick()
            }
        }
        _ = listeners.insert(hashable)
    }
    
    @objc func requestPollingMode(forObject object: AnyHashable) {
        requestPollingMode(forHashable: object)
    }
    
    @nonobjc func releasePollingMode<T>(forHashable hashable: T) where T: Hashable {
        _ = listeners.remove(hashable)
        if listeners.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc func releasePollingMode(forObject object: AnyHashable) {
        releasePollingMode(forHashable: object)
    }
    
    private func onTimerTick() {
        let newCount = systemPasteboard.changeCount
        if newCount > changeCount {
            if hasContents() {
                NotificationCenter.default.post(name: .pasteboardChangedNotification, object: self)
            } else {
                NotificationCenter.default.post(name: .pasteboardRemovedNotification, object: self)
            }
        }
        changeCount = newCount
    }
}

#if canImport(UIKit)
extension UTMPasteboard.PasteboardType: RawRepresentable {
    typealias RawValue = String
    
    init?(rawValue: String) {
        let cfValue = rawValue as CFString
        switch cfValue {
        case kUTTypeURL: self = .URL
        case kUTTypeBMP: self = .bmp
        case kUTTypeFileURL: self = .fileURL
        case kUTTypeFont: self = .font
        case kUTTypeHTML: self = .html
        case kUTTypeJPEG: self = .jpg
        case kUTTypeJPEG2000: self = .jpg
        case kUTTypePDF: self = .pdf
        case kUTTypePNG: self = .png
        case kUTTypeRTF: self = .rtf
        case kUTTypeRTFD: self = .rtfd
        case kUTTypeFlatRTFD: self = .rtfd
        case kUTTypeWaveformAudio: self = .sound
        case kUTTypePlainText: self = .string
        case kUTTypeUTF8PlainText: self = .string
        case kUTTypeTabSeparatedText: self = .tabularText
        case kUTTypeUTF8TabSeparatedText: self = .tabularText
        case kUTTypeTIFF: self = .tiff
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .URL: return kUTTypeURL as String
        case .bmp: return kUTTypeBMP as String
        case .fileURL: return kUTTypeFileURL as String
        case .font: return kUTTypeFont as String
        case .html: return kUTTypeHTML as String
        case .jpg: return kUTTypeJPEG as String
        case .pdf: return kUTTypePDF as String
        case .png: return kUTTypePNG as String
        case .rtf: return kUTTypeRTF as String
        case .rtfd: return kUTTypeRTFD as String
        case .sound: return kUTTypeWaveformAudio as String
        case .string: return kUTTypeUTF8PlainText as String
        case .tabularText: return kUTTypeUTF8TabSeparatedText as String
        case .tiff: return kUTTypeTIFF as String
        }
    }
}

@objc extension UTMPasteboard {
    func hasContents() -> Bool {
        return systemPasteboard.types.count > 0
    }
    
    func clearContents() {
        changeCount += 1
        systemPasteboard.items = []
    }
    
    func setData(_ data: Data, forType dataType: PasteboardType) {
        clearContents()
        changeCount += 1
        systemPasteboard.setData(data, forPasteboardType: dataType.rawValue)
    }
    
    func data(forType dataType: PasteboardType) -> Data? {
        return systemPasteboard.data(forPasteboardType: dataType.rawValue)
    }
    
    func setString(_ string: String, forType dataType: PasteboardType) {
        clearContents()
        changeCount += 1
        systemPasteboard.setValue(string, forPasteboardType: dataType.rawValue)
    }
    
    func setString(_ string: String) {
        setString(string, forType: .string)
    }
    
    func string(forType dataType: PasteboardType) -> String? {
        return systemPasteboard.value(forPasteboardType: dataType.rawValue) as? String
    }
    
    func string() -> String? {
        return string(forType: .string)
    }
    
    func canReadItem(forType dataType: PasteboardType) -> Bool {
        let types = systemPasteboard.types
        return types.contains(dataType.rawValue)
    }
}
#elseif canImport(AppKit)
extension UTMPasteboard.PasteboardType: RawRepresentable {
    typealias RawValue = NSPasteboard.PasteboardType
    
    init?(rawValue: NSPasteboard.PasteboardType) {
        switch rawValue {
        case .URL: self = .URL
        case .fileURL: self = .fileURL
        case .font: self = .font
        case .html: self = .html
        case .pdf: self = .pdf
        case .png: self = .png
        case .rtf: self = .rtf
        case .rtfd: self = .rtfd
        case .sound: self = .sound
        case .string: self = .string
        case .tabularText: self = .tabularText
        case .tiff: self = .tiff
        default: return nil
        }
    }
    
    var rawValue: NSPasteboard.PasteboardType {
        switch self {
        case .URL: return .URL
        case .bmp: return .fileURL
        case .fileURL: return .fileURL
        case .font: return .font
        case .html: return .html
        case .jpg: return .fileURL
        case .pdf: return .pdf
        case .png: return .png
        case .rtf: return .rtf
        case .rtfd: return .rtfd
        case .sound: return .sound
        case .string: return .string
        case .tabularText: return .tabularText
        case .tiff: return .tiff
        }
    }
}

@objc extension UTMPasteboard {
    func hasContents() -> Bool {
        if let types = systemPasteboard.types {
            return types.count > 0
        } else {
            return false
        }
    }
    
    func clearContents() {
        changeCount += 1
        _ = systemPasteboard.clearContents()
    }
    
    func setData(_ data: Data, forType dataType: PasteboardType) {
        clearContents()
        changeCount += 1
        _ = systemPasteboard.setData(data, forType: dataType.rawValue)
    }
    
    func data(forType dataType: PasteboardType) -> Data? {
        return systemPasteboard.data(forType: dataType.rawValue)
    }
    
    func setString(_ string: String, forType dataType: PasteboardType) {
        clearContents()
        changeCount += 1
        _ = systemPasteboard.setString(string, forType: dataType.rawValue)
    }
    
    func setString(_ string: String) {
        setString(string, forType: .string)
    }
    
    func string(forType dataType: PasteboardType) -> String? {
        return systemPasteboard.string(forType: dataType.rawValue)
    }
    
    func string() -> String? {
        return string(forType: .string)
    }
    
    func canReadItem(forType dataType: PasteboardType) -> Bool {
        guard let types = systemPasteboard.types else {
            return false
        }
        return types.contains(dataType.rawValue)
    }
}
#endif

extension NSNotification.Name {
    public static let pasteboardChangedNotification: NSNotification.Name = .init(rawValue: "utmPasteboardChangedNotification")
    public static let pasteboardRemovedNotification: NSNotification.Name = .init(rawValue: "utmPasteboardRemovedNotification")
}

@objc extension UTMPasteboard {
    public static let changedNotification = NSNotification.Name.pasteboardChangedNotification
    public static let removedNotification = NSNotification.Name.pasteboardRemovedNotification
}
