import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class EmergencyOverrideCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testCurrentPolicyDesignIsTwoInOverlayRequests() {
        XCTAssertEqual(EmergencyOverridePolicy.inOverlayRequestCount, 2)
        XCTAssertEqual(EmergencyOverridePolicy.currentDesignConfirmationSteps, 1)
        XCTAssertEqual(EmergencyOverridePolicy.defaults.confirmationSteps, 1)
        XCTAssertEqual(EmergencyOverridePolicy.confirmationStepsForCurrentDesign(isEnabled: true), 1)
        XCTAssertEqual(EmergencyOverridePolicy.confirmationStepsForCurrentDesign(isEnabled: false), 0)
    }

    func testLegacyHoldKeyIsDecodeOnlyAndNotReencoded() throws {
        let legacyJSON = Data(
            #"{"isEnabled":true,"confirmationSteps":3,"minimumHoldDuration":45}"#.utf8
        )

        let policy = try JSONDecoder().decode(EmergencyOverridePolicy.self, from: legacyJSON)

        XCTAssertTrue(policy.isEnabled)
        XCTAssertEqual(policy.confirmationSteps, 3)

        let encoded = try JSONEncoder().encode(policy)
        XCTAssertFalse(String(data: encoded, encoding: .utf8)?.contains("minimumHoldDuration") ?? true)
    }

    func testEnabledEmergencyRequiresSecondRequestEvenWhenLegacyStepsAreZero() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(3)
        ))
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(3)),
            .complete
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testSecondRequestCompletesInternalOverlayConfirmationIgnoringLegacyExtraStepsAndHold() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 2)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(4)),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(10)
        ))
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(10)),
            .complete
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testSecondRequestCompletesImmediatelyWithoutHoldDelay() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(4)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: requestTime.addingTimeInterval(1)
        ))
        XCTAssertTrue(coordinator.isArmed(for: session, now: requestTime.addingTimeInterval(1)))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .complete
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testSecondRequestCompletesWithinShortConfirmationWindow() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(4)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session, now: requestTime.addingTimeInterval(5)))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime.addingTimeInterval(5)),
            .complete
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testExpiredSecondRequestRearmsInsteadOfCompleting() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(4)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertFalse(coordinator.isArmed(
            for: session,
            now: requestTime.addingTimeInterval(EmergencyOverrideCoordinator.confirmationWindowDuration + 1)
        ))
        XCTAssertEqual(
            coordinator.request(
                session: session,
                policy: policy,
                now: requestTime.addingTimeInterval(EmergencyOverrideCoordinator.confirmationWindowDuration + 1)
            ),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
    }

    func testElapsedLegacyHoldDoesNotKeepConfirmationWindowOpen() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))

        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(30)
        ))
        XCTAssertFalse(coordinator.isArmed(for: session, now: start.addingTimeInterval(30)))
    }

    func testEmergencyIsUnavailableAfterEyeGateDurationHasBeenSatisfied() {
        let session = eyeGateSession(duration: 20)
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(19)
        ))
        XCTAssertFalse(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(20)
        ))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(20)),
            .unavailable
        )
    }

    func testEmergencyIsUnavailableAfterEyeGateDurationEvenWithLegacyHold() {
        let session = eyeGateSession(duration: 20)
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(18)),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(20)),
            .unavailable
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testDisabledPolicyCannotLeaveArmedState() {
        let session = eyeGateSession()
        let enabled = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0)
        let disabled = EmergencyOverridePolicy.disabled
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: enabled, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: disabled, now: start.addingTimeInterval(1)),
            .unavailable
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testBodyBreakCannotCreateArmedEmergencyState() {
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .unavailable
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    private func eyeGateSession(duration: TimeInterval = 60) -> RestSession {
        RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: duration,
            manualFinishEnabled: false
        )
    }
}
