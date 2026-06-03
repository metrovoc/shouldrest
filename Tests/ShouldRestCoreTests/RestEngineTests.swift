import Foundation
import XCTest
@testable import ShouldRestCore

final class RestEngineTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testDefaultSchedulesEyeGateFirst() {
        let engine = RestEngine(settings: .defaults, now: start)

        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(engine.state.scheduled?.dueAt, start.addingTimeInterval(20 * 60))
    }

    func testEyeGateStartsWhenDue() {
        var engine = RestEngine(settings: .defaults, now: start)
        let result = engine.evaluate(now: start.addingTimeInterval(20 * 60))

        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate to start")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
    }

    func testBodyBreakAfterConfiguredEyeGates() {
        var engine = RestEngine(settings: .defaults, now: start)

        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)

        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(100))
        _ = engine.completeActive(now: start.addingTimeInterval(120), reason: .completed)
        XCTAssertEqual(engine.state.scheduled?.kind, .bodyBreak)
    }

    func testBodyBreakOnlyScheduleUsesConfiguredBodyInterval() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        settings.bodyBreak.interval = 45 * 60

        let engine = RestEngine(settings: settings, now: start)

        XCTAssertEqual(engine.state.scheduled?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.scheduled?.dueAt, start.addingTimeInterval(45 * 60))
    }

    func testEyeGateCannotUseOrdinaryPostponeOrSkip() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        XCTAssertEqual(engine.postponeActive(now: start), .denied(.eyeGateCannotBePostponed))
        XCTAssertEqual(engine.skipActive(now: start), .denied(.eyeGateCannotBeSkipped))
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
    }

    func testEyeGateEmergencyOverrideIsTrackedAsMissedRest() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        let result = engine.emergencyOverride(
            now: start.addingTimeInterval(3),
            completedConfirmationSteps: 2
        )

        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected emergency override completion")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .emergencyOverride)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 1)
        XCTAssertEqual(engine.state.dangerScore, 1)
        XCTAssertEqual(engine.state.eyeGatesSinceBodyBreak, 0)
    }

    func testEyeGateEmergencyOverrideRequiresHoldAndConfirmationFriction() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        XCTAssertEqual(
            engine.emergencyOverride(now: start.addingTimeInterval(2), completedConfirmationSteps: 2),
            .denied(.emergencyOverrideHoldIncomplete)
        )
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)

        XCTAssertEqual(
            engine.emergencyOverride(now: start.addingTimeInterval(3), completedConfirmationSteps: 1),
            .denied(.emergencyOverrideConfirmationIncomplete)
        )
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
    }

    func testBodyBreakCanBePostponedWithinPolicy() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)
        let result = engine.postponeActive(now: start.addingTimeInterval(30))

        guard case .postponed(let kind, let until) = result else {
            return XCTFail("Expected Body Break to postpone")
        }
        XCTAssertEqual(kind, .bodyBreak)
        XCTAssertEqual(until, start.addingTimeInterval(30 + 5 * 60))
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.scheduled?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.statistics.postpones, 1)
    }

    func testBodyBreakPostponeWindowPercentIsEnforced() {
        var settings = RestSettings.defaults
        settings.bodyBreak.duration = 100
        settings.bodyBreak.postpone = PostponePolicy(
            isEnabled: true,
            duration: 5 * 60,
            maxCount: 1,
            allowedDuringFirstPercent: 10
        )
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        XCTAssertEqual(
            engine.postponeActive(now: start.addingTimeInterval(20)),
            .denied(.postponeWindowExpired)
        )
    }

    func testBodyBreakPostponeLimitIsEnforced() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)
        _ = engine.postponeActive(now: start.addingTimeInterval(1))
        _ = engine.evaluate(now: start.addingTimeInterval(1 + 5 * 60))

        XCTAssertEqual(engine.postponeActive(now: start.addingTimeInterval(1 + 5 * 60)), .denied(.postponeLimitReached))
    }

    func testBodyBreakSkipCanBeDisabled() {
        var settings = RestSettings.defaults
        settings.bodyBreak.ordinarySkipEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        XCTAssertEqual(engine.skipActive(now: start), .denied(.actionDisabled))
        XCTAssertEqual(engine.state.activeSession?.kind, .bodyBreak)
    }

    func testNaturalIdleCreditsScheduledEyeGate() {
        var engine = RestEngine(settings: .defaults, now: start)
        let result = engine.evaluate(
            now: start.addingTimeInterval(60),
            context: RestContext(idleDuration: 20)
        )

        XCTAssertEqual(result, .naturalRestCredited(.eyeGate))
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.eyeGatesSinceBodyBreak, 1)
    }

    func testFocusModeDefersBodyBreakButNotEyeGateByDefault() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(40))
        _ = engine.completeActive(now: start.addingTimeInterval(60), reason: .completed)

        let bodyDue = engine.state.scheduled!.dueAt
        let bodyResult = engine.evaluate(
            now: bodyDue,
            context: RestContext(focusModeActive: true)
        )
        XCTAssertEqual(bodyResult, .deferred(.bodyBreak, .focusMode))

        _ = engine.reset(now: start)
        let eyeDue = engine.state.scheduled!.dueAt
        let eyeResult = engine.evaluate(
            now: eyeDue,
            context: RestContext(focusModeActive: true)
        )
        guard case .started(let session) = eyeResult else {
            return XCTFail("Expected Eye Gate to ignore focus-mode deferral")
        }
        XCTAssertEqual(session.kind, .eyeGate)
    }

    func testContinuousContextDeferralEscalatesOnceAndStartsImmediatelyWhenCleared() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(40))
        _ = engine.completeActive(now: start.addingTimeInterval(60), reason: .completed)

        let bodyDue = engine.state.scheduled!.dueAt
        let firstDeferral = engine.evaluate(
            now: bodyDue,
            context: RestContext(focusModeActive: true)
        )

        XCTAssertEqual(firstDeferral, .deferred(.bodyBreak, .focusMode))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .focusMode)
        XCTAssertEqual(engine.state.dangerScore, RestKind.bodyBreak.defaultHealthWeight)

        let repeatedDeferral = engine.evaluate(
            now: bodyDue.addingTimeInterval(10),
            context: RestContext(focusModeActive: true)
        )

        XCTAssertEqual(repeatedDeferral, .deferred(.bodyBreak, .focusMode))
        XCTAssertEqual(engine.state.dangerScore, RestKind.bodyBreak.defaultHealthWeight)
        XCTAssertEqual(engine.state.activeDeferral?.startedAt, bodyDue)
        XCTAssertEqual(engine.state.activeDeferral?.lastSeenAt, bodyDue.addingTimeInterval(10))

        let resumed = engine.evaluate(
            now: bodyDue.addingTimeInterval(11),
            context: RestContext(focusModeActive: false)
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected deferred Body Break to start as soon as Focus clears")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.scheduledAt, bodyDue)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testAppExclusionPauseCanTargetSpecificBreakKind() {
        let rule = AppExclusionRule(
            id: "presentation",
            name: "Presentation",
            matchTerms: ["Keynote"],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        var settings = RestSettings.defaults
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(40))
        _ = engine.completeActive(now: start.addingTimeInterval(60), reason: .completed)

        let result = engine.evaluate(
            now: engine.state.scheduled!.dueAt,
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])
        )

        XCTAssertEqual(result, .deferred(.bodyBreak, .appExclusion("Presentation")))
    }

    func testResumeOnlyAppExclusionDefersUntilMatchedThenStarts() {
        let rule = AppExclusionRule(
            id: "deep-work",
            name: "Deep Work",
            matchTerms: ["Xcode"],
            mode: .resumeOnlyWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        var settings = RestSettings.defaults
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(40))
        _ = engine.completeActive(now: start.addingTimeInterval(60), reason: .completed)

        let bodyDue = engine.state.scheduled!.dueAt
        let waiting = engine.evaluate(
            now: bodyDue,
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: false)])
        )
        XCTAssertEqual(waiting, .deferred(.bodyBreak, .appExclusion("Deep Work")))
        XCTAssertEqual(engine.state.activeDeferral?.reason, .appExclusion("Deep Work"))

        let resumed = engine.evaluate(
            now: bodyDue.addingTimeInterval(1),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected resume-only rule to start Body Break once matched")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testContentSanitizerRemovesScriptsAndDangerousAttributes() {
        let unsafe = #"""
        <p onclick="alert(1)">Stretch</p>
        <script>alert("x")</script>
        <a href="javascript:alert(1)">bad</a>
        <img src="data:text/html;base64,abc">
        <img src="https://example.com/pixel.png">
        """#

        let sanitized = ContentSanitizer.sanitizeRichText(unsafe)

        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("script"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("onclick"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("javascript:"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("data:"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("<img"))
        XCTAssertTrue(sanitized.contains("Stretch"))
    }

    func testContentLibraryCanDisableBuiltInIdeasWhileKeepingCustomBodyIdeas() {
        let custom = RestIdea(id: "custom", kind: .bodyBreak, title: "Custom", body: "Move")
        let library = ContentLibrarySettings(
            useBuiltInIdeas: false,
            customBodyBreakIdeas: [custom],
            localImagePaths: []
        )

        XCTAssertEqual(library.ideas(for: .eyeGate), [])
        XCTAssertEqual(library.ideas(for: .bodyBreak), [custom])
    }

    func testPresentationSettingsDecodesLegacyMissingMenuBarVisibility() throws {
        let legacyJSON = #"""
        {
          "themeSource": "system",
          "trayIconStyle": "default",
          "showCurrentTimeDuringBodyBreak": false,
          "breakHealthMode": true
        }
        """#.data(using: .utf8)!

        let presentation = try JSONDecoder().decode(PresentationSettings.self, from: legacyJSON)

        XCTAssertNil(presentation.showMenuBarItem)
        XCTAssertNil(presentation.languageIdentifier)
        XCTAssertTrue(presentation.resolvedShowMenuBarItem)
    }

    func testSettingsStoreRoundTripsDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)

        try store.save(.defaults)
        let loaded = try store.load()

        XCTAssertEqual(loaded, .defaults)
    }

    func testEnforcementProfileDecodesLegacyDisplaySettings() throws {
        let legacyJSON = #"""
        {
          "coversAllDisplays": true,
          "usesScreenSaverLevel": true,
          "isOpaque": true,
          "opacity": 1,
          "allowRegularWindowMode": false,
          "contentDisplay": "primary",
          "blankSecondaryDisplays": true
        }
        """#.data(using: .utf8)!

        let profile = try JSONDecoder().decode(EnforcementProfile.self, from: legacyJSON)

        XCTAssertTrue(profile.coversAllDisplays)
        XCTAssertNil(profile.coveredDisplay)
        XCTAssertEqual(profile.contentDisplay, .primary)
        XCTAssertNil(profile.configuredDisplayIndex)
    }

    func testShortcutSettingsDecodesLegacyMissingEmergencyShortcut() throws {
        let legacyJSON = #"""
        {
          "pauseToggle": "",
          "pauseFor30Minutes": "",
          "pauseFor1Hour": "",
          "pauseFor2Hours": "",
          "pauseFor5Hours": "",
          "pauseUntilMorning": "",
          "takeEyeGateNow": "",
          "takeBodyBreakNow": "",
          "skipToNextBodyBreak": "",
          "reset": ""
        }
        """#.data(using: .utf8)!

        let shortcuts = try JSONDecoder().decode(ShortcutSettings.self, from: legacyJSON)

        XCTAssertNil(shortcuts.emergencyEyeGateOverride)
        XCTAssertNil(shortcuts.endBodyBreak)
        XCTAssertNil(shortcuts.skipToNextScheduledRest)
    }

    func testOperationsSettingsCalculatesUntilMorningUsingConfiguredHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let earlyMorning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 2, minute: 0))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 20, minute: 0))!

        XCTAssertEqual(
            OperationsSettings.secondsUntilMorning(from: earlyMorning, calendar: calendar, morningHour: 6),
            4 * 60 * 60
        )
        XCTAssertEqual(
            OperationsSettings.secondsUntilMorning(from: evening, calendar: calendar, morningHour: 8),
            12 * 60 * 60
        )
    }

    func testOperationsSettingsCalculatesUntilMorningUsingSunrise() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let beforeSunrise = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 8, minute: 0))!
        let afterSunrise = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 20, minute: 0))!

        let sameDaySeconds = OperationsSettings.secondsUntilMorning(
            from: beforeSunrise,
            calendar: calendar,
            morningHour: 6,
            mode: .sunrise,
            latitude: 42.3,
            longitude: -71
        )
        let nextDaySeconds = OperationsSettings.secondsUntilMorning(
            from: afterSunrise,
            calendar: calendar,
            morningHour: 6,
            mode: .sunrise,
            latitude: 42.3,
            longitude: -71
        )

        XCTAssertGreaterThan(sameDaySeconds, 60 * 60)
        XCTAssertLessThan(sameDaySeconds, 2 * 60 * 60)
        XCTAssertGreaterThan(nextDaySeconds, 12 * 60 * 60)
        XCTAssertLessThan(nextDaySeconds, 15 * 60 * 60)
    }

    func testOperationsSettingsDecodesLegacyMissingPauseUntilMorningHour() throws {
        let legacyJSON = #"""
        {
          "openAtLogin": false,
          "checkForUpdates": true,
          "notifyNewVersion": true,
          "updateFeedURL": "",
          "hasCompletedOnboarding": false
        }
        """#.data(using: .utf8)!

        let operations = try JSONDecoder().decode(OperationsSettings.self, from: legacyJSON)

        XCTAssertNil(operations.pauseUntilMorningHour)
        XCTAssertNil(operations.pauseUntilMorningMode)
        XCTAssertNil(operations.pauseUntilMorningLatitude)
        XCTAssertNil(operations.pauseUntilMorningLongitude)
        XCTAssertNil(operations.pauseForSuspendOrLock)
        XCTAssertEqual(operations.resolvedPauseUntilMorningHour, OperationsSettings.defaultPauseUntilMorningHour)
        XCTAssertEqual(operations.resolvedPauseUntilMorningMode, .hour)
        XCTAssertTrue(operations.resolvedPauseForSuspendOrLock)
    }

    func testWorkingHoursSupportsDayAndOvernightWindows() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10, minute: 0))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 20, minute: 0))!
        let late = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 23, minute: 0))!
        let early = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 2, minute: 0))!

        let daytime = WorkingHoursSettings(isEnabled: true, startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)
        XCTAssertTrue(daytime.contains(day, calendar: calendar))
        XCTAssertFalse(daytime.contains(evening, calendar: calendar))

        let overnight = WorkingHoursSettings(isEnabled: true, startMinuteOfDay: 22 * 60, endMinuteOfDay: 4 * 60)
        XCTAssertTrue(overnight.contains(late, calendar: calendar))
        XCTAssertTrue(overnight.contains(early, calendar: calendar))
        XCTAssertFalse(overnight.contains(day, calendar: calendar))
    }
}
