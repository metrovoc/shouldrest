import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class EmergencyOverrideCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testRequestBeforeHoldOnlyWaitsAndNeverCreatesConfirmationState() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(1)),
            .waiting(remainingSeconds: 2)
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
        XCTAssertNil(coordinator.completionIfArmedAndReady(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(2)
        ))
        XCTAssertNil(coordinator.completionIfArmedAndReady(
            session: session,
            policy: policy,
            now: start.addingTimeInterval(3)
        ))
    }

    func testRequestAfterHoldCompletesImmediatelyWithoutLegacyConfirmationSteps() {
        let session = eyeGateSession()
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 2, minimumHoldDuration: 3)
        var coordinator = EmergencyOverrideCoordinator()

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: start.addingTimeInterval(4)),
            .complete(heldDuration: 4)
        )
    }

    func testDisabledPolicyClearsArmedState() {
        let session = eyeGateSession()
        let enabled = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 0, minimumHoldDuration: 3)
        let disabled = EmergencyOverridePolicy.disabled
        var coordinator = EmergencyOverrideCoordinator()

        _ = coordinator.request(session: session, policy: enabled, now: start.addingTimeInterval(1))
        XCTAssertFalse(coordinator.isArmed(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: disabled, now: start.addingTimeInterval(1)),
            .unavailable
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    private func eyeGateSession() -> RestSession {
        RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
    }
}
