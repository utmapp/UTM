//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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
import XCTest
@testable import UTM

/// Hosts a preview offscreen so that a trap in its body (a force unwrap, a missing
/// environment object) fails the test that names it rather than the first tap in the app.
///
/// The generated `PreviewSmokeTests` calls `render` once per PreviewProvider. Every
/// environment object the test can build is injected into each preview; a preview whose
/// view file reads one it cannot build is skipped, which XCTest reports.
@MainActor
class PreviewSmokeTestCase: XCTestCase {
    /// Previews that cannot be rendered here, with the reason.
    static let quarantined: [String: String] = {
        var list = [
            "ContentView_Previews": "the home window starts the VM list refresh and the release notes fetch on appear",
        ]
        #if !os(macOS)
        // both crash the iOS host with the empty VM the preview passes (the class of f7c38dc5)
        list["VMDetailsView_Previews"] = "crashes on iOS with a VM that has no configuration"
        list["VMRemovableDrivesView_Previews"] = "crashes on iOS with a VM that has no configuration"
        #endif
        return list
    }()

    /// Environment object types no test can build: they need a running VM or a remote session.
    static let unsatisfiable: Set<String> = ["VMSessionState", "UTMRemoteData", "UTMRemoteServer.State"]

    private var data: UTMData!
    private var fileImporter: GlobalFileImporterShim!
    private var vm: VMData!

    override func setUp() {
        data = UTMData()
        fileImporter = GlobalFileImporterShim()
        vm = VMData(from: .empty)
    }

    override func tearDown() {
        data = nil
        fileImporter = nil
        vm = nil
    }

    /// Renders the preview named `name` with every environment object injected.
    func render(_ name: String, source: String, needs: [String], make: () -> AnyView) throws {
        if let reason = Self.quarantined[name] {
            throw XCTSkip("\(name) is quarantined: \(reason)")
        }
        if let missing = needs.first(where: { Self.unsatisfiable.contains($0) }) {
            throw XCTSkip("\(name) needs \(missing), which no test can build")
        }
        for need in needs where !Self.unsatisfiable.contains(need) {
            XCTAssertTrue(["UTMData", "GlobalFileImporterShim", "VMData"].contains(need), "\(source) reads an environment object this test does not know: \(need)")
        }
        let view = make()
            .environmentObject(data!)
            .environmentObject(fileImporter!)
            .environmentObject(vm!)
        host(AnyView(view))
    }

    /// Lays the view out in an offscreen window and lets the first run loop pass settle.
    func host(_ view: AnyView) {
        #if os(macOS)
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        window.contentView = nil
        #else
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        window.isHidden = true
        #endif
    }

    /// A view that records that its body was evaluated.
    private struct Sentinel: View {
        let seen: () -> Void
        var body: some View {
            seen()
            return Text("sentinel")
        }
    }

    /// The hosting really evaluates bodies, so a trap in a preview cannot go unnoticed.
    func testHostingEvaluatesTheBody() {
        var evaluated = false
        host(AnyView(Sentinel { evaluated = true }))
        XCTAssertTrue(evaluated, "the offscreen window did not evaluate the view's body")
    }
}
