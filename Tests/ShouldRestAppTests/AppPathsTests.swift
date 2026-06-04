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

    func testDefaultAppIdentityKeepsStableAutomationNotificationName() {
        XCTAssertEqual(AppIdentity.defaultBundleIdentifier, "dev.shouldrest.app")
        XCTAssertEqual(AppIdentity.defaultAutomationNotificationName.rawValue, "dev.shouldrest.automation")
        XCTAssertEqual(
            AppIdentity.automationNotificationName(
                bundleIdentifier: AppIdentity.defaultBundleIdentifier,
                environment: [:]
            ).rawValue,
            "dev.shouldrest.automation"
        )
    }

    func testTemporaryBundleIdentifierGetsIsolatedAutomationNotificationName() {
        let bundleIdentifier = "dev.shouldrest.smoke.123"

        XCTAssertEqual(
            AppIdentity.automationNotificationName(bundleIdentifier: bundleIdentifier, environment: [:]).rawValue,
            "dev.shouldrest.smoke.123.automation"
        )
    }

    func testAppIdentityEnvironmentOverridesAreTrimmed() {
        XCTAssertEqual(
            AppIdentity.bundleIdentifier(
                bundle: nil,
                environment: ["SHOULDREST_BUNDLE_IDENTIFIER": "  dev.shouldrest.test  "]
            ),
            "dev.shouldrest.test"
        )
        XCTAssertEqual(
            AppIdentity.automationNotificationName(
                bundleIdentifier: AppIdentity.defaultBundleIdentifier,
                environment: ["SHOULDREST_AUTOMATION_NOTIFICATION": "  dev.shouldrest.test.automation  "]
            ).rawValue,
            "dev.shouldrest.test.automation"
        )
    }
}
