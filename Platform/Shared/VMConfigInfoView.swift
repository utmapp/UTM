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

private enum IconStyle: String, Identifiable, CaseIterable {
    case generic
    case operatingSystem
    case custom
    
    var text: Text {
        get {
            switch self {
            case .generic: return Text("Generic");
            case .operatingSystem: return Text("Operating System")
            case .custom: return Text("Custom")
            }
        }
    }
    
    var id: String { get { self.rawValue } }
}

struct VMConfigInfoView: View {
    @Binding var config: UTMConfigurationInfo
    @State private var imageSelectVisible: Bool = false
    @State private var iconStyle: IconStyle = .generic
    @State private var warningMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if os(macOS)
            HStack {
                Text("Name").frame(width: 50, alignment: .trailing)
                nameField
            }
            HStack(alignment: .top) {
                Text("Notes").frame(width: 50, alignment: .trailing)
                notesField
            }
            HStack {
                Text("Icon").frame(width: 50, alignment: .trailing)
                iconSelector
                    .aspectRatio(1, contentMode: .fill)
                iconStylePicker
            }
            #else
            Form {
                Section(header: Text("Name")) {
                    nameField
                }
                Section(header: Text("Notes")) {
                    notesField
                }
                Section(header: Text("Icon")) {
                    iconStylePicker
                    iconSelector
                }
            }
            #endif
        }.onAppear {
            if config.isIconCustom {
                iconStyle = .custom
            } else if config.iconURL != nil {
                iconStyle = .operatingSystem
            }
        }.alert(item: $warningMessage) { warning in
            Alert(title: Text(warning))
        }.disableAutocorrection(true)
    }

    private var nameField: some View {
        TextField("Name", text: $config.name)
            .keyboardType(.asciiCapable)
            .lineLimit(1)
    }

    private var notesField: some View {
        TextEditor(text: $config.notes.bound)
            #if os(macOS)
            .border(Color.primary, width: 0.5)
            #endif
            .frame(minHeight: 200)
    }

    @ViewBuilder
    private var iconStylePicker: some View {
        let style = Binding<IconStyle> {
            return iconStyle
        } set: {
            iconStyle = $0
            config.isIconCustom = false
            config.iconURL = nil
        }

        Picker(selection: style.animation(), label: Text("Style")) {
            ForEach(IconStyle.allCases, id: \.rawValue) { value in
                value.text
                    .tag(value)
            }
        }
        #if os(macOS)
        .pickerStyle(.radioGroup)
        .labelsHidden()
        #endif
    }

    @ViewBuilder
    private var iconSelector: some View {
        switch iconStyle {
        case .custom:
            #if os(macOS)
            VStack {
                IconPreview(url: config.iconURL)
                    .onTapGesture {
                        imageSelectVisible.toggle()
                    }
                Button(action: { imageSelectVisible.toggle() }, label: {
                    Text("Choose")
                }).fileImporter(isPresented: $imageSelectVisible, allowedContentTypes: [.image]) { result in
                    switch result {
                    case .success(let url):
                        imageCustomSelected(url: url)
                    case .failure:
                        break
                    }
                }
            }
            .frame(width: 90)
            #else
            Button(action: { imageSelectVisible.toggle() }, label: {
                IconPreview(url: config.iconURL)
            }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                ImagePicker(onImageSelected: imageCustomSelected)
            }.buttonStyle(.plain)
            #endif
        case .operatingSystem:
            #if os(macOS)
            VStack {
                IconPreview(url: config.iconURL)
                    .onTapGesture {
                        imageSelectVisible.toggle()
                    }
                Button(action: { imageSelectVisible.toggle() }, label: {
                    Text("Choose")
                }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                    IconSelect(current: config.iconURL, onIconSelected: imageSelected)
                }
            }
            .frame(width: 90)
            #else
            IconSelect(current: config.iconURL, onIconSelected: imageSelected)
            #endif
        default:
            #if os(macOS)
            VStack {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .foregroundColor(Color(NSColor.disabledControlTextColor))
                Button {} label: {
                    Text("Choose")
                }.disabled(true)
            }
            .frame(width: 90)
            #else
            EmptyView()
            #endif
        }
    }
    
    private func imageCustomSelected(url: URL?) {
        if let imageURL = url {
            config.iconURL = imageURL
            config.isIconCustom = true
        }
        imageSelectVisible = false
    }
    
    private func imageSelected(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        config.iconURL = UTMConfigurationInfo.builtinIcon(named: name)
        config.isIconCustom = false
        imageSelectVisible = false
    }
}

private struct IconPreview: View {
    let url: URL?
    
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    var body: some View {
        HStack {
            #if !os(macOS)
            Spacer()
            #endif
            Logo(logo: PlatformImage(contentsOfURL: url))
            #if !os(macOS)
            Spacer()
            #endif
        }
    }
}

