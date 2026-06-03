import Foundation
import XCTest
import ShouldRestCore
@testable import shouldrest

final class TerminationPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testBlocksTerminationDuringEyeGate() {
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertEqual(TerminationPolicy.strictActiveRestKind(state: state, settings: .defaults), .eyeGate)
        XCTAssertFalse(TerminationPolicy.canTerminate(state: state, settings: .defaults))
    }

    func testBlocksTerminationDuringStrictBodyBreak() {
        var settings = RestSettings.defaults
        settings.bodyBreak.ordinarySkipEnabled = false
        let state = RestEngineState(activeSession: session(kind: .bodyBreak))

        XCTAssertEqual(TerminationPolicy.strictActiveRestKind(state: state, settings: settings), .bodyBreak)
        XCTAssertFalse(TerminationPolicy.canTerminate(state: state, settings: settings))
    }

    func testAllowsTerminationWithoutStrictActiveRest() {
        XCTAssertTrue(TerminationPolicy.canTerminate(state: RestEngineState(), settings: .defaults))

        let state = RestEngineState(activeSession: session(kind: .bodyBreak))

        XCTAssertNil(TerminationPolicy.strictActiveRestKind(state: state, settings: .defaults))
        XCTAssertTrue(TerminationPolicy.canTerminate(state: state, settings: .defaults))
    }

    func testBlockedActionCopyExplainsDisabledMenuActions() {
        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }

        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertEqual(
            BlockedActionCopy.quitMessage(state: state, settings: .defaults),
            "Finish Eye Gate before quitting."
        )
        XCTAssertEqual(
            BlockedActionCopy.resetScheduleMessage(state: state, settings: .defaults),
            "Finish Eye Gate before resetting the schedule."
        )
        XCTAssertNil(BlockedActionCopy.quitMessage(state: RestEngineState(), settings: .defaults))
        XCTAssertNil(BlockedActionCopy.resetScheduleMessage(state: RestEngineState(), settings: .defaults))
    }

    private func session(kind: RestKind) -> RestSession {
        RestSession(
            kind: kind,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        )
    }
}
