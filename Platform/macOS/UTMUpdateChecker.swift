import Foundation

class UTMUpdateChecker: ObservableObject {
    @Published var isUpdateAvailable = false
    @Published var latestVersion: String?
    @Published var updateURL: URL?
    
    private let currentVersion: String
    private static let githubAPI = "https://api.github.com/repos/utmapp/UTM/releases/latest"
    
    init() {
        // Get current version from bundle
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    @MainActor
    func checkForUpdates() async {
        do {
            // Configure the API request
            let configuration = URLSessionConfiguration.ephemeral
            configuration.allowsCellularAccess = true
            configuration.allowsExpensiveNetworkAccess = false
            configuration.allowsConstrainedNetworkAccess = false
            configuration.waitsForConnectivity = false
            configuration.httpAdditionalHeaders = [
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28"
            ]
            
            let session = URLSession(configuration: configuration)
            let url = URL(string: Self.githubAPI)!
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            
            self.latestVersion = latestVersion
            
            // Compare versions
            if compareVersions(currentVersion, latestVersion) {
                self.isUpdateAvailable = true
                // Get macOS dmg asset URL
                if let dmgAsset = release.assets.first(where: { asset in
                    asset.name.hasSuffix(".dmg") && !asset.name.contains("unsigned")
                }) {
                    self.updateURL = URL(string: dmgAsset.browserDownloadUrl)
                }
            }
            
        } catch {
            print("Failed to check for updates: \(error.localizedDescription)")
        }
    }
    
    private func compareVersions(_ current: String, _ latest: String) -> Bool {
        let currentComponents = current.split(separator: ".")
        let latestComponents = latest.split(separator: ".")
        
        let currentMajor = Int(currentComponents[0]) ?? 0
        let currentMinor = Int(currentComponents[1]) ?? 0
        let currentPatch = Int(currentComponents[2]) ?? 0
        
        let latestMajor = Int(latestComponents[0]) ?? 0
        let latestMinor = Int(latestComponents[1]) ?? 0
        let latestPatch = Int(latestComponents[2]) ?? 0
        
        if latestMajor > currentMajor {
            return true
        }
        if latestMajor == currentMajor && latestMinor > currentMinor {
            return true
        }
        if latestMajor == currentMajor && latestMinor == currentMinor && latestPatch > currentPatch {
            return true
        }
        return false
    }
}

// GitHub API response models
private struct GitHubRelease: Codable {
    let tagName: String
    let assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

private struct Asset: Codable {
    let name: String
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}
