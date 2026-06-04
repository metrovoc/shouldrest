import Foundation
import XCTest
@testable import shouldrest

final class ReleaseStatusTests: XCTestCase {
    func testReadmeCurrentReleaseMatchesPackagedAppVersion() throws {
        let root = repositoryRoot()
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let infoPlist = root.appendingPathComponent("packaging/Info.plist")
        let info = try XCTUnwrap(NSDictionary(contentsOf: infoPlist) as? [String: Any])
        let version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)

        XCTAssertTrue(
            readme.contains("Current release: `\(version)`"),
            "README release status should match packaging/Info.plist."
        )
        XCTAssertEqual(AppVersion.current, version)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
