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
        XCTAssertTrue(lines[0].contains(" in "))
        XCTAssertTrue(lines[0].contains("("))
        XCTAssertFalse(lines[0].contains("eyeGate"))
        XCTAssertEqual(lines[1], "Next Body Break after 4 Eye Gates")
    }

    func testScheduledStatusShowsRelativeAndClockTimeInLocalizedCopy() {
        let dueAt = start.addingTimeInterval(10 * 60)
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: dueAt, notificationAt: nil)
        )

        XCTAssertEqual(
            MenuStatusPresenter.lines(state: state, settings: .defaults, now: start)[0],
            "Next: Eye Gate in 10m (\(dueAt.formatted(date: .omitted, time: .shortened)))"
        )

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            MenuStatusPresenter.lines(state: state, settings: .defaults, now: start)[0],
            "下一次：护眼休息，10 分钟后（\(dueAt.formatted(date: .omitted, time: .shortened))）"
        )
        L10n.languageOverride = "en"
    }

    func testTooltipIncludesHeaderAndStatusLines() {
        let engine = RestEngine(settings: .defaults, now: start)

        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: engine.settings, now: start)

        XCTAssertTrue(tooltip.hasPrefix("ShouldRest - Short eye rests, protected\n\n"))
        XCTAssertTrue(tooltip.contains("Next: Eye Gate"))
        XCTAssertTrue(tooltip.contains("Next Body Break after 4 Eye Gates"))
        XCTAssertTrue(tooltip.contains("Rest debt: 0/10"))
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

    func testHeaderContentPromotesStatusLinesAndRestDebtBadge() {
        let settings = RestSettings.defaults
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil),
            dangerScore: 3
        )

        let content = MenuStatusPresenter.headerContent(state: state, settings: settings, now: start)

        XCTAssertEqual(content.title, "ShouldRest")
        XCTAssertEqual(
            content.primary,
            "Next: Eye Gate in 10m (\(start.addingTimeInterval(10 * 60).formatted(date: .omitted, time: .shortened)))"
        )
        XCTAssertEqual(content.secondary, "Next Body Break after 4 Eye Gates")
        XCTAssertEqual(content.healthBadge, "Debt 3/10")
        XCTAssertEqual(content.icon, .restGate)
    }

    func testHeaderContentHidesHealthBadgeWhenBreakHealthModeIsDisabled() {
        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        let engine = RestEngine(settings: settings, now: start)

        let content = MenuStatusPresenter.headerContent(state: engine.state, settings: settings, now: start)

        XCTAssertNil(content.healthBadge)
    }

    func testHeaderContentHidesZeroHealthBadgeWithoutHidingTooltipHealth() {
        let engine = RestEngine(settings: .defaults, now: start)

        let content = MenuStatusPresenter.headerContent(state: engine.state, settings: engine.settings, now: start)
        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: engine.settings, now: start)

        XCTAssertNil(content.healthBadge)
        XCTAssertTrue(tooltip.contains("Rest debt: 0/10"))
    }

    func testTooltipHidesHealthWhenBreakHealthModeIsDisabled() {
        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        let engine = RestEngine(settings: settings, now: start)

        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: engine.settings, now: start)

        XCTAssertFalse(tooltip.contains("Rest debt:"))
    }

    func testMenuBarAccessibilityDescriptionIsCompactAndStateful() {
        let engine = RestEngine(settings: .defaults, now: start)

        let description = MenuStatusPresenter.menuBarAccessibilityDescription(
            state: engine.state,
            settings: engine.settings,
            now: start
        )

        XCTAssertTrue(description.hasPrefix("ShouldRest: Next: Eye Gate in "))
        XCTAssertTrue(description.contains("("))
        XCTAssertTrue(description.contains("Next Body Break after 4 Eye Gates"))
        XCTAssertFalse(description.contains("The rest reminder app"))
        XCTAssertFalse(description.contains("\n"))
        XCTAssertFalse(description.contains("Rest debt: 0/10"))
    }

    func testMenuBarAccessibilityDescriptionIncludesMeaningfulRestDebtBadge() {
        let settings = RestSettings.defaults
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .bodyBreak, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil),
            dangerScore: 4
        )

        let description = MenuStatusPresenter.menuBarAccessibilityDescription(
            state: state,
            settings: settings,
            now: start
        )

        XCTAssertTrue(description.hasPrefix("ShouldRest: Next: Body Break in 10m ("))
        XCTAssertTrue(description.contains("Debt 4/10"))
        XCTAssertFalse(description.contains("Rest debt:"))
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
        XCTAssertEqual(lines[1], "Paused by you · resumes in 30m")
        XCTAssertEqual(content.secondary, "Paused by you · resumes in 30m")
    }

    func testIndefinitePauseStatusShowsManualResumeContext() {
        let state = RestEngineState(
            pause: PauseState(reason: .user, startedAt: start, until: nil)
        )

        let lines = MenuStatusPresenter.lines(state: state, settings: .defaults, now: start)
        let content = MenuStatusPresenter.headerContent(state: state, settings: .defaults, now: start)

        XCTAssertEqual(lines, [
            "Paused indefinitely",
            "Paused by you · resume from this menu when ready"
        ])
        XCTAssertEqual(content.secondary, "Paused by you · resume from this menu when ready")
    }

    func testPauseStatusNamesNonManualPauseReasons() {
        let untilMorning = RestEngineState(
            pause: PauseState(
                reason: .untilMorning,
                startedAt: start,
                until: start.addingTimeInterval(8 * 60 * 60)
            )
        )
        let sleepOrLock = RestEngineState(
            pause: PauseState(reason: .suspendOrLock, startedAt: start, until: nil)
        )

        XCTAssertEqual(
            MenuStatusPresenter.lines(state: untilMorning, settings: .defaults, now: start)[1],
            "Until morning · resumes in 8h"
        )
        XCTAssertEqual(
            MenuStatusPresenter.lines(state: sleepOrLock, settings: .defaults, now: start)[1],
            "Sleep or lock · resume from this menu when ready"
        )
    }

    func testDeferralStatusUsesUserFacingReasonCopy() {
        let appRuleState = RestEngineState(
            activeDeferral: RestDeferral(
                kind: .bodyBreak,
                reason: .appExclusion("Presentation"),
                startedAt: start,
                lastSeenAt: start
            )
        )
        let focusState = RestEngineState(
            activeDeferral: RestDeferral(
                kind: .bodyBreak,
                reason: .focusMode,
                startedAt: start,
                lastSeenAt: start
            )
        )
        let appRuleLines = MenuStatusPresenter.lines(state: appRuleState, settings: .defaults, now: start)
        let appRuleHeader = MenuStatusPresenter.headerContent(state: appRuleState, settings: .defaults, now: start)
        let appRuleTooltip = MenuStatusPresenter.tooltip(state: appRuleState, settings: .defaults, now: start)

        XCTAssertEqual(
            appRuleLines[0],
            "Body Break delayed: App rule: Presentation"
        )
        XCTAssertEqual(appRuleLines[1], "Scheduling resumes automatically when this context ends.")
        XCTAssertEqual(appRuleHeader.secondary, "Scheduling resumes automatically when this context ends.")
        XCTAssertTrue(appRuleTooltip.contains("Scheduling resumes automatically when this context ends."))
        XCTAssertEqual(
            MenuStatusPresenter.lines(state: focusState, settings: .defaults, now: start)[0],
            "Body Break delayed: Focus or Do Not Disturb"
        )
        XCTAssertFalse(
            appRuleLines[0].localizedCaseInsensitiveContains("exclusion")
        )
        XCTAssertFalse(
            appRuleLines[0].localizedCaseInsensitiveContains("deferred")
        )

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(
            MenuStatusPresenter.lines(state: appRuleState, settings: .defaults, now: start),
            [
                "活动休息已延后：应用规则：Presentation",
                "当前上下文结束后会自动恢复调度。"
            ]
        )
    }

    func testDefaultMenuBarPresentationIsCompactIconOnly() {
        let engine = RestEngine(settings: .defaults, now: start)

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: engine.state, settings: engine.settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: engine.state), .restGate)
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: engine.state, settings: engine.settings), .restGate)
    }

    func testMenuBarHealthIndicatorUsesIconBadgeWithoutTextTitle() {
        let settings = RestSettings.defaults
        let eyeDebtState = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil),
            dangerScore: 3
        )
        let bodyDebtState = RestEngineState(
            scheduled: ScheduledRest(kind: .bodyBreak, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil),
            dangerScore: 4
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarTitle(state: eyeDebtState, settings: settings, now: start), "")
        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: eyeDebtState, settings: settings), .restGateWithHealthIndicator)
        XCTAssertEqual(
            MenuStatusPresenter.menuBarIcon(state: bodyDebtState, settings: settings),
            .systemSymbolWithHealthIndicator("figure.walk")
        )
    }

    func testMenuBarHealthIndicatorRespectsBreakHealthMode() {
        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        let state = RestEngineState(
            scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil),
            dangerScore: 3
        )

        XCTAssertEqual(MenuStatusPresenter.menuBarIcon(state: state, settings: settings), .restGate)
    }

    func testDefaultMenuBarPresentationStaysIconOnlyAcrossStates() {
        let settings = RestSettings.defaults
        let states = [
            RestEngineState(
                scheduled: ScheduledRest(kind: .eyeGate, dueAt: start.addingTimeInterval(10 * 60), notificationAt: nil)
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
        XCTAssertEqual(lines[1], "Finish from the overlay when ready.")
        XCTAssertEqual(content.primary, "Eye Gate ready to finish")
        XCTAssertEqual(content.secondary, "Finish from the overlay when ready.")
        XCTAssertFalse(lines.first?.contains("0s") ?? true)
    }

    func testBodyBreakCountdownCountsScheduledEyeGateTowardBodyBreak() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start)

        XCTAssertEqual(lines[1], "Next Body Break after 3 Eye Gates")
    }

    func testActiveStatusUsesLocalizedBodyBreakName() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let lines = MenuStatusPresenter.lines(state: engine.state, settings: engine.settings, now: start.addingTimeInterval(5))

        XCTAssertTrue(lines[0].contains("Body Break active"))
        XCTAssertTrue(lines[0].contains("5m remaining"))
        XCTAssertFalse(lines[0].contains("295s"))
        XCTAssertFalse(lines[0].contains("bodyBreak"))
        XCTAssertEqual(lines[1], "Use overlay controls to postpone, skip, or finish.")
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
        XCTAssertEqual(lines[1], "Click Emergency Exit twice in the overlay, or press Esc twice.")
    }

    func testActiveEyeGateStatusDoesNotAdvertiseEmergencyWhenDisabled() {
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride.isEnabled = false
        let state = RestEngineState(activeSession: RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        ))

        let lines = MenuStatusPresenter.lines(state: state, settings: settings, now: start.addingTimeInterval(5))

        XCTAssertEqual(lines.first, "Eye Gate active, 15s remaining")
        XCTAssertEqual(lines[1], "Keep looking away until the timer ends.")
        XCTAssertFalse(lines[1].contains("Esc"))
        XCTAssertFalse(lines[1].localizedCaseInsensitiveContains("Emergency Exit"))
    }
}
