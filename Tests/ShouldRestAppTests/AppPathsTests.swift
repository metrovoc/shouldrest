import XCTest
@testable import shouldrest

final class AppPathsTests: XCTestCase {
    func testUsesDefaultApplicationSupportDirectoryWithoutOverride() {
        let url = AppPaths.supportDirectory(environment: [:])

        XCTAssertEqual(url.lastPathComponent, "ShouldRest")
        XCTAssertTrue(url.path.contains("Application Support"))
    }

    func testSupportDirectoryCanBeOverriddenForSmokeRuns() {
        let url = AppPaths.supportDirectory(environment: ["SHOULDREST_SUPPORT_DIR": "/tmp/shouldrest-smoke"])

        XCTAssertEqual(url.path, "/tmp/shouldrest-smoke")
    }

    func testBlankSupportDirectoryOverrideFallsBackToDefault() {
        let url = AppPaths.supportDirectory(environment: ["SHOULDREST_SUPPORT_DIR": "   "])

        XCTAssertEqual(url.lastPathComponent, "ShouldRest")
        XCTAssertTrue(url.path.contains("Application Support"))
    }
}
