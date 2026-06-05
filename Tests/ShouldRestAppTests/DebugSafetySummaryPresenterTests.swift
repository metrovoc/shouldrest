import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class DebugSafetySummaryPresenterTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 8_000)

    func testActiveBodyBreakSummaryNamesMenuAndOverlayControls() {
        let state = RestEngineState(activeSession: session(
            kind: .bodyBreak,
            duration: 300,
            manualFinishEnabled: true
        ))

        let summary = DebugSafetySummaryPresenter.summary(
            state: state,
            settings: .defaults,
            now: start.addingTimeInterval(60)
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryBodyActiveTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryBodyActiveBody"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("status menu"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("overlay"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("overlay buttons"))
        XCTAssertEqual(summary.symbolName, "figure.walk.circle")
        XCTAssertEqual(summary.severity, .warning)
    }

    func testActiveBodyBreakSummaryOmitsStatusMenuWhenMenuBarIconIsHidden() {
        let state = RestEngineState(activeSession: session(
            kind: .bodyBreak,
            duration: 300,
            manualFinishEnabled: true
        ))

        let summary = DebugSafetySummaryPresenter.summary(
            state: state,
            settings: hiddenMenuBarSettings(),
            now: start.addingTimeInterval(60)
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryBodyActiveTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryBodyActiveBodyMenuHidden"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("overlay"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("still running"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("status menu"))
        XCTAssertEqual(summary.symbolName, "figure.walk.circle")
        XCTAssertEqual(summary.severity, .warning)
    }

    func testReadyBodyBreakSummaryOnlyNamesFinish() {
        let state = RestEngineState(activeSession: session(
            kind: .bodyBreak,
            duration: 300,
            manualFinishEnabled: true
        ))

        let summary = DebugSafetySummaryPresenter.summary(
            state: state,
            settings: .defaults,
            now: start.addingTimeInterval(301)
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryBodyReadyTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryBodyReadyBody"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("status menu"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("overlay"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("postpone"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("skip"))
        XCTAssertEqual(summary.symbolName, "checkmark.circle")
        XCTAssertEqual(summary.severity, .warning)
    }

    func testReadyBodyBreakSummaryOmitsStatusMenuWhenMenuBarIconIsHidden() {
        let state = RestEngineState(activeSession: session(
            kind: .bodyBreak,
            duration: 300,
            manualFinishEnabled: true
        ))

        let summary = DebugSafetySummaryPresenter.summary(
            state: state,
            settings: hiddenMenuBarSettings(),
            now: start.addingTimeInterval(301)
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryBodyReadyTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryBodyReadyBodyMenuHidden"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("overlay"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("still running"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("status menu"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("postpone"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("skip"))
        XCTAssertEqual(summary.symbolName, "checkmark.circle")
        XCTAssertEqual(summary.severity, .warning)
    }

    func testEyeGateSummaryStillKeepsStrictOverlayGuidance() {
        let state = RestEngineState(activeSession: session(
            kind: .eyeGate,
            duration: 20,
            manualFinishEnabled: false
        ))

        let summary = DebugSafetySummaryPresenter.summary(
            state: state,
            settings: .defaults,
            now: start.addingTimeInterval(5)
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryEyeActiveTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryEyeActiveBody"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("Emergency Exit twice"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("Esc twice"))
        XCTAssertEqual(summary.symbolName, "exclamationmark.shield")
        XCTAssertEqual(summary.severity, .active)
    }

    func testReadySummaryNamesRecoveryPathWhenMenuBarIconIsHidden() {
        let summary = DebugSafetySummaryPresenter.summary(
            state: RestEngineState(),
            settings: hiddenMenuBarSettings(),
            now: start
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryReadyBodyMenuHidden"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("Applications"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("shouldrest preferences"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("shouldrest://preferences"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("Menu actions"))
        XCTAssertEqual(summary.symbolName, "checkmark.shield")
        XCTAssertEqual(summary.severity, .ready)
    }

    func testPausedSummaryNamesResumePathWhenMenuBarIconIsHidden() {
        let summary = DebugSafetySummaryPresenter.summary(
            state: RestEngineState(pause: PauseState(reason: .user, startedAt: start, until: nil)),
            settings: hiddenMenuBarSettings(),
            now: start
        )

        XCTAssertEqual(summary.title, L10n.tr("debug.summaryPausedTitle"))
        XCTAssertEqual(summary.body, L10n.tr("debug.summaryPausedBodyMenuHidden"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("Applications"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("shouldrest resume"))
        XCTAssertTrue(summary.body.localizedCaseInsensitiveContains("shouldrest://resume"))
        XCTAssertFalse(summary.body.localizedCaseInsensitiveContains("status menu"))
        XCTAssertEqual(summary.symbolName, "pause.circle")
        XCTAssertEqual(summary.severity, .warning)
    }

    private func session(
        kind: RestKind,
        duration: TimeInterval,
        manualFinishEnabled: Bool
    ) -> RestSession {
        RestSession(
            kind: kind,
            startedAt: start,
            scheduledAt: start,
            duration: duration,
            manualFinishEnabled: manualFinishEnabled
        )
    }

    private func hiddenMenuBarSettings() -> RestSettings {
        var settings = RestSettings.defaults
        settings.presentation.showMenuBarItem = false
        return settings
    }
}
