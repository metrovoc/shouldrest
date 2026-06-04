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

    func testActiveEyeGateQuitAttemptRoutesToOverlayEmergencyFocus() {
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        XCTAssertEqual(
            StrictRestBlockedActionPolicy.feedback(
                state: state,
                settings: .defaults,
                now: start.addingTimeInterval(1)
            ),
            .focusEyeGateEmergencyInOverlay
        )
        XCTAssertEqual(
            TerminationPolicy.requestAction(
                state: state,
                settings: .defaults,
                now: start.addingTimeInterval(1)
            ),
            .focusEyeGateEmergencyInOverlay
        )
    }

    func testEyeGateQuitAttemptFallsBackToBlockedNoticeWhenEmergencyIsUnavailable() {
        var settings = RestSettings.defaults
        let state = RestEngineState(activeSession: session(kind: .eyeGate))

        settings.eyeGate.emergencyOverride.isEnabled = false
        XCTAssertEqual(
            StrictRestBlockedActionPolicy.feedback(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(1)
            ),
            .notifyBlocked(.eyeGate)
        )
        XCTAssertEqual(
            TerminationPolicy.requestAction(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(1)
            ),
            .notifyBlocked(.eyeGate)
        )

        settings.eyeGate.emergencyOverride.isEnabled = true
        XCTAssertEqual(
            StrictRestBlockedActionPolicy.feedback(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(20)
            ),
            .notifyBlocked(.eyeGate)
        )
        XCTAssertEqual(
            TerminationPolicy.requestAction(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(20)
            ),
            .notifyBlocked(.eyeGate)
        )
    }

    func testStrictBodyBreakQuitAttemptStillUsesBlockedNotice() {
        var settings = RestSettings.defaults
        settings.bodyBreak.ordinarySkipEnabled = false
        let state = RestEngineState(activeSession: session(kind: .bodyBreak))

        XCTAssertEqual(
            StrictRestBlockedActionPolicy.feedback(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(1)
            ),
            .notifyBlocked(.bodyBreak)
        )
        XCTAssertEqual(
            TerminationPolicy.requestAction(
                state: state,
                settings: settings,
                now: start.addingTimeInterval(1)
            ),
            .notifyBlocked(.bodyBreak)
        )
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
        XCTAssertEqual(
            BlockedActionCopy.pauseMessage(for: .eyeGate),
            "Finish Eye Gate before pausing."
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

    func testPauseIndefinitelyMenuTitleUsesDialogEllipsisWhenConfirmationWillOpen() {
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

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: true),
            "无限期暂停..."
        )
        XCTAssertEqual(
            PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: false),
            "无限期暂停"
        )
    }

    func testTimedPauseMenuTitlesShowResumeTime() {
        let now = start
        let target = now.addingTimeInterval(30 * 60)

        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }
        XCTAssertEqual(
            PauseMenuCopy.durationTitle(L10n.tr("menu.pause30"), duration: 30 * 60, now: now),
            L10n.format("menu.pauseDurationWithTime", L10n.tr("menu.pause30"), target.formatted(date: .omitted, time: .shortened))
        )
        XCTAssertNotEqual(PauseMenuCopy.durationTitle(L10n.tr("menu.pause30"), duration: 30 * 60, now: now), "30 Minutes")

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            PauseMenuCopy.durationTitle(L10n.tr("menu.pause30"), duration: 30 * 60, now: now),
            L10n.format("menu.pauseDurationWithTime", L10n.tr("menu.pause30"), target.formatted(date: .omitted, time: .shortened))
        )
        XCTAssertTrue(PauseMenuCopy.durationTitle(L10n.tr("menu.pause30"), duration: 30 * 60, now: now).contains("至"))
    }

    func testPauseUntilMorningMenuTitleShowsResumeTime() {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .hour
        settings.operations.pauseUntilMorningHour = 9
        let now = start
        let target = now.addingTimeInterval(settings.operations.secondsUntilMorning(from: now))

        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }
        XCTAssertEqual(
            PauseMenuCopy.untilMorningTitle(settings: settings, now: now),
            L10n.format("menu.pauseUntilMorningWithTime", target.formatted(date: .omitted, time: .shortened))
        )
        XCTAssertNotEqual(PauseMenuCopy.untilMorningTitle(settings: settings, now: now), "Until Morning")

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            PauseMenuCopy.untilMorningTitle(settings: settings, now: now),
            L10n.format("menu.pauseUntilMorningWithTime", target.formatted(date: .omitted, time: .shortened))
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
