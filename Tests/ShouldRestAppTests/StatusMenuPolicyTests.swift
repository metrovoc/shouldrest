import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class StatusMenuPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 2_000)

    func testActiveEyeGateSuppressesOrdinaryMenuControls() {
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertFalse(StatusMenuPolicy.showsOrdinaryControls(state: state))
        XCTAssertTrue(StatusMenuPolicy.routesEmergencyExitThroughOverlay(state: state))
        XCTAssertTrue(StatusMenuPolicy.showsOverlayOnlyNotice(state: state, canEmergencyExit: true))
    }

    func testActiveEyeGateKeepsSafeSupportActionsVisibleWithoutOrdinaryControls() {
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertTrue(StrictRestStatusMenuPolicy.showsSafeSupportReportCopy(state: state))
        XCTAssertTrue(StrictRestStatusMenuPolicy.showsDisabledQuitExplanation(state: state, settings: .defaults))
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
        XCTAssertTrue(StatusMenuPolicy.routesEmergencyExitThroughOverlay(state: state))
        XCTAssertFalse(StatusMenuPolicy.showsOverlayOnlyNotice(state: state, canEmergencyExit: false))
    }

    func testBodyBreakAndIdleStatesShowOrdinaryMenuControls() {
        XCTAssertTrue(StatusMenuPolicy.showsOrdinaryControls(state: RestEngineState()))
        XCTAssertFalse(StatusMenuPolicy.routesEmergencyExitThroughOverlay(state: RestEngineState()))
        XCTAssertFalse(StatusMenuPolicy.showsOverlayOnlyNotice(state: RestEngineState(), canEmergencyExit: true))
        XCTAssertTrue(StatusMenuPolicy.showsOrdinaryControls(
            state: RestEngineState(activeSession: session(kind: .bodyBreak))
        ))
        XCTAssertFalse(StatusMenuPolicy.routesEmergencyExitThroughOverlay(
            state: RestEngineState(activeSession: session(kind: .bodyBreak))
        ))
        XCTAssertFalse(StatusMenuPolicy.showsOverlayOnlyNotice(
            state: RestEngineState(activeSession: session(kind: .bodyBreak)),
            canEmergencyExit: true
        ))
        XCTAssertFalse(StrictRestStatusMenuPolicy.showsSafeSupportReportCopy(state: RestEngineState()))
        XCTAssertFalse(StrictRestStatusMenuPolicy.showsDisabledQuitExplanation(state: RestEngineState(), settings: .defaults))
        XCTAssertFalse(StrictRestStatusMenuPolicy.showsSafeSupportReportCopy(
            state: RestEngineState(activeSession: session(kind: .bodyBreak))
        ))
        XCTAssertFalse(StrictRestStatusMenuPolicy.showsDisabledQuitExplanation(
            state: RestEngineState(activeSession: session(kind: .bodyBreak)),
            settings: .defaults
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
