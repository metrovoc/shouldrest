import AppKit
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

    func testHeaderContentPromotesStatusLinesAndHealthBadge() {
        let settings = RestSettings.defaults
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(20 * 60), notificationAt: nil),
            dangerScore: 3
        )

        let content = MenuStatusPresenter.headerContent(state: state, settings: settings, now: start)

        XCTAssertEqual(content.title, "ShouldRest")
        XCTAssertTrue(content.primary.hasPrefix("Next: Eye Gate at "))
        XCTAssertEqual(content.secondary, "Next Body Break after 2 Eye Gate(s)")
        XCTAssertEqual(content.healthBadge, "Danger 3/10")
        XCTAssertEqual(content.icon, .restGate)
    }

    func testHeaderContentHidesHealthBadgeWhenBreakHealthModeIsDisabled() {
        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        let engine = RestEngine(settings: settings, now: start)

        let content = MenuStatusPresenter.headerContent(state: engine.state, settings: settings, now: start)

        XCTAssertNil(content.healthBadge)
    }

    func testDefaultMenuBarPresentationIsCompactIconOnly() {
        let engine = RestEngine(settings: .defaults, now: start)

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: engine.state, settings: engine.settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: engine.state), .restGate)
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
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: state), .systemSymbol("figure.walk"))
        XCTAssertNotNil(NSImage(systemSymbolName: MenuStatusPresenter.menuBarSymbolName(state: state), accessibilityDescription: nil))
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
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: state), .restGate)
    }

    func testManualFinishStatusShowsReadyInsteadOfZeroRemaining() {
        let state = RestEngineState(activeSession: RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: true
        ))

        let lines = MenuStatusPresenter.lines(state: state, settings: .defaults, now: start.addingTimeInterval(21))
        let content = MenuStatusPresenter.headerContent(state: state, settings: .defaults, now: start.addingTimeInterval(21))

        XCTAssertEqual(lines.first, "Eye Gate ready to finish")
        XCTAssertEqual(content.primary, "Eye Gate ready to finish")
        XCTAssertFalse(lines.first?.contains("0s") ?? true)
    }

    func testManualFinishMenuBarStylesUseReadyState() {
        let state = RestEngineState(activeSession: RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: true
        ))
        var timeSettings = RestSettings.defaults
        timeSettings.presentation.trayIconStyle = .timeToBreak
        var progressSettings = RestSettings.defaults
        progressSettings.presentation.trayIconStyle = .progress

        XCTAssertEqual(
            MenuStatusPresenter.menuBarTitle(state: state, settings: timeSettings, now: start.addingTimeInterval(21)),
            "done"
        )
        XCTAssertEqual(
            MenuStatusPresenter.menuBarTitle(state: state, settings: progressSettings, now: start.addingTimeInterval(21)),
            "E done"
        )
    }

    func testMenuBarPausedStateStaysIconOnlyInCountdownStyles() {
        var settings = RestSettings.defaults
        settings.presentation.trayIconStyle = .timeToBreak
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(20 * 60), notificationAt: nil),
            pause: PauseState(reason: .user, startedAt: start, until: nil)
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: state), .systemSymbol("pause.circle"))
        XCTAssertNotNil(NSImage(systemSymbolName: MenuStatusPresenter.menuBarSymbolName(state: state), accessibilityDescription: nil))
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
