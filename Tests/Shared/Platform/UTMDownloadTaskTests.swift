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

import XCTest
@testable import UTM

/// The `Last-Modified` parsing every download task shares: the guest tools tasks compare it
/// with the value saved at download time, and a header that does not parse counts as
/// "not newer", so cached guest tools would never be downloaded again (#7978).
final class UTMDownloadTaskTests: XCTestCase {
    private let task = UTMDownloadTask(for: URL(string: "https://example.invalid/tools.iso")!, named: "Test")

    private func response(_ headers: [String: String]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.invalid/tools.iso")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
    }

    private func timestamp(_ lastModified: String) -> Int? {
        task.lastModifiedTimestamp(for: response(["Last-Modified": lastModified]))
    }

    /// The formatters must not follow the user's locale: with UTM in any of its non-English
    /// languages, the English day and month names did not parse. This holds on any test runner;
    /// the parsing tests below also cover it when run with `-testLanguage de -testRegion DE`.
    func testHTTPDatesIgnoreTheUserLocale() {
        for formatter in UTMDownloadTask.httpDateFormatters {
            XCTAssertEqual(formatter.locale.identifier, "en_US_POSIX", formatter.dateFormat)
            XCTAssertEqual(formatter.timeZone.secondsFromGMT(), 0, formatter.dateFormat)
        }
    }

    func testLastModifiedIsParsedAsHTTPDate() {
        XCTAssertEqual(timestamp("Thu, 29 Oct 2026 18:37:20 GMT"), 1793299040)
        XCTAssertEqual(timestamp("Thu, 15 Oct 2026 00:00:00 GMT"), 1792022400)
        XCTAssertEqual(timestamp("Sun, 31 Aug 2025 12:00:00 GMT"), 1756641600)
    }

    /// RFC 9110 section 5.6.7: recipients also accept the obsolete RFC 850 and asctime formats
    func testObsoleteHTTPDateFormatsAreParsed() {
        XCTAssertEqual(timestamp("Sunday, 06-Nov-94 08:49:37 GMT"), 784111777)
        XCTAssertEqual(timestamp("Sun Nov  6 08:49:37 1994"), 784111777)
    }

    func testHeaderNameIsCaseInsensitive() {
        XCTAssertEqual(task.lastModifiedTimestamp(for: response(["last-modified": "Thu, 29 Oct 2026 18:37:20 GMT"])), 1793299040)
    }

    func testMissingOrInvalidLastModifiedIsNil() {
        XCTAssertNil(task.lastModifiedTimestamp(for: response([:])))
        XCTAssertNil(timestamp("yesterday"))
        XCTAssertNil(task.lastModifiedTimestamp(for: nil))
        XCTAssertNil(task.lastModifiedTimestamp(for: URLResponse(url: URL(string: "file:///tools.iso")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)))
    }
}
