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
}