#if os(macOS)
let iconGridSize: CGFloat = 80
#else
let iconGridSize: CGFloat = 100
#endif

private struct IconSelect: View {
    let current: URL?
    let onIconSelected: (URL) -> Void
    private let gridLayout = [GridItem(.adaptive(minimum: iconGridSize))]
    private var icons: [URL] {
        let paths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: "Icons")
        let urls = paths.map({ URL(fileURLWithPath: $0) })
        return urls.sorted { urlA, urlB in
            urlA.lastPathComponent < urlB.lastPathComponent
        }
    }
    
    #if os(macOS)

    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    struct IconSelectModifier: ViewModifier {
        @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
        
        func body(content: Content) -> some View {
    #if os(macOS)
            return AnyView(
                ScrollView {
                    content.padding(16)
                }.frame(width: 480, height: 400)
            )
    #else
            return AnyView(content)
    #endif
        }
    }
    
    var body: some View {
        LazyVGrid(columns: gridLayout, spacing: 0) {
            ForEach(icons, id: \.self) { icon in
                Button(action: { onIconSelected(icon) }, label: {
                    VStack(alignment: .center) {
                        Logo(logo: PlatformImage(contentsOfURL: icon))
                        Text(iconToTitle(icon))
                            .lineLimit(2, optionalReservesSpace: true)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .padding(8)
                    .frame(width: iconGridSize, height: iconGridSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(current == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }).buttonStyle(.plain)
            }
        }.modifier(IconSelectModifier())
    }
}

private extension View {
    @ViewBuilder
    func lineLimit(_ limit: Int, optionalReservesSpace: Bool) -> some View {
        if #available(macOS 13, iOS 16, *) {
            self.lineLimit(limit, reservesSpace: optionalReservesSpace)
        } else {
            self.lineLimit(limit)
        }
    }
}

struct VMConfigInfoView_Previews: PreviewProvider {
    @State static private var config = UTMConfigurationInfo()
    
    static var previews: some View {
        Group {
            VMConfigInfoView(config: $config)
                #if os(macOS)
                .scrollable()
                #endif
            IconSelect(current: nil) { _ in
                
            }
        }
    }
}

private func iconToTitle(_ icon: URL?) -> LocalizedStringKey {
    guard let fileName = icon?.deletingPathExtension().lastPathComponent else {
        return "Custom"
    }
    return ICON_TITLE_MAP[fileName] ?? "Custom"
}

private let ICON_TITLE_MAP: [String: LocalizedStringKey] = [
    "AIX": "AIX",
    "IOS": "iOS",
    "Windows7": "Windows 7",
    "almalinux": "AlmaLinux",
    "alpine": "Alpine",
    "amigaos": "AmigaOS",
    "android": "Android",
    "apple-tv": "Apple TV",
    "arch-linux": "Arch Linux",
    "backtrack": "BackTrack",
    "bada": "Bada",
    "beos": "BeOS",
    "centos": "CentOS",
    "chrome-os": "Chrome OS",
    "cyanogenmod": "CyanogenMod",
    "debian": "Debian",
    "elementary-os": "Elementary OS",
    "fedora": "Fedora",
    "firefox-os": "Firefox OS",
    "freebsd": "FreeBSD",
    "gentoo": "Gentoo",
    "haiku-os": "Haiku OS",
    "hp-ux": "HP-UX",
    "kaios": "KaiOS",
    "knoppix": "Knoppix",
    "kubuntu": "Kubuntu",
    "linux": "Linux",
    "lubuntu": "Lubuntu",
    "mac": "macOS",
    "maemo": "Maemo",
    "mandriva": "Mandriva",
    "meego": "MeeGo",
    "mint": "Linux Mint",
    "netbsd": "NetBSD",
    "nintendo": "Nintendo",
    "nixos": "NixOS",
    "openbsd": "OpenBSD",
    "openwrt": "OpenWrt",
    "os2": "OS/2",
    "palmos": "Palm OS",
    "playstation-portable": "PlayStation Portable",
    "playstation": "PlayStation",
    "pop-os": "Pop!_OS",
    "red-hat": "Red Hat",
    "remix-os": "Remix OS",
    "risc-os": "RISC OS",
    "rocky-linux": "Rocky Linux",
    "sabayon": "Sabayon",
    "sailfish-os": "Sailfish OS",
    "slackware": "Slackware",
    "solaris": "Solaris",
    "suse": "openSUSE",
    "syllable": "Syllable",
    "symbian": "Symbian",
    "threadx": "ThreadX",
    "tizen": "Tizen",
    "ubuntu": "Ubuntu",
    "webos": "webOS",
    "windows-11": "Windows 11",
    "windows-9x": "Windows 9x",
    "windows-xp": "Windows XP",
    "windows": "Windows",
    "xbox": "Xbox",
    "xubuntu": "Xubuntu",
    "yunos": "YunOS",
    "pardus": "Pardus"
]
