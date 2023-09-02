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

import SwiftUI

struct VMReleaseNotesView: View {
    @ObservedObject var helper: UTMReleaseHelper
    @State private var isShowAll: Bool = false
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    let ignoreSections = ["Highlights", "Installation"]
    
    var body: some View {
        VStack {
            if helper.releaseNotes.count > 0 {
                ScrollView {
                    Text("What's New")
                        .font(.largeTitle)
                        .padding(.bottom)
                    VStack(alignment: .leading) {
                        Notes(section: helper.releaseNotes.first!, isProminent: true)
                            .padding(.bottom, 0.5)
                        if isShowAll {
                            ForEach(helper.releaseNotes) { section in
                                if !ignoreSections.contains(section.title) {
                                    Notes(section: section)
                                }
                            }
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("No release notes found for version \(helper.currentVersion).")
                            .font(.headline)
                        Spacer()
                    }
                    Spacer()
                }
            }
            Spacer()
            Buttons {
                if !isShowAll {
                    Button {
                        isShowAll = true
                    } label: {
                        Text("Show All")
                        #if os(iOS) || os(visionOS)
                            .frame(maxWidth: .infinity)
                        #endif
                    }.buttonStyle(ReleaseButtonStyle())
                }
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Continue")
                    #if os(iOS) || os(visionOS)
                        .frame(maxWidth: .infinity)
                    #endif
                }.keyboardShortcut(.defaultAction)
                .buttonStyle(ReleaseButtonStyle(isProminent: true))
            }
        }
        #if os(macOS) || os(visionOS)
        .frame(width: 450, height: 450)
        #endif
        .onAppear {
            if helper.releaseNotes.count == 0 {
                isShowAll = true
            } else if helper.releaseNotes.first!.body.count == 0 {
                isShowAll = true
            }
        }
    }
}

private struct Notes: View {
    let section: UTMReleaseHelper.Section
    @State var isProminent: Bool = false
    
    private var hasBullet: Bool {
        !isProminent && section.body.count > 1
    }
    
    var body: some View {
        if !isProminent {
            Text(section.title)
                .font(.title2)
                .padding([.top, .bottom])
        }
        ForEach(section.body) { description in
            HStack(alignment: .top) {
                if hasBullet {
                    Text("\u{2022} ")
                }
                if #available(iOS 15, macOS 12, *), let attributed = try? AttributedString(markdown: description) {
                    Text(attributed)
                } else {
                    Text(description)
                }
            }
        }
    }
}

private struct Buttons<Content>: View where Content: View {
    var content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        #if os(macOS)
        HStack {
            Spacer()
            content()
        }
        #else
        VStack {
            if #available(iOS 15, *) {
                content()
                    .buttonStyle(.bordered)
            } else {
                content()
            }
        }
        #endif
    }
}

private struct ReleaseButtonStyle: PrimitiveButtonStyle {
    private let isProminent: Bool
    private let backgroundColor: Color
    private let foregroundColor: Color
    
    init(isProminent: Bool = false) {
        self.isProminent = isProminent
        self.backgroundColor = isProminent ? .accentColor : .gray
        self.foregroundColor = isProminent ? .white : .white
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        #if os(macOS) || os(visionOS)
        DefaultButtonStyle().makeBody(configuration: configuration)
        #else
        if #available(iOS 15, *) {
            if isProminent {
                BorderedProminentButtonStyle().makeBody(configuration: configuration)
            } else {
                BorderedButtonStyle().makeBody(configuration: configuration)
            }
        } else {
            DefaultButtonStyle().makeBody(configuration: configuration)
                .padding()
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(foregroundColor, lineWidth: 1)
                )
        }
        #endif
    }
}

struct VMReleaseNotesView_Previews: PreviewProvider {
    static var previews: some View {
        VMReleaseNotesView(helper: UTMReleaseHelper())
    }
}
