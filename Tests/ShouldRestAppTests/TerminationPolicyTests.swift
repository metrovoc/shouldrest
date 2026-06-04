import AppKit
import Foundation
import XCTest
import ShouldRestCore
@testable import shouldrest

@MainActor
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

    func testResetScheduleConfirmationDefaultsToCancel() {
        let alert = ResetScheduleConfirmation.makeAlert()

        XCTAssertEqual(alert.messageText, L10n.tr("reset.confirmTitle"))
        XCTAssertEqual(alert.informativeText, L10n.tr("reset.confirmBody"))
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map(\.title), [
            L10n.tr("reset.confirmCancel"),
            L10n.tr("reset.confirmAction")
        ])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        if #available(macOS 11.0, *) {
            XCTAssertFalse(alert.buttons[0].hasDestructiveAction)
            XCTAssertTrue(alert.buttons[1].hasDestructiveAction)
        }
    }

    func testPauseIndefinitelyConfirmationDefaultsToCancel() {
        let alert = PauseIndefinitelyConfirmation.makeAlert()

        XCTAssertEqual(alert.messageText, L10n.tr("pause.indefiniteConfirmTitle"))
        XCTAssertEqual(alert.informativeText, L10n.tr("pause.indefiniteConfirmBody"))
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map(\.title), [
            L10n.tr("pause.indefiniteConfirmCancel"),
            L10n.tr("pause.indefiniteConfirmAction")
        ])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        if #available(macOS 11.0, *) {
            XCTAssertFalse(alert.buttons[0].hasDestructiveAction)
            XCTAssertTrue(alert.buttons[1].hasDestructiveAction)
        }
    }

    func testPauseIndefinitelyMenuTitleSignalsConfirmationOnlyWhenUsed() {
        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }

        XCTAssertEqual(
            PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: true),
            "Indefinitely..."
        )
        XCTAssertEqual(
            PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: false),
            "Indefinitely"
        )
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
