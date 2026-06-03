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

    func testEngineKeepsAtLeastOneRestEnabled() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = false

        var engine = RestEngine(settings: settings, now: start)

        XCTAssertTrue(engine.settings.eyeGate.isEnabled)
        XCTAssertFalse(engine.settings.bodyBreak.isEnabled)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)

        var updated = RestSettings.defaults
        updated.eyeGate.isEnabled = false
        updated.bodyBreak.isEnabled = false
        updated.presentation.breakHealthMode = false
        engine.updateSettings(updated, now: start.addingTimeInterval(60))

        XCTAssertTrue(engine.settings.eyeGate.isEnabled)
        XCTAssertFalse(engine.settings.bodyBreak.isEnabled)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
    }

    func testEyeGateCannotUseOrdinaryPostponeOrSkip() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        XCTAssertEqual(engine.postponeActive(now: start), .denied(.eyeGateCannotBePostponed))
        XCTAssertEqual(engine.skipActive(now: start), .denied(.eyeGateCannotBeSkipped))
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
    }

    func testEyeGateManualFinishDoesNotEnableOrdinaryDismissal() {
        var settings = RestSettings.defaults
        settings.eyeGate.manualFinishEnabled = true
        var engine = RestEngine(settings: settings, now: start)

        _ = engine.takeNow(.eyeGate, now: start)

        XCTAssertTrue(engine.state.activeSession?.manualFinishEnabled ?? false)
        XCTAssertEqual(engine.postponeActive(now: start.addingTimeInterval(1)), .denied(.eyeGateCannotBePostponed))
        XCTAssertEqual(engine.skipActive(now: start.addingTimeInterval(1)), .denied(.eyeGateCannotBeSkipped))

        let result = engine.completeActive(now: start.addingTimeInterval(settings.eyeGate.duration), reason: .manual)
        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected manually completed Eye Gate")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .manual)
    }

    func testEyeGateEmergencyOverrideIsTrackedAsMissedRest() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        let result = engine.emergencyOverride(
            now: start,
            completedConfirmationSteps: 0
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

    func testEyeGateEmergencyOverrideIgnoresLegacyConfirmationAndHold() {
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 2,
            minimumHoldDuration: 3
        )
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        guard case .completed(let session, let reason) = engine.emergencyOverride(
            now: start.addingTimeInterval(1),
            completedConfirmationSteps: 0
        ) else {
            return XCTFail("Expected emergency override without legacy confirmation or hold")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .emergencyOverride)
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

        let repeatedIdleResult = engine.evaluate(
            now: start.addingTimeInterval(61),
            context: RestContext(idleDuration: 21)
        )
        XCTAssertEqual(repeatedIdleResult, .noChange)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)

        _ = engine.evaluate(
            now: start.addingTimeInterval(62),
            context: RestContext(idleDuration: 0)
        )
        let nextIdleResult = engine.evaluate(
            now: start.addingTimeInterval(83),
            context: RestContext(idleDuration: 20)
        )
        XCTAssertEqual(nextIdleResult, .naturalRestCredited(.eyeGate))
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 2)
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

    func testDisablingBreakHealthModeResetsDangerScore() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)
        _ = engine.completeActive(now: start.addingTimeInterval(20), reason: .completed)
        _ = engine.takeNow(.eyeGate, now: start.addingTimeInterval(40))
        _ = engine.completeActive(now: start.addingTimeInterval(60), reason: .completed)

        let bodyDue = engine.state.scheduled!.dueAt
        _ = engine.evaluate(now: bodyDue, context: RestContext(focusModeActive: true))
        XCTAssertGreaterThan(engine.state.dangerScore, 0)

        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        engine.updateSettings(settings, now: bodyDue)

        XCTAssertEqual(engine.state.dangerScore, 0)
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

    func testPauseAppExclusionInterruptsActiveBodyBreakUntilCleared() {
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
        _ = engine.takeNow(.bodyBreak, now: start)

        let interruptedAt = start.addingTimeInterval(30)
        let interrupted = engine.deferActiveForAppExclusion(
            now: interruptedAt,
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])
        )

        XCTAssertEqual(interrupted, .deferred(.bodyBreak, .appExclusion("Presentation")))
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.scheduled?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.scheduled?.dueAt, interruptedAt)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .appExclusion("Presentation"))

        let dangerAfterInterruption = engine.state.dangerScore
        let stillDeferred = engine.evaluate(
            now: interruptedAt.addingTimeInterval(10),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])
        )
        XCTAssertEqual(stillDeferred, .deferred(.bodyBreak, .appExclusion("Presentation")))
        XCTAssertEqual(engine.state.dangerScore, dangerAfterInterruption)

        let resumed = engine.evaluate(
            now: interruptedAt.addingTimeInterval(20),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: false)])
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected Body Break to restart once pause app exclusion clears")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testAppExclusionDoesNotInterruptEyeGateOrResumeOnlyActiveBodyBreak() {
        let pauseRule = AppExclusionRule(
            id: "presentation",
            name: "Presentation",
            matchTerms: ["Keynote"],
            mode: .pauseWhenMatched,
            appliesTo: [.eyeGate, .bodyBreak],
            isEnabled: true
        )
        var pauseSettings = RestSettings.defaults
        pauseSettings.appExclusions = [pauseRule]

        var eyeEngine = RestEngine(settings: pauseSettings, now: start)
        _ = eyeEngine.takeNow(.eyeGate, now: start)
        let eyeResult = eyeEngine.deferActiveForAppExclusion(
            now: start.addingTimeInterval(5),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: pauseRule, isMatched: true)])
        )
        XCTAssertEqual(eyeResult, .noChange)
        XCTAssertEqual(eyeEngine.state.activeSession?.kind, .eyeGate)

        let resumeRule = AppExclusionRule(
            id: "deep-work",
            name: "Deep Work",
            matchTerms: ["Xcode"],
            mode: .resumeOnlyWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        var resumeSettings = RestSettings.defaults
        resumeSettings.appExclusions = [resumeRule]

        var bodyEngine = RestEngine(settings: resumeSettings, now: start)
        _ = bodyEngine.takeNow(.bodyBreak, now: start)
        let bodyResult = bodyEngine.deferActiveForAppExclusion(
            now: start.addingTimeInterval(5),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: resumeRule, isMatched: false)])
        )
        XCTAssertEqual(bodyResult, .noChange)
        XCTAssertEqual(bodyEngine.state.activeSession?.kind, .bodyBreak)
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

    func testPresentationSettingsKeepsMenuBarVisibleEvenForLegacyHiddenValue() throws {
        let legacyJSON = #"""
        {
          "themeSource": "system",
          "trayIconStyle": "default",
          "showCurrentTimeDuringBodyBreak": false,
          "breakHealthMode": true,
          "showMenuBarItem": false
        }
        """#.data(using: .utf8)!

        let presentation = try JSONDecoder().decode(PresentationSettings.self, from: legacyJSON)

        XCTAssertEqual(presentation.showMenuBarItem, false)
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

    func testShortcutSettingsDefaultsToStretchlyStyleEndBreakShortcut() {
        XCTAssertEqual(ShortcutSettings.defaultEndBodyBreakShortcut, "CmdOrCtrl+X")
        XCTAssertEqual(ShortcutSettings.defaults.endBodyBreak, ShortcutSettings.defaultEndBodyBreakShortcut)
        XCTAssertEqual(ShortcutSettings.defaults.resolvedEndBodyBreakShortcut, ShortcutSettings.defaultEndBodyBreakShortcut)
        XCTAssertEqual(ShortcutSettings.defaultEmergencyEyeGateOverride, "CmdOrCtrl+Option+E")
        XCTAssertEqual(
            ShortcutSettings.defaults.emergencyEyeGateOverride,
            ShortcutSettings.defaultEmergencyEyeGateOverride
        )
        XCTAssertEqual(
            ShortcutSettings.defaults.resolvedEmergencyEyeGateOverride,
            ShortcutSettings.defaultEmergencyEyeGateOverride
        )

        var disabled = ShortcutSettings.defaults
        disabled.endBodyBreak = ""
        disabled.emergencyEyeGateOverride = ""
        XCTAssertEqual(disabled.resolvedEndBodyBreakShortcut, "")
        XCTAssertEqual(disabled.resolvedEmergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
    }

    func testShortcutSettingsResolvesLegacyBodyBreakNowAlias() {
        var shortcuts = ShortcutSettings.defaults
        shortcuts.takeBodyBreakNow = ""
        shortcuts.skipToNextBodyBreak = "Cmd+3"

        XCTAssertEqual(shortcuts.resolvedTakeBodyBreakNowShortcut, "Cmd+3")

        shortcuts.takeBodyBreakNow = "Cmd+4"
        XCTAssertEqual(shortcuts.resolvedTakeBodyBreakNowShortcut, "Cmd+4")
    }

    func testRestoredDefaultsDoNotReopenFirstRunOnboarding() {
        let restored = RestSettings.restoredDefaults

        XCTAssertTrue(restored.operations.hasCompletedOnboarding)
        XCTAssertFalse(restored.operations.resolvedShowOnboardingOnNextLaunch)
    }

    func testSettingsStoreKeepsAtLeastOneRestEnabled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)

        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = false

        try store.save(settings)
        let saved = try store.load()

        XCTAssertTrue(saved.eyeGate.isEnabled)
        XCTAssertFalse(saved.bodyBreak.isEnabled)

        let rawData = try JSONEncoder().encode(settings)
        try rawData.write(to: url, options: [.atomic])
        let loaded = try store.load()

        XCTAssertTrue(loaded.eyeGate.isEnabled)
        XCTAssertFalse(loaded.bodyBreak.isEnabled)
    }

    func testSettingsStoreMigratesLegacyEmergencyConfirmationSteps() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 3,
            minimumHoldDuration: 3
        )
        legacy.bodyBreak.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 2,
            minimumHoldDuration: 0
        )

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rawData = try JSONEncoder().encode(legacy)
        try rawData.write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(loaded.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(loaded.eyeGate.emergencyOverride.minimumHoldDuration, 0)
        XCTAssertEqual(loaded.bodyBreak.emergencyOverride.minimumHoldDuration, 0)
        let migratedData = try Data(contentsOf: url)
        let migratedRaw = try JSONDecoder().decode(RestSettings.self, from: migratedData)
        XCTAssertEqual(migratedRaw.eyeGate.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(migratedRaw.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(migratedRaw.eyeGate.emergencyOverride.minimumHoldDuration, 0)
        XCTAssertEqual(migratedRaw.bodyBreak.emergencyOverride.minimumHoldDuration, 0)

        try store.save(legacy)
        let savedData = try Data(contentsOf: url)
        let savedRaw = try JSONDecoder().decode(RestSettings.self, from: savedData)

        XCTAssertEqual(savedRaw.eyeGate.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(savedRaw.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertEqual(savedRaw.eyeGate.emergencyOverride.minimumHoldDuration, 0)
        XCTAssertEqual(savedRaw.bodyBreak.emergencyOverride.minimumHoldDuration, 0)
    }

    func testSettingsStoreMigratesBlankEmergencyShortcutToDefault() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.shortcuts.emergencyEyeGateOverride = ""

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.shortcuts.emergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertEqual(loaded.shortcuts.resolvedEmergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
        let migratedData = try Data(contentsOf: url)
        let migratedRaw = try JSONDecoder().decode(RestSettings.self, from: migratedData)
        XCTAssertEqual(migratedRaw.shortcuts.emergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
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
        XCTAssertEqual(shortcuts.resolvedEndBodyBreakShortcut, ShortcutSettings.defaultEndBodyBreakShortcut)
        XCTAssertEqual(
            shortcuts.resolvedEmergencyEyeGateOverride,
            ShortcutSettings.defaultEmergencyEyeGateOverride
        )
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
        XCTAssertNil(operations.showOnboardingOnNextLaunch)
        XCTAssertEqual(operations.resolvedPauseUntilMorningHour, OperationsSettings.defaultPauseUntilMorningHour)
        XCTAssertEqual(operations.resolvedPauseUntilMorningMode, .hour)
        XCTAssertTrue(operations.resolvedPauseForSuspendOrLock)
        XCTAssertFalse(operations.resolvedShowOnboardingOnNextLaunch)
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
