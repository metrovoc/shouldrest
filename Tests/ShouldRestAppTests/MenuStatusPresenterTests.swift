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
        XCTAssertEqual(lines[1], "Next Body Break after 2 Eye Gates")
    }

    func testTooltipIncludesHeaderAndStatusLines() {
        let engine = RestEngine(settings: .defaults, now: start)

        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: engine.settings, now: start)

        XCTAssertTrue(tooltip.hasPrefix("ShouldRest - The rest reminder app\n\n"))
        XCTAssertTrue(tooltip.contains("Next: Eye Gate"))
        XCTAssertTrue(tooltip.contains("Next Body Break after 2 Eye Gates"))
    }

    func testNextScheduledRestMenuActionNamesConcreteRestKind() {
        XCTAssertEqual(
            StatusMenuActionCopy.nextScheduledRestTitle(kind: .eyeGate),
            "Start Next Eye Gate Now"
        )
        XCTAssertEqual(
            StatusMenuActionCopy.nextScheduledRestTitle(kind: .bodyBreak),
            "Start Next Body Break Now"
        )
        XCTAssertNotEqual(
            StatusMenuActionCopy.nextScheduledRestTitle(kind: .eyeGate),
            L10n.tr("menu.takeNextScheduledRestNow")
        )

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            StatusMenuActionCopy.nextScheduledRestTitle(kind: .eyeGate),
            "立即开始下一项护眼休息"
        )
        XCTAssertEqual(
            StatusMenuActionCopy.nextScheduledRestTitle(kind: .bodyBreak),
            "立即开始下一项活动休息"
        )
        L10n.languageOverride = "en"
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
        XCTAssertEqual(content.secondary, "Next Body Break after 2 Eye Gates")
        XCTAssertEqual(content.healthBadge, "Pressure 3/10")
        XCTAssertEqual(content.icon, .restGate)
    }

    func testHeaderContentHidesHealthBadgeWhenBreakHealthModeIsDisabled() {
        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        let engine = RestEngine(settings: settings, now: start)

        let content = MenuStatusPresenter.headerContent(state: engine.state, settings: settings, now: start)

        XCTAssertNil(content.healthBadge)
    }

    func testTimedPauseStatusShowsAutomaticResumeContext() {
        let state = RestEngineState(
            pause: PauseState(
                reason: .user,
                startedAt: start,
                until: start.addingTimeInterval(30 * 60)
            )
        )

        let lines = MenuStatusPresenter.lines(state: state, settings: .defaults, now: start)
        let content = MenuStatusPresenter.headerContent(state: state, settings: .defaults, now: start)

        XCTAssertEqual(lines[0], "Paused until \(start.addingTimeInterval(30 * 60).formatted(date: .omitted, time: .shortened))")
        XCTAssertEqual(lines[1], "Resumes in 30m")
        XCTAssertEqual(content.secondary, "Resumes in 30m")
    }

    func testIndefinitePauseStatusShowsManualResumeContext() {
        let state = RestEngineState(
            pause: PauseState(reason: .user, startedAt: start, until: nil)
        )

        let lines = MenuStatusPresenter.lines(state: state, settings: .defaults, now: start)
        let content = MenuStatusPresenter.headerContent(state: state, settings: .defaults, now: start)

        XCTAssertEqual(lines, [
            "Paused indefinitely",
            "Resume from this menu when ready"
        ])
        XCTAssertEqual(content.secondary, "Resume from this menu when ready")
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

    func testLegacyMenuBarTitleStylesAreIgnoredForCompactIconOnlyMenuBar() {
        let states = [
            RestEngineState(
                scheduled: ScheduledRest(kind: .bodyBreak, dueAt: start.addingTimeInterval(5 * 60), notificationAt: nil)
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
                activeSession: RestSession(
                    kind: .eyeGate,
                    startedAt: start,
                    scheduledAt: start,
                    duration: 20,
                    manualFinishEnabled: true
                )
            ),
            RestEngineState(
                pause: PauseState(reason: .user, startedAt: start, until: nil)
            )
        ]

        for style in TrayIconStyle.allCases {
            var settings = RestSettings.defaults
            settings.presentation.trayIconStyle = style
            for state in states {
                XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: state, settings: settings, now: start.addingTimeInterval(21)), "")
            }
        }

        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: states[0]), .systemSymbol("figure.walk"))
        XCTAssertNotNil(NSImage(systemSymbolName: MenuStatusPresenter.menuBarSymbolName(state: states[0]), accessibilityDescription: nil))
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: states[3]), .systemSymbol("pause.circle"))
        XCTAssertNotNil(NSImage(systemSymbolName: MenuStatusPresenter.menuBarSymbolName(state: states[3]), accessibilityDescription: nil))
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

    func testBodyBreakCountdownCountsScheduledEyeGateTowardBodyBreak() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start)

        XCTAssertEqual(lines[1], "Next Body Break after 1 Eye Gate")
    }

    func testActiveStatusUsesLocalizedBodyBreakName() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start.addingTimeInterval(5))

        XCTAssertTrue(lines[0].contains("Body Break active"))
        XCTAssertTrue(lines[0].contains("5m remaining"))
        XCTAssertFalse(lines[0].contains("295s"))
        XCTAssertFalse(lines[0].contains("bodyBreak"))
        XCTAssertEqual(lines.count, 1)
    }

    func testActiveEyeGateStatusKeepsExactShortSeconds() {
        let state = RestEngineState(activeSession: RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        ))

        let lines = MenuStatusPresenter.lines(state: state, settings: .defaults, now: start.addingTimeInterval(5))

        XCTAssertEqual(lines.first, "Eye Gate active, 15s remaining")
    }
}
