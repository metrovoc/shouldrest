import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class EmergencyOverrideCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testMinimumHoldDurationIsCompatibilityOnly() {
        var policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 30)

        XCTAssertEqual(policy.minimumHoldDuration, 0)

        policy.minimumHoldDuration = 45

        XCTAssertEqual(policy.minimumHoldDuration, 0)
    }

    func testEnabledEmergencyRequiresSecondRequestEvenWhenLegacyStepsAreZero() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(3)
        ))
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(3)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testSecondRequestCompletesInternalOverlayConfirmationIgnoringLegacyExtraStepsAndHold() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 2, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(4)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(10)
        ))
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(10)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testSecondRequestCompletesImmediatelyWithoutHoldDelay() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 21)
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(4)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: requestTime.addingTimeInterval(21)
        ))
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testExternalArmCannotCompleteEmergencyOverride() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 0)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(2)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(3)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testRepeatedExternalArmsNeverCompleteEmergencyOverrideEvenAfterLegacyHoldTime() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 21)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(30)),
            .armed
        )
        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(45)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
    }

    func testExternalArmAfterOverlayRequestCannotActAsSecondConfirmation() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 21)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))

        XCTAssertEqual(
            coordinator.arm(session: session, policy: policy, now: start.addingTimeInterval(30)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(31)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testElapsedLegacyHoldCannotCompleteWithoutSecondRequest() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 21)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))

        XCTAssertTrue(EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(30)
        ))
        XCTAssertTrue(coordinator.isArmed(for: session))
    }

    func testEmergencyIsUnavailableAfterEyeGateDurationHasBeenSatisfied() {
        let session = eyeGateSession(duration: 20)
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
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
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 21)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(18)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(20)),
            .unavailable
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testDisabledPolicyCannotLeaveArmedState() {
        let session = eyeGateSession()
        let enabled = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        let disabled = EmergencyOverridePolicy.disabled
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: enabled, now: start.addingTimeInterval(1)),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: disabled, now: start.addingTimeInterval(1)),
            .unavailable
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testBodyBreakCannotCreateArmedEmergencyState() {
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .unavailable
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
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
