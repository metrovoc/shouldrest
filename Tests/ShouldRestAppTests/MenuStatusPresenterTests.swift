import XCTest
import ShouldRestCore
@testable import shouldrest

final class MenuStatusPresenterTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        L10n.languageOverride = "en"
    }

    override func tearDown() {
        L10n.languageOverride = nil
        super.tearDown()
    }

    func testScheduledEyeGateStatusIncludesLocalizedNameAndBodyBreakCountdown() {
        let engine = RestEngine(settings: .defaults, now: start)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start)

        XCTAssertTrue(lines[0].contains("Eye Gate"))
        XCTAssertFalse(lines[0].contains("eyeGate"))
        XCTAssertEqual(lines[1], "Next Body Break after 2 Eye Gate(s)")
    }

    func testTooltipIncludesHeaderAndStatusLines() {
        let engine = RestEngine(settings: .defaults, now: start)

        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: engine.settings, now: start)

        XCTAssertTrue(tooltip.hasPrefix("ShouldRest - The rest reminder app\n\n"))
        XCTAssertTrue(tooltip.contains("Next: Eye Gate"))
        XCTAssertTrue(tooltip.contains("Next Body Break after 2 Eye Gate(s)"))
    }

    func testDefaultMenuBarPresentationIsCompactIconOnly() {
        let engine = RestEngine(settings: .defaults, now: start)

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: engine.state, settings: engine.settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarSymbolName(state: engine.state), "timer")
    }

    func testDefaultMenuBarPresentationStaysIconOnlyAcrossStates() {
        let settings = RestSettings.defaults
        let states = [
            RestEngineState(
                scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(20 * 60), notificationAt: nil)
            ),
            RestEngineState(
                activeSession: RestSession(
                    kind: .eyeGate,
                    startedAt: start,
                    scheduledAt: start,
                    duration: 20,
                    manualFinishEnabled: false
                )
            ),
            RestEngineState(
                pause: PauseState(reason: .user, startedAt: start, until: nil)
            ),
            RestEngineState(
                activeDeferral: RestDeferral(
                    kind: .bodyBreak,
                    reason: .focusMode,
                    startedAt: start,
                    lastSeenAt: start
                )
            )
        ]

        for state in states {
            XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start), "")
        }
    }

    func testAppNameMenuBarStyleUsesCompactBrandMark() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .appName
        let engine = RestEngine(settings: settings, now: start)

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: engine.state, settings: settings, now: start), "SR")
    }

    func testMenuBarCountdownUsesCompactDuration() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .timeToBreak
        let engine = RestEngine(settings: settings, now: start)

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: engine.state, settings: settings, now: start), "20m")
    }

    func testMenuBarProgressUsesCompactRestTypePrefix() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .progress
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .bodyBreak, dueAt: start.addingTimeInterval(5 * 60), notificationAt: nil)
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start), "B 5m")
        XCTAssertEqual(MenuStatusPresenter.menuBarSymbolName(state: state), "figure.walk")
    }

    func testMenuBarActiveCountdownUsesRemainingBreakTime() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .progress
        let state = RestEngineState(
            activeSession: RestSession(
                kind: .eyeGate,
                startedAt: start,
                scheduledAt: start,
                duration: 20,
                manualFinishEnabled: false
            )
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start.addingTimeInterval(5)), "E 15s")
        XCTAssertEqual(MenuStatusPresenter.menuBarSymbolName(state: state), "timer")
    }

    func testMenuBarPausedStateStaysIconOnlyInCountdownStyles() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .timeToBreak
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(20 * 60), notificationAt: nil),
            pause: PauseState(reason: .user, startedAt: start, until: nil)
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarSymbolName(state: state), "pause.circle")
    }

    func testBodyBreakCountdownCountsScheduledEyeGateTowardBodyBreak() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start)

        XCTAssertEqual(lines[1], "Next Body Break after 1 Eye Gate(s)")
    }

    func testActiveStatusUsesLocalizedBodyBreakName() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start.addingTimeInterval(5))

        XCTAssertTrue(lines[0].contains("Body Break active"))
        XCTAssertFalse(lines[0].contains("bodyBreak"))
        XCTAssertEqual(lines.count, 1)
    }
}
