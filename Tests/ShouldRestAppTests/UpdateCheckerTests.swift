import Foundation
import XCTest
@testable import shouldrest

final class UpdateCheckerTests: XCTestCase {
    private enum TestError: Error {
        case unexpectedFetch
    }

    func testComparesVersionComponentsAndVPREFIX() {
        XCTAssertTrue(UpdateChecker.isVersion("v1.2.10", newerThan: "1.2.9"))
        XCTAssertTrue(UpdateChecker.isVersion("1.3", newerThan: "1.2.99"))
        XCTAssertFalse(UpdateChecker.isVersion("1.2.0", newerThan: "1.2"))
        XCTAssertFalse(UpdateChecker.isVersion("1.2.3", newerThan: "1.2.3"))
        XCTAssertFalse(UpdateChecker.isVersion("1.2.3-beta", newerThan: "1.2.3"))
    }

    func testReturnsNotConfiguredWithoutFetching() async {
        let checker = UpdateChecker(fetch: { _ in
            throw TestError.unexpectedFetch
        })

        let result = await checker.check(feedURL: "", currentVersion: "1.0.0")

        XCTAssertEqual(result.status, .notConfigured)
        XCTAssertNil(result.releaseURL)
    }

    func testParsesGitHubStyleNewerRelease() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://example.com/releases/v1.2.0"))
        let checker = UpdateChecker(fetch: { url in
            XCTAssertEqual(url.absoluteString, "https://example.com/latest")
            return (
                Self.jsonData([
                    "tag_name": "v1.2.0",
                    "html_url": releaseURL.absoluteString
                ]),
                Self.httpResponse(statusCode: 200)
            )
        })

        let result = await checker.check(feedURL: "https://example.com/latest", currentVersion: "1.1.9")

        XCTAssertEqual(result.status, .newerVersion("v1.2.0"))
        XCTAssertEqual(result.releaseURL, releaseURL)
    }

    func testParsesVersionFieldAndReportsUpToDate() async {
        let checker = UpdateChecker(fetch: { _ in
            (
                Self.jsonData(["version": "1.0.0"]),
                Self.httpResponse(statusCode: 200)
            )
        })

        let result = await checker.check(feedURL: "https://example.com/latest", currentVersion: "1.0.0")

        XCTAssertEqual(result.status, .upToDate)
    }

    func testReportsHTTPAndMalformedResponseFailures() async {
        let httpFailure = UpdateChecker(fetch: { _ in
            (Data(), Self.httpResponse(statusCode: 404))
        })
        let invalidJSON = UpdateChecker(fetch: { _ in
            (Data("not json".utf8), Self.httpResponse(statusCode: 200))
        })

        let httpResult = await httpFailure.check(feedURL: "https://example.com/latest", currentVersion: "1.0.0")
        let invalidResult = await invalidJSON.check(feedURL: "https://example.com/latest", currentVersion: "1.0.0")

        XCTAssertEqual(httpResult.status, .failed("HTTP 404"))
        XCTAssertEqual(invalidResult.status, .failed("Invalid update response"))
    }

    private static func jsonData(_ object: [String: String]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private static func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/latest")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
