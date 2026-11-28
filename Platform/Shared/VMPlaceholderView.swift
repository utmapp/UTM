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

struct VMPlaceholderView: View {
    var body: some View {
        #if os(macOS)
        if #available(macOS 26, *) {
            VMPlaceholderViewMac()
        } else {
            legacyBody
        }
        #else
        legacyBody
        #endif
    }

    @ViewBuilder private var legacyBody: some View {
        if #available(iOS 16, macOS 13, *) {
            VMPlaceholderViewNew()
        } else {
            VMPlaceholderViewOld()
        }
    }
}

#if os(macOS)
/// Welcome view in the style of macOS 26: the two main actions as standard buttons and the
/// secondary ones as links, instead of the tiles shared with iOS.
@available(macOS 26, *)
fileprivate struct VMPlaceholderViewMac: View {
    @EnvironmentObject private var data: UTMData
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Title()
            }
            VStack(spacing: 10) {
                Button {
                    data.newVM()
                } label: {
                    Text(String.create)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(UTMAccessibilityID.Welcome.create)
                Button {
                    NotificationCenter.default.post(name: NSNotification.OpenVirtualMachine, object: nil)
                } label: {
                    Text(String.open)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(UTMAccessibilityID.Welcome.open)
            }
            .controlSize(.large)
            .frame(minWidth: 260)
            .fixedSize()
            HStack(spacing: 20) {
                Button(String.guide, systemImage: "book") {
                    openURL(URL(string: "https://docs.getutm.app/basics/basics/")!)
                }
                .accessibilityIdentifier(UTMAccessibilityID.Welcome.guide)
                Button(String.support, systemImage: "questionmark.circle") {
                    openURL(URL(string: "https://docs.getutm.app/")!)
                }
                .accessibilityIdentifier(UTMAccessibilityID.Welcome.support)
                Button(String.server, systemImage: "server.rack") {
                    openWindow(id: "server")
                }
                .accessibilityIdentifier(UTMAccessibilityID.Welcome.server)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

fileprivate struct VMPlaceholderViewOld: View {
    var body: some View {
        VStack {
            Title()
            HStack {
                FirstRow()
            }
            HStack {
                SecondRow()
            }
        }
    }
}

@available(iOS 16, macOS 13, *)
fileprivate struct VMPlaceholderViewNew: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            Title()
            Grid {
                GridRow {
                    FirstRow()
                }
                GridRow {
                    SecondRow()
                }
                #if os(macOS)
                GridRow {
                    TileButton(Label(String.server, systemImage: "server.rack"), width: nil, height: 50, compact: true) {
                        openWindow(id: "server")
                    }
                    .gridCellColumns(2)
                    .gridCellUnsizedAxes(.horizontal)
                }
                #endif
            }
        }
    }
}

fileprivate struct Title: View {
    var body: some View {
        HStack {
            Text("Welcome to UTM").font(.title)
        }
    }
}

fileprivate struct FirstRow: View {
    @EnvironmentObject private var data: UTMData

    var body: some View {
        TileButton(Label(String.create, systemImage: "plus.circle")) {
            data.newVM()
        }
        TileButton(Label(String.open, systemImage: "doc.circle")) {
            NotificationCenter.default.post(name: NSNotification.OpenVirtualMachine, object: nil)
        }
    }
}

fileprivate struct SecondRow: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        TileButton(Label(String.guide, systemImage: "book.circle")) {
            openURL(URL(string: "https://docs.getutm.app/basics/basics/")!)
        }
        TileButton(Label(String.support, systemImage: "questionmark.circle")) {
            openURL(URL(string: "https://docs.getutm.app/")!)
        }
    }
}

fileprivate extension String {
    static let create = NSLocalizedString("Create a New Virtual Machine", comment: "Welcome view")
    static let open = NSLocalizedString("Open Existing Virtual Machine", comment: "Welcome view")
    static let guide = NSLocalizedString("User Guide", comment: "Welcome view")
    static let support = NSLocalizedString("Support", comment: "Welcome view")
    static let server = NSLocalizedString("Server", comment: "Server view")
}

private struct TileButton: View {
    let label: Label<Text, Image>
    let width: CGFloat?
    let height: CGFloat?
    let compact: Bool
    let action: () -> Void
    
    init(_ label: Label<Text, Image>, width: CGFloat? = 150, height: CGFloat? = 150, compact: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.action = action
        self.width = width
        self.height = height
        self.compact = compact
    }
    
    var body: some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            Button(action: action, label: {
                if compact {
                    label
                        .frame(minWidth: width, maxWidth: .infinity, minHeight: height)
                } else {
                    label
                        .labelStyle(TileLabelStyle())
                        .frame(width: width, height: height)
                }
            })
            .buttonStyle(.bordered)
            .buttonSizing(.fitted)
            .buttonBorderShape(.roundedRectangle)
        } else {
            Button(action: action, label: {
                if compact {
                    label
                } else {
                    label
                        .labelStyle(TileLabelStyle())
                }
            }).buttonStyle(BigButtonStyle(width: width, height: height))
        }
    }
}


private struct TileLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
                .font(.system(size: 48.0, weight: .medium))
                .padding(.bottom)
            configuration.title
                .lineLimit(nil)
                .multilineTextAlignment(.center)
        }
    }
}

struct VMPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        VMPlaceholderView()
    }
}
