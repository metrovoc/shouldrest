import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class EmergencyOverrideCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testRequestCompletesImmediatelyWithoutArmingOrWaiting() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
        XCTAssertNil(coordinator.completionIfArmedAndReady(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(3)
        ))
    }

    func testSecondRequestCompletesInternalOverlayConfirmationIgnoringLegacyExtraStepsAndHold() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 2, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(4)),
            .waiting(remainingSeconds: 0)
        )
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertNil(coordinator.completionIfArmedAndReady(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(10)
        ))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(10)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
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
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(20)),
            .unavailable
        )
    }

    func testDisabledPolicyCannotLeaveArmedState() {
        let session = eyeGateSession()
        let enabled = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        let disabled = EmergencyOverridePolicy.disabled
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: enabled, now: start.addingTimeInterval(1)),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))

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
