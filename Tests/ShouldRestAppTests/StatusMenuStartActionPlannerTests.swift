import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class StatusMenuStartActionPlannerTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 7_000)

    func testScheduledEyeGateIsPrimaryAndDoesNotRepeatGenericEyeGateAction() {
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(600), notificationAt: nil)
        )

        XCTAssertEqual(
            StatusMenuStartActionPlanner.actions(state: state, settings: .defaults),
            [.nextScheduled(.eyeGate), .bodyBreak]
        )
    }

    func testScheduledBodyBreakIsPrimaryAndDoesNotRepeatGenericBodyBreakAction() {
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .bodyBreak, dueAt: start.addingTimeInterval(600), notificationAt: nil)
        )

        XCTAssertEqual(
            StatusMenuStartActionPlanner.actions(state: state, settings: .defaults),
            [.nextScheduled(.bodyBreak), .eyeGate]
        )
    }

    func testNoScheduledRestShowsEnabledManualRestActions() {
        XCTAssertEqual(
            StatusMenuStartActionPlanner.actions(state: RestEngineState(), settings: .defaults),
            [.eyeGate, .bodyBreak]
        )
    }

    func testDisabledRestTypesAreNotOfferedAsManualAlternates() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(600), notificationAt: nil)
        )

        XCTAssertEqual(
            StatusMenuStartActionPlanner.actions(state: state, settings: settings),
            [.nextScheduled(.eyeGate)]
        )
    }

    func testActiveRestSuppressesStartActions() {
        let state = RestEngineState(activeSession: RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 300,
            manualFinishEnabled: false
        ))

        XCTAssertEqual(
            StatusMenuStartActionPlanner.actions(state: state, settings: .defaults),
            []
        )
    }

    func testStartActionTitlesStayUserFacingAndConcrete() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        XCTAssertEqual(StatusMenuStartAction.nextScheduled(.eyeGate).title, "Start Next Eye Gate Now")
        XCTAssertEqual(StatusMenuStartAction.eyeGate.title, "Start Eye Gate Now")
        XCTAssertEqual(StatusMenuStartAction.bodyBreak.title, "Start Body Break Now")
        XCTAssertFalse(StatusMenuStartAction.nextScheduled(.eyeGate).title.contains("takeNextScheduledRestNow"))
    }
}
