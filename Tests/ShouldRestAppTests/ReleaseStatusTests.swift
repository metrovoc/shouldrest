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

    func testStretchlyCapabilityDocsDoNotReintroduceLongMenuBarStatusStyles() throws {
        let root = repositoryRoot()
        let contract = try String(
            contentsOf: root.appendingPathComponent("docs/stretchly-capability-contract.md"),
            encoding: .utf8
        )
        let audit = try String(
            contentsOf: root.appendingPathComponent("docs/stretchly-feature-audit.md"),
            encoding: .utf8
        )

        XCTAssertTrue(contract.contains("compact icon-only menu bar"))
        XCTAssertTrue(contract.contains("legacy tray style values decode for compatibility"))
        XCTAssertTrue(audit.contains("compact icon-only menu bar"))
        XCTAssertTrue(audit.contains("legacy tray style values decode for compatibility only"))
        XCTAssertFalse(contract.contains("Tray/menu-bar status styles: default, time-to-break, and progress"))
        XCTAssertFalse(audit.contains("Tray style: default, time-to-break, progress"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
