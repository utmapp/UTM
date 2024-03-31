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

import SwiftUI
import UniformTypeIdentifiers
import Network

extension Optional where Wrapped == String {
    var _bound: String? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
    public var bound: String {
        get {
            return _bound ?? ""
        }
        set {
            _bound = newValue.isEmpty ? nil : newValue
        }
    }
}

extension Optional where Wrapped: FixedWidthInteger {
    var _bound: Wrapped? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
    public var bound: Wrapped {
        get {
            return _bound ?? 0
        }
        set {
            _bound = newValue == 0 ? nil : newValue
        }
    }
}

extension Optional where Wrapped == Bool {
    var _bound: Wrapped? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
    public var bound: Wrapped {
        get {
            return _bound ?? false
        }
        set {
            _bound = newValue
        }
    }
}

extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding {
            !wrappedValue
        } set: { newValue in
            wrappedValue = !newValue
        }
    }
}

extension LocalizedStringKey {
    var localizedString: String {
        let mirror = Mirror(reflecting: self)
        var key: String? = nil
        for property in mirror.children {
            if property.label == "key" {
                key = property.value as? String
            }
        }
        guard let goodKey = key else {
            logger.error("Failed to get localization key")
            return ""
        }
        return NSLocalizedString(goodKey, comment: "LocalizedStringKey")
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension String: Identifiable {
    public var id: String { return self }
}

extension IndexSet: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

extension Array {
    subscript(indicies: IndexSet) -> [Element] {
        get {
            var slice = [Element]()
            for i in indicies {
                slice.append(self[i])
            }
            return slice
        }
    }
}

extension View {
    func onReceive(_ name: Notification.Name,
                   center: NotificationCenter = .default,
                   object: AnyObject? = nil,
                   perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(
            center.publisher(for: name, object: object), perform: action
        )
    }
}

extension UTType {
    static let UTM = UTType(exportedAs: "com.utmapp.utm")
    
    // SwiftUI BUG: exportedAs: "com.utmapp.utm" doesn't work on macOS and older iOS
    static let UTMextension = UTType(exportedAs: "utm")
    
    static let appleLog = UTType(filenameExtension: "log")!

    static let ipsw = UTType(filenameExtension: "ipsw")!
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

extension Color {
    init?(hexString hex: String) {
        if hex.count != 7 { // The '#' included
            return nil
        }
            
        let hexColor = String(hex.dropFirst())
        
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        
        if !scanner.scanHexInt64(&hexNumber) {
            return nil
        }
        
        let r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000ff) / 255
        
        self.init(.displayP3, red: r, green: g, blue: b, opacity: 1.0)
    }
}

extension CGColor {
    var hexString: String? {
        hexString(for: .init(name: CGColorSpace.displayP3)!)
    }
    
    var sRGBhexString: String? {
        hexString(for: .init(name: CGColorSpace.sRGB)!)
    }
    
    private func hexString(for colorSpace: CGColorSpace) -> String? {
        guard let rgbColor = self.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let components = rgbColor.components else {
            return nil
        }
        let red = Int(round(components[0] * 0xFF))
        let green = Int(round(components[1] * 0xFF))
        let blue = Int(round(components[2] * 0xFF))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

#if !os(macOS)
@objc extension UIView {
    /// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
    /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
    func bindFrameToSuperviewBounds() {
        guard let superview = self.superview else {
            print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
            return
        }

        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true

    }
}

extension UIImage {
    convenience init?(contentsOfURL: URL?) {
        if let url = contentsOfURL {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            self.init(contentsOfFile: url.path)
        } else {
            return nil
        }
    }
}

// Only used in hterm support
@objc extension UIColor {
    convenience init?(hexString hex: String?) {
        guard let hex = hex else {
            return nil
        }
        if hex.count != 7 { // The '#' included
            return nil
        }
            
        let hexColor = String(hex.dropFirst())
        
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        
        if !scanner.scanHexInt64(&hexNumber) {
            return nil
        }
        
        let r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000ff) / 255
        
        self.init(displayP3Red: r, green: g, blue: b, alpha: 1.0)
    }
    
    var sRGBhexString: String? {
        cgColor.sRGBhexString
    }
}
#endif

#if canImport(AppKit)
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
typealias PlatformImage = UIImage
#endif

#if os(macOS)
enum FakeKeyboardType : Int {
    case asciiCapable
    case decimalPad
    case numberPad
}

struct EditButton {
    
}

extension View {
    func keyboardType(_ type: FakeKeyboardType) -> some View {
        return self
    }
    
    func navigationBarItems(trailing: EditButton) -> some View {
        return self
    }
}

extension NSImage {
    convenience init?(contentsOfURL: URL?) {
        if let url = contentsOfURL {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            self.init(contentsOf: url)
        } else {
            return nil
        }
    }
}
#endif

@propertyWrapper
struct Setting<T> {
    private(set) var keyName: String
    private var defaultValue: T
    
    var wrappedValue: T {
        get {
            let defaults = UserDefaults.standard
            guard let value = defaults.value(forKey: keyName) else {
                return defaultValue
            }
            return value as! T
        }
        
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: keyName)
        }
    }
    
    init(wrappedValue: T, _ keyName: String) {
        self.defaultValue = wrappedValue
        self.keyName = keyName
    }
}

// MARK: - Bookmark handling
extension URL {
    private static var defaultCreationOptions: BookmarkCreationOptions {
        #if os(iOS) || os(visionOS)
        return .minimalBookmark
        #else
        return .withSecurityScope
        #endif
    }
    
    private static var defaultResolutionOptions: BookmarkResolutionOptions {
        #if os(iOS) || os(visionOS)
        return []
        #else
        return .withSecurityScope
        #endif
    }
    
    func persistentBookmarkData(isReadyOnly: Bool = false) throws -> Data {
        var options = Self.defaultCreationOptions
        #if os(macOS)
        if isReadyOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        #endif
        let scopedAccess = startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                stopAccessingSecurityScopedResource()
            }
        }
        return try self.bookmarkData(options: options,
                                     includingResourceValuesForKeys: nil,
                                     relativeTo: nil)
    }
    
    init(resolvingPersistentBookmarkData bookmark: Data) throws {
        var stale: Bool = false
        try self.init(resolvingBookmarkData: bookmark,
                      options: Self.defaultResolutionOptions,
                      bookmarkDataIsStale: &stale)
    }
}

extension String {
    func integerPrefix() -> Int? {
        var numeric = ""
        for char in self {
            if !char.isNumber {
                break
            }
            numeric.append(char)
        }
        return Int(numeric)
    }

    static func random(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
}

extension Encodable {
    func propertyList() throws -> Any {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let xml = try encoder.encode(self)
        return try PropertyListSerialization.propertyList(from: xml, format: nil)
    }
}

extension Decodable {
    init(fromPropertyList propertyList: Any) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: propertyList, format: .xml, options: 0)
        let decoder = PropertyListDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
}

extension NWEndpoint {
    var hostname: String? {
        if case .hostPort(let host, _) = self {
            switch host {
            case .name(let hostname, _):
                return hostname
            case .ipv4(let address):
                return "\(address)"
            case .ipv6(let address):
                return "\(address)"
            @unknown default:
                break
            }
        }
        return nil
    }
}
