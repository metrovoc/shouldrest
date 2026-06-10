import XCTest
import ShouldRestCore
@testable import shouldrest

final class AppPathsTests: XCTestCase {
    func testUsesDefaultApplicationSupportDirectoryWithoutOverride() {
        let url = AppPaths.supportDirectory(environment: [:])

        XCTAssertEqual(url.lastPathComponent, "ShouldRest")
        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertEqual(AppPaths.engineStateURL.lastPathComponent, "engine-state.json")
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

    func testEngineStateStoreRoundTripsRuntimeState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = EngineStateStore(fileURL: directory.appendingPathComponent("engine-state.json"))
        let state = RestEngineState(
            scheduled: ScheduledRest(
                kind: .eyeGate,
                dueAt: Date(timeIntervalSinceReferenceDate: 200),
                notificationAt: Date(timeIntervalSinceReferenceDate: 190),
                notificationSent: false
            ),
            eyeDebt: 12,
            bodyDebt: 34,
            lastEvaluatedAt: Date(timeIntervalSinceReferenceDate: 100)
        )

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }
}
