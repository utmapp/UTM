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

@MainActor
class UTMReleaseHelper: ObservableObject {
    struct Section: Identifiable {
        var title: String = ""
        var body: [String] = []
        
        let id: UUID = UUID()
        
        var isEmpty: Bool {
            title.isEmpty && body.isEmpty
        }
    }
    
    private enum ReleaseError: Error {
        case fetchFailed
    }
    
    @Setting("ReleaseNotesLastVersion") private var releaseNotesLastVersion: String? = nil
    
    @Published var isReleaseNotesShown: Bool = false
    @Published var releaseNotes: [Section] = []
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    func fetchReleaseNotes(force: Bool = false) async {
        guard force || releaseNotesLastVersion != currentVersion else {
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["Accept": "application/vnd.github+json",
                                               "X-GitHub-Api-Version": "2022-11-28"]
        let session = URLSession(configuration: configuration)
        let url = "https://api.github.com/repos/utmapp/UTM/releases/tags/v\(currentVersion)"
        do {
            try await Task.detached(priority: .utility) {
                let (data, _) = try await session.data(from: URL(string: url)!)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let body = json["body"] as? String {
                    await self.parseReleaseNotes(body)
                } else {
                    throw ReleaseError.fetchFailed
                }
            }.value
        } catch {
            logger.error("Failed to download release notes: \(error.localizedDescription)")
            if force {
                updateReleaseNotes([])
            } else {
                // do not try to download again for this release
                releaseNotesLastVersion = currentVersion
            }
        }
    }
    
    nonisolated func parseReleaseNotes(_ notes: String) async {
        let lines = notes.split(whereSeparator: \.isNewline)
        var sections = [Section]()
        var currentSection = Section()
        for line in lines {
            let string = String(line)
            let nsString = string as NSString
            if line.hasPrefix("## ") {
                if !currentSection.isEmpty {
                    sections.append(currentSection)
                }
                let index = line.index(line.startIndex, offsetBy: 3)
                currentSection = Section(title: String(line[index...]))
            } else if let regex = try? NSRegularExpression(pattern: #"^\* \(([^\)]+)\) "#),
                      let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: nsString.length)),
                      match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let platform = nsString.substring(with: range)
                let description = nsString.substring(from: match.range.location + match.range.length)
                #if os(iOS) || os(visionOS)
                #if WITH_QEMU_TCI
                if platform == "iOS SE" {
                    currentSection.body.append(description)
                }
                #elseif WITH_REMOTE
                if platform == "iOS Remote" {
                    currentSection.body.append(description)
                }
                #endif
                #if os(visionOS)
                if platform.hasPrefix("visionOS") {
                    currentSection.body.append(description)
                }
                #endif
                if platform != "iOS SE" && platform.hasPrefix("iOS") {
                    // should we also parse versions?
                    currentSection.body.append(description)
                }
                #elseif os(macOS)
                if platform.hasPrefix("macOS") {
                    currentSection.body.append(description)
                }
                #else
                currentSection.body.append(description)
                #endif
            } else if line.hasPrefix("* ") {
                let index = line.index(line.startIndex, offsetBy: 2)
                currentSection.body.append(String(line[index...]))
            } else {
                currentSection.body.append(String(line))
            }
        }
        if !currentSection.isEmpty {
            sections.append(currentSection)
        }
        if !sections.isEmpty {
            await updateReleaseNotes(sections)
        }
    }
    
    private func updateReleaseNotes(_ sections: [Section]) {
        releaseNotes = sections
        isReleaseNotesShown = true
    }
    
    func closeReleaseNotes() {
        releaseNotesLastVersion = currentVersion
        isReleaseNotesShown = false
    }
}
