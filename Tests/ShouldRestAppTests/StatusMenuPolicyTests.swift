import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class StatusMenuPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 2_000)

    func testActiveEyeGateSuppressesOrdinaryMenuControls() {
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertFalse(StatusMenuPolicy.showsOrdinaryControls(state: state))
    }

    func testEyeGateManualFinishPhaseStillSuppressesOrdinaryMenuControls() {
        let state = RestEngineState(activeSession: RestSession(
            kind: .eyeGate,
            startedAt: start.addingTimeInterval(-30),
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: true
        ))

        XCTAssertFalse(StatusMenuPolicy.showsOrdinaryControls(state: state))
    }

    func testBodyBreakAndIdleStatesShowOrdinaryMenuControls() {
        XCTAssertTrue(StatusMenuPolicy.showsOrdinaryControls(state: RestEngineState()))
        XCTAssertTrue(StatusMenuPolicy.showsOrdinaryControls(
            state: RestEngineState(activeSession: session(kind: .bodyBreak))
        ))
    }

    private func session(kind: RestKind) -> RestSession {
        RestSession(
            kind: kind,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
    }
}
