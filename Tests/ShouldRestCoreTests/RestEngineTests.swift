import Foundation
import XCTest
@testable import ShouldRestCore

final class RestEngineTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    // MARK: - Scheduling

    func testDefaultSchedulesEyeGateFirst() {
        let engine = RestEngine(settings: .defaults, now: start)

        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(engine.state.scheduled?.dueAt, start.addingTimeInterval(20 * 60))
        XCTAssertEqual(engine.settings.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
    }

    func testRestoringStatePreservesExistingSchedule() throws {
        let original = RestEngine(settings: .defaults, now: start)
        let scheduled = try XCTUnwrap(original.state.scheduled)
        let restartedAt = start.addingTimeInterval(90)

        let restored = RestEngine(settings: .defaults, restoring: original.state, now: restartedAt)

        XCTAssertEqual(restored.state.scheduled, scheduled)
        XCTAssertEqual(restored.state.lastEvaluatedAt, original.state.lastEvaluatedAt)
        XCTAssertEqual(restored.state.scheduled?.dueAt, start.addingTimeInterval(20 * 60))
    }

    func testDueEyeGateWaitsForNaturalPauseInsteadOfCuttingIntoInput() {
        var engine = RestEngine(settings: .defaults, now: start)
        let dueAt = start.addingTimeInterval(20 * 60)

        XCTAssertEqual(engine.evaluate(now: dueAt, context: RestContext(idleDuration: 0)), .notificationDue(.eyeGate))
        XCTAssertEqual(
            engine.evaluate(now: dueAt.addingTimeInterval(5), context: RestContext(idleDuration: 0.5)),
            .noChange
        )
        XCTAssertNil(engine.state.activeSession)

        let result = engine.evaluate(
            now: dueAt.addingTimeInterval(10),
            context: RestContext(idleDuration: RestTiming.naturalPause)
        )

        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate to start at the first natural pause")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(session.startedAt, dueAt.addingTimeInterval(10))
        XCTAssertEqual(session.scheduledAt, dueAt)
    }

    func testDueRestStartsAtDeadlineDuringContinuousInput() {
        var engine = RestEngine(settings: .defaults, now: start)
        let dueAt = start.addingTimeInterval(20 * 60)
        let deadline = dueAt.addingTimeInterval(RestTiming.slack(forInterval: 20 * 60))

        var now = dueAt
        while now < deadline {
            if case .started = engine.evaluate(now: now, context: RestContext(idleDuration: 0.5)) {
                return XCTFail("Expected Eye Gate to wait for a pause before its deadline")
            }
            now = now.addingTimeInterval(1)
        }

        guard case .started(let session) = engine.evaluate(now: deadline, context: RestContext(idleDuration: 0.5)) else {
            return XCTFail("Expected Eye Gate to start at its deadline")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(session.scheduledAt, dueAt)
    }

    func testRestStartsEarlyOnlyDuringClearPauseInsideItsWindow() {
        var engine = RestEngine(settings: .defaults, now: start)
        let dueAt = start.addingTimeInterval(20 * 60)
        _ = engine.evaluate(now: dueAt.addingTimeInterval(-90), context: RestContext(idleDuration: 0))

        XCTAssertEqual(
            engine.evaluate(now: dueAt.addingTimeInterval(-70), context: RestContext(idleDuration: 20)),
            .noChange
        )
        XCTAssertEqual(
            engine.evaluate(now: dueAt.addingTimeInterval(-40), context: RestContext(idleDuration: 0)),
            .noChange
        )
        XCTAssertEqual(
            engine.evaluate(now: dueAt.addingTimeInterval(-30), context: RestContext(idleDuration: 10)),
            .noChange
        )

        XCTAssertEqual(engine.evaluate(now: dueAt.addingTimeInterval(-25),
                                       context: RestContext(idleDuration: RestTiming.clearPause)), .notificationDue(.eyeGate))
        let result = engine.evaluate(
            now: dueAt.addingTimeInterval(-15),
            context: RestContext(idleDuration: RestTiming.clearPause)
        )

        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate to start early during a clear pause")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(session.startedAt, dueAt.addingTimeInterval(-15))
        XCTAssertEqual(session.scheduledAt, dueAt)
    }

    func testEarlyStartDuringDeferringContextDoesNotRecordDeferral() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        let bodyDue = start.addingTimeInterval(10 * 60)

        let early = engine.evaluate(
            now: bodyDue.addingTimeInterval(-20),
            context: RestContext(idleDuration: 60, focusModeActive: true)
        )

        XCTAssertEqual(early, .noChange)
        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.dangerScore, 0)

        XCTAssertEqual(
            engine.evaluate(now: bodyDue, context: atNaturalPause(RestContext(focusModeActive: true))),
            .deferred(.bodyBreak, .focusMode)
        )
    }

    func testBodyBreakUsesIndependentWallClockDebt() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 10 * 60
        settings.bodyBreak.interval = 25 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        let result = engine.evaluate(now: start.addingTimeInterval(25 * 60), context: atNaturalPause())

        guard case .started(let session) = result else {
            return XCTFail("Expected Body Break to start from independent body debt")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), settings.bodyBreak.interval)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), settings.eyeGate.interval * 2)
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

    func testNotificationLeadFiresOnceWithoutDueDriftDuringShortIdle() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        let notificationAt = start.addingTimeInterval(
            settings.bodyBreak.interval - settings.notifications.bodyBreakLeadTime
        )

        XCTAssertEqual(
            engine.evaluate(now: notificationAt, context: RestContext(idleDuration: 0)),
            .notificationDue(.bodyBreak)
        )
        XCTAssertTrue(engine.state.scheduled?.notificationSent ?? false)

        let driftedResult = engine.evaluate(
            now: notificationAt.addingTimeInterval(4),
            context: RestContext(idleDuration: 2)
        )

        XCTAssertEqual(driftedResult, .noChange)
        XCTAssertTrue(engine.state.scheduled?.notificationSent ?? false)
        XCTAssertEqual(
            engine.state.scheduled?.dueAt,
            start.addingTimeInterval(settings.bodyBreak.interval)
        )
    }

    // MARK: - Coalescing rests

    func testBodyBreakTakesOverEyeGateWhenItIsAboutToFallDue() {
        var settings = RestSettings.defaults
        settings.bodyBreak.interval = 21 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        let result = engine.evaluate(now: start.addingTimeInterval(20 * 60), context: atNaturalPause())

        guard case .started(let session) = result else {
            return XCTFail("Expected one interruption for both rests")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.scheduledAt, start.addingTimeInterval(21 * 60))

        _ = engine.completeActive(now: session.startedAt.addingTimeInterval(session.duration))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    func testPostponedBodyBreakIsNotPulledEarlyByEyeGate() {
        var settings = RestSettings.defaults
        settings.bodyBreak.postpone.duration = 10 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)
        let postponedAt = start.addingTimeInterval(14 * 60 + 1)
        _ = engine.takeNow(.bodyBreak, now: start.addingTimeInterval(14 * 60))
        guard case .postponed(_, let until) = engine.postponeActive(now: postponedAt) else {
            return XCTFail("Expected Body Break postpone")
        }
        XCTAssertNil(engine.state.activeSession)

        let eyeDue = engine.startWindow(for: .eyeGate, now: postponedAt).dueAt
        XCTAssertLessThan(eyeDue, until)
        let result = engine.evaluate(now: eyeDue, context: atNaturalPause())

        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate to start while the Body Break stays postponed")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.bodySuppressedUntil, until)
    }

    func testPostponingBodyBreakContinuesDueEyeGateInSameInterruption() {
        var engine = RestEngine(settings: withoutCues(alignedSettings()), now: start)
        let dueAt = start.addingTimeInterval(20 * 60)
        guard case .started(let body) = engine.evaluate(now: dueAt, context: atNaturalPause()) else {
            return XCTFail("Expected Body Break for both due rests")
        }
        XCTAssertEqual(body.kind, .bodyBreak)

        let postponedAt = dueAt.addingTimeInterval(3)
        let result = engine.postponeActive(now: postponedAt)

        XCTAssertEqual(result, .postponed(.bodyBreak, until: postponedAt.addingTimeInterval(5 * 60)))
        let continuation = engine.state.activeSession
        XCTAssertEqual(continuation?.kind, .eyeGate)
        XCTAssertEqual(continuation?.startedAt, postponedAt)
        XCTAssertEqual(continuation?.duration, engine.settings.eyeGate.duration - 3)
        XCTAssertNil(engine.state.scheduled)

        let completedAt = postponedAt.addingTimeInterval(engine.settings.eyeGate.duration - 3)
        guard case .completed(let completed, .completed) = engine.completeActive(now: completedAt) else {
            return XCTFail("Expected continued Eye Gate to complete")
        }
        XCTAssertEqual(completed.kind, .eyeGate)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.postpones, 1)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.bodySuppressedUntil, postponedAt.addingTimeInterval(5 * 60))
    }

    func testPostponingBodyBreakContinuesEyeGateThatIsDueWithinMinutes() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start.addingTimeInterval(16 * 60))
        let postponedAt = start.addingTimeInterval(16 * 60 + 3)

        _ = engine.postponeActive(now: postponedAt)

        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
        XCTAssertEqual(engine.state.activeSession?.duration, engine.settings.eyeGate.duration - 3)
    }

    func testSkippingBodyBreakAfterEyeRestDurationSatisfiesEyes() {
        var engine = RestEngine(settings: withoutCues(alignedSettings()), now: start)
        let dueAt = start.addingTimeInterval(20 * 60)
        _ = engine.evaluate(now: dueAt, context: atNaturalPause())

        let skippedAt = dueAt.addingTimeInterval(30)
        guard case .completed(let session, .skipped) = engine.skipActive(now: skippedAt) else {
            return XCTFail("Expected Body Break skip")
        }

        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 0)
        XCTAssertEqual(
            engine.startWindow(for: .eyeGate, now: skippedAt).dueAt,
            skippedAt.addingTimeInterval(20 * 60)
        )
    }

    func testEyeGateContinuationRespectsEyeGateDeferral() {
        var settings = alignedSettings()
        settings.focusMode.deferEyeGate = true
        settings.focusMode.deferBodyBreak = false
        var engine = RestEngine(settings: withoutCues(settings), now: start)
        let dueAt = start.addingTimeInterval(20 * 60)
        let focus = RestContext(focusModeActive: true)

        guard case .started(let body) = engine.evaluate(now: dueAt, context: atNaturalPause(focus)) else {
            return XCTFail("Expected Body Break while Focus defers the Eye Gate")
        }
        XCTAssertEqual(body.kind, .bodyBreak)

        _ = engine.postponeActive(now: dueAt.addingTimeInterval(3), context: focus)
        XCTAssertNil(engine.state.activeSession)

        guard case .started(let eye) = engine.evaluate(now: dueAt.addingTimeInterval(10), context: atNaturalPause()) else {
            return XCTFail("Expected the due Eye Gate once Focus clears")
        }
        XCTAssertEqual(eye.kind, .eyeGate)
    }

    // MARK: - Strict and negotiable controls

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
        let result = engine.emergencyOverride(now: start)

        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected emergency override completion")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .emergencyOverride)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 1)
        XCTAssertEqual(engine.state.dangerScore, 1)
        XCTAssertEqual(engine.state.eyeDebt, 0)
    }

    func testEyeGateEmergencyOverrideIgnoresLegacyConfirmationAndHold() {
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 2
        )
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        guard case .completed(let session, let reason) = engine.emergencyOverride(now: start.addingTimeInterval(1)) else {
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
        XCTAssertEqual(engine.state.scheduled?.dueAt, until)
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
        var engine = RestEngine(settings: withoutCues(.defaults), now: start)
        _ = engine.takeNow(.bodyBreak, now: start)
        _ = engine.postponeActive(now: start.addingTimeInterval(1))
        guard case .started = engine.evaluate(now: start.addingTimeInterval(1 + 5 * 60), context: atNaturalPause()) else {
            return XCTFail("Expected postponed Body Break to return")
        }

        XCTAssertEqual(engine.postponeActive(now: start.addingTimeInterval(2 + 5 * 60)), .denied(.postponeLimitReached))
    }

    func testBodyBreakSkipCanBeDisabled() {
        var settings = RestSettings.defaults
        settings.bodyBreak.ordinarySkipEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        XCTAssertEqual(engine.skipActive(now: start), .denied(.actionDisabled))
        XCTAssertEqual(engine.state.activeSession?.kind, .bodyBreak)
    }

    // MARK: - Pause

    func testPauseDuringSkippableBodyBreakRecordsSkippedRestAndPauses() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let result = engine.pause(for: 30 * 60, now: start.addingTimeInterval(1), reason: .user)

        guard case .paused(let pause) = result else {
            return XCTFail("Expected pause to skip active Body Break and pause")
        }
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.pause, pause)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 1)
        XCTAssertEqual(engine.state.dangerScore, RestKind.bodyBreak.defaultHealthWeight)
    }

    func testPauseCompletesElapsedAutomaticBodyBreakBeforePausing() {
        let settings = RestSettings.defaults
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let result = engine.pause(
            for: nil,
            now: start.addingTimeInterval(settings.bodyBreak.duration),
            reason: .user
        )

        guard case .paused = result else {
            return XCTFail("Expected pause after completing elapsed Body Break")
        }
        XCTAssertNil(engine.state.activeSession)
        XCTAssertNotNil(engine.state.pause)
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 0)
        XCTAssertEqual(engine.state.dangerScore, 0)
    }

    func testPauseNaturallyCompletesManualBodyBreakBeforePausing() {
        var settings = RestSettings.defaults
        settings.bodyBreak.manualFinishEnabled = true
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let result = engine.pause(
            for: nil,
            now: start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            reason: .user,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        guard case .paused = result else {
            return XCTFail("Expected pause after naturally completing Body Break")
        }
        XCTAssertNil(engine.state.activeSession)
        XCTAssertNotNil(engine.state.pause)
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertEqual(engine.state.eyeDebt, 0)
    }

    func testPauseCompletesElapsedEyeGateBeforeApplyingPause() {
        let settings = RestSettings.defaults
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        let result = engine.pause(
            for: nil,
            now: start.addingTimeInterval(settings.eyeGate.duration),
            reason: .user
        )

        guard case .paused = result else {
            return XCTFail("Expected pause after completing elapsed Eye Gate")
        }
        XCTAssertNil(engine.state.activeSession)
        XCTAssertNotNil(engine.state.pause)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 0)
    }

    func testPauseSkippingBodyBreakDuringIdleDropsUnresolvedExposureAtAwayThreshold() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let started = engine.takeNow(
            .bodyBreak,
            now: start.addingTimeInterval(9 * 60),
            context: RestContext(idleDuration: 9 * 60)
        )
        guard case .started = started else {
            return XCTFail("Expected Body Break to start during the unattended stretch")
        }
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.pendingEyeDebt, 9 * 60)

        let paused = engine.pause(
            for: nil,
            now: start.addingTimeInterval(9 * 60 + 30),
            reason: .user,
            context: RestContext(idleDuration: 9 * 60 + 30)
        )
        guard case .paused = paused else {
            return XCTFail("Expected pause to skip active Body Break and pause")
        }
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0, "Thirty seconds on the Body Break overlay rested the eyes")

        _ = engine.evaluate(
            now: start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 1)
    }

    func testPauseSkippingBodyBreakDoesNotCreditTheSameAbsenceTwice() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        settings.bodyBreak.duration = 20 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))

        let idleStartedAt = start.addingTimeInterval(60)
        let started = engine.takeNow(
            .bodyBreak,
            now: idleStartedAt.addingTimeInterval(8 * 60),
            context: RestContext(idleDuration: 8 * 60)
        )
        guard case .started = started else {
            return XCTFail("Expected Body Break to start during short idle")
        }

        let awayAt = idleStartedAt.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        _ = engine.pause(
            for: nil,
            now: awayAt,
            reason: .user,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)

        _ = engine.evaluate(
            now: awayAt.addingTimeInterval(1),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime + 1)
        )

        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testPauseCannotBypassStrictBodyBreakSkipPolicy() {
        var settings = RestSettings.defaults
        settings.bodyBreak.ordinarySkipEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let result = engine.pause(for: 30 * 60, now: start.addingTimeInterval(1), reason: .user)

        XCTAssertEqual(result, .denied(.actionDisabled))
        XCTAssertEqual(engine.state.activeSession?.kind, .bodyBreak)
        XCTAssertNil(engine.state.pause)
        XCTAssertEqual(engine.state.statistics.skippedBodyBreaks, 0)
    }

    func testBodyBreakOnlyPauseKeepsEyeGateScheduled() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 20 * 60
        settings.bodyBreak.interval = 5 * 60
        var engine = RestEngine(settings: settings, now: start)

        let result = engine.pause(
            for: 30 * 60,
            now: start,
            reason: .user,
            appliesTo: [.bodyBreak]
        )

        guard case .paused(let pause) = result else {
            return XCTFail("Expected Body Break-only pause")
        }
        XCTAssertEqual(pause.appliesTo, [.bodyBreak])
        XCTAssertEqual(engine.state.pause, pause)
        let scheduled = try XCTUnwrap(engine.state.scheduled)
        XCTAssertEqual(scheduled.kind, .eyeGate)
        XCTAssertEqual(scheduled.dueAt, start.addingTimeInterval(settings.eyeGate.interval))
    }

    func testBodyBreakOnlyPauseAccruesOnlyEyeGateDebt() {
        var engine = RestEngine(settings: .defaults, now: start)

        _ = engine.pause(for: 30 * 60, now: start, reason: .user, appliesTo: [.bodyBreak])
        _ = engine.evaluate(now: start.addingTimeInterval(10 * 60), context: RestContext(idleDuration: 0))

        XCTAssertEqual(engine.state.eyeDebt, 10 * 60)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
    }

    func testTakeNowCannotCreateActiveRestWhilePaused() {
        var engine = RestEngine(settings: .defaults, now: start)
        let pauseResult = engine.pause(for: 60 * 60, now: start, reason: .user)
        guard case .paused(let pause) = pauseResult else {
            return XCTFail("Expected initial pause")
        }

        let result = engine.takeNow(.eyeGate, now: start.addingTimeInterval(1))

        XCTAssertEqual(result, .denied(.alreadyPaused))
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.pause, pause)
    }

    func testUserPauseDuringShortIdleStillDropsTheStretchOnceItBecomesAway() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let shortIdleAt = start.addingTimeInterval(9 * 60)
        _ = engine.evaluate(now: shortIdleAt, context: RestContext(idleDuration: 9 * 60))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 9 * 60)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 9 * 60)
        XCTAssertEqual(engine.state.eyeDebt, 0)

        _ = engine.pause(
            for: nil,
            now: shortIdleAt,
            reason: .user,
            context: RestContext(idleDuration: 9 * 60)
        )

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        XCTAssertEqual(engine.resume(now: awayAt), .resumed)
        let result = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(result, .noChange)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testUserResumeDuringShortIdleKeepsTheStretchUnresolvedUntilThreshold() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let pauseAt = start.addingTimeInterval(9 * 60)
        _ = engine.evaluate(now: pauseAt, context: RestContext(idleDuration: 9 * 60))
        _ = engine.pause(for: nil, now: pauseAt, reason: .user, context: RestContext(idleDuration: 9 * 60))
        _ = engine.resume(now: start.addingTimeInterval(9 * 60 + 30))
        XCTAssertEqual(engine.state.pendingEyeDebt, 9 * 60)

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        _ = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testPausedTickCrossingAwayThresholdDropsStretchBeforeResumeInputResetsIdle() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let pauseAt = start.addingTimeInterval(9 * 60)
        _ = engine.evaluate(now: pauseAt, context: RestContext(idleDuration: 9 * 60))
        _ = engine.pause(for: nil, now: pauseAt, reason: .user, context: RestContext(idleDuration: 9 * 60))

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let pausedAway = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )
        guard case .paused = pausedAway else {
            return XCTFail("Expected pause to remain active while the away threshold is reached")
        }
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)

        _ = engine.resume(now: awayAt.addingTimeInterval(1))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    func testPausedTickDoesNotCreateNaturalCreditFromPreIdlePauseTime() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.pause(for: nil, now: start, reason: .user)

        let result = engine.evaluate(
            now: start.addingTimeInterval(700),
            context: RestContext(idleDuration: 10 * 60)
        )

        guard case .paused = result else {
            return XCTFail("Expected pause to remain active")
        }
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testPausedTickWithoutNaturalBreaksDoesNotInventDebtFromPreIdlePauseTime() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.pause(for: nil, now: start, reason: .user)

        _ = engine.evaluate(
            now: start.addingTimeInterval(700),
            context: RestContext(idleDuration: 10 * 60)
        )

        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    // MARK: - Exposure and absence

    func testEyeGateAccruesDuringIdleUntilConfiguredAwayThreshold() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = settings.eyeGate.interval + 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        let result = engine.evaluate(
            now: start.addingTimeInterval(settings.eyeGate.interval),
            context: RestContext(idleDuration: settings.eyeGate.interval)
        )

        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate to start after screen exposure even without input")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), settings.eyeGate.interval)
    }

    func testBodyBreakAccruesDuringIdleUntilConfiguredAwayThreshold() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = settings.bodyBreak.interval + 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        let result = engine.evaluate(
            now: start.addingTimeInterval(settings.bodyBreak.interval),
            context: RestContext(idleDuration: settings.bodyBreak.interval)
        )

        guard case .started(let session) = result else {
            return XCTFail("Expected Body Break to start from wall-clock computer use")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), settings.bodyBreak.interval)
    }

    func testReturnBeforeAwayThresholdTurnsIdleStretchIntoScreenTime() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))

        _ = engine.evaluate(now: start.addingTimeInterval(360), context: RestContext(idleDuration: 300))
        XCTAssertEqual(engine.state.eyeDebt, 60)
        XCTAssertEqual(engine.state.pendingEyeDebt, 300)

        _ = engine.evaluate(now: start.addingTimeInterval(361), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.eyeDebt, 361)
        XCTAssertEqual(engine.state.pendingEyeDebt, 0)
    }

    func testNaturalIdleCreditsEyeGateOnlyAfterConfiguredAwayThresholdAndOnlyWhenDebtExists() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        XCTAssertGreaterThan(engine.state.eyeDebt, 0)

        let shortIdleResult = engine.evaluate(
            now: start.addingTimeInterval(80),
            context: RestContext(idleDuration: engine.settings.eyeGate.duration)
        )
        XCTAssertEqual(shortIdleResult, .noChange)
        XCTAssertGreaterThan(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)

        let awayThreshold = engine.settings.naturalBreaks.inactivityResetTime
        let result = engine.evaluate(
            now: start.addingTimeInterval(60 + awayThreshold),
            context: RestContext(idleDuration: awayThreshold)
        )
        XCTAssertEqual(result, .naturalRestsCredited([.eyeGate]))
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)

        let repeatedIdleResult = engine.evaluate(
            now: start.addingTimeInterval(64 + awayThreshold),
            context: RestContext(idleDuration: awayThreshold + 4)
        )
        XCTAssertEqual(repeatedIdleResult, .noChange)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)

        _ = engine.evaluate(
            now: start.addingTimeInterval(65 + awayThreshold),
            context: RestContext(idleDuration: 0)
        )
        _ = engine.evaluate(
            now: start.addingTimeInterval(125 + awayThreshold),
            context: RestContext(idleDuration: 0)
        )
        let nextIdleResult = engine.evaluate(
            now: start.addingTimeInterval(125 + awayThreshold * 2),
            context: RestContext(idleDuration: awayThreshold)
        )
        XCTAssertEqual(nextIdleResult, .naturalRestsCredited([.eyeGate]))
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 2)
    }

    func testAwayThresholdDropsIdleStretchWhenNaturalBreakCreditsAreDisabled() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.naturalBreaks.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.bodyDebt, 60)

        let shortIdleResult = engine.evaluate(
            now: start.addingTimeInterval(120),
            context: RestContext(idleDuration: 60)
        )
        XCTAssertEqual(shortIdleResult, .noChange)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 120)

        let awayThreshold = engine.settings.naturalBreaks.inactivityResetTime
        let longIdleResult = engine.evaluate(
            now: start.addingTimeInterval(60 + awayThreshold),
            context: RestContext(idleDuration: awayThreshold)
        )
        XCTAssertEqual(longIdleResult, .noChange)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 60)

        _ = engine.evaluate(
            now: start.addingTimeInterval(64 + awayThreshold),
            context: RestContext(idleDuration: awayThreshold + 4)
        )
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 60)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testWatchedScreenAccruesExposureAndNeverCountsAsAway() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        var engine = RestEngine(settings: withoutCues(settings), now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))

        let watching = engine.evaluate(
            now: start.addingTimeInterval(60 + 15 * 60),
            context: RestContext(idleDuration: 15 * 60, screenWatched: true)
        )

        XCTAssertEqual(watching, .noChange)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.eyeDebt, 16 * 60)

        let result = engine.evaluate(
            now: start.addingTimeInterval(20 * 60),
            context: RestContext(idleDuration: 19 * 60, screenWatched: true)
        )
        guard case .started(let session) = result else {
            return XCTFail("Expected Eye Gate during long playback without input")
        }
        XCTAssertEqual(session.kind, .eyeGate)
    }

    func testAwayClockStartsWhenPlaybackStops() {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)

        _ = engine.evaluate(
            now: start.addingTimeInterval(5 * 60),
            context: RestContext(idleDuration: 5 * 60, screenWatched: true)
        )
        XCTAssertEqual(engine.state.eyeDebt, 5 * 60)

        let fiveMinutesAfterPlayback = engine.evaluate(
            now: start.addingTimeInterval(10 * 60),
            context: RestContext(idleDuration: 10 * 60)
        )
        XCTAssertEqual(fiveMinutesAfterPlayback, .noChange)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 10 * 60)

        let result = engine.evaluate(
            now: start.addingTimeInterval(15 * 60),
            context: RestContext(idleDuration: 15 * 60)
        )
        XCTAssertEqual(result, .naturalRestsCredited([.eyeGate]))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
    }

    func testVerifiedScreenOffCreditsEyeGateWithoutAwayThreshold() {
        var engine = RestEngine(settings: .defaults, now: start)
        let lockedAt = start.addingTimeInterval(10 * 60)
        _ = engine.evaluate(now: lockedAt, context: RestContext(idleDuration: 0))
        _ = engine.pause(for: nil, now: lockedAt, reason: .suspendOrLock)

        let unlockedAt = lockedAt.addingTimeInterval(60)
        _ = engine.resume(now: unlockedAt)
        let result = engine.evaluate(
            now: unlockedAt,
            context: RestContext(idleDuration: 60, screenOffDuration: 60)
        )

        XCTAssertEqual(result, .naturalRestsCredited([.eyeGate]))
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 10 * 60)
    }

    func testVerifiedScreenOffAsLongAsBodyBreakCreditsBothRests() {
        var engine = RestEngine(settings: .defaults, now: start)
        let lockedAt = start.addingTimeInterval(10 * 60)
        _ = engine.evaluate(now: lockedAt, context: RestContext(idleDuration: 0))
        _ = engine.pause(for: nil, now: lockedAt, reason: .suspendOrLock)

        let unlockedAt = lockedAt.addingTimeInterval(engine.settings.bodyBreak.duration)
        _ = engine.resume(now: unlockedAt)
        let result = engine.evaluate(
            now: unlockedAt,
            context: RestContext(
                idleDuration: engine.settings.bodyBreak.duration,
                screenOffDuration: engine.settings.bodyBreak.duration
            )
        )

        XCTAssertEqual(result, .naturalRestsCredited([.eyeGate, .bodyBreak]))
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    func testSuspendResumeKeepsPreSuspendIdleStretchForAwayResolution() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let idleStartedAt = start.addingTimeInterval(60)
        _ = engine.evaluate(now: idleStartedAt, context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.bodyDebt, 60)

        let sleepAt = idleStartedAt.addingTimeInterval(9 * 60)
        _ = engine.pause(
            for: nil,
            now: sleepAt,
            reason: .suspendOrLock,
            context: RestContext(idleDuration: 9 * 60)
        )
        XCTAssertEqual(engine.state.bodyDebt, 60)
        XCTAssertEqual(engine.state.pendingBodyDebt, 9 * 60)

        let wakeAt = sleepAt.addingTimeInterval(60)
        _ = engine.resume(now: wakeAt)
        let result = engine.evaluate(now: wakeAt, context: RestContext(idleDuration: 10 * 60))

        XCTAssertEqual(result, .noChange)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 60)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testSuspendPauseTicksKeepIdleStretchForResumeResolution() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let shortIdleAt = start.addingTimeInterval(9 * 60)
        _ = engine.evaluate(now: shortIdleAt, context: RestContext(idleDuration: 9 * 60))
        _ = engine.pause(
            for: nil,
            now: shortIdleAt,
            reason: .suspendOrLock,
            context: RestContext(idleDuration: 9 * 60)
        )

        let pausedTick = engine.evaluate(
            now: start.addingTimeInterval(9 * 60 + 1),
            context: RestContext(idleDuration: 9 * 60 + 1)
        )
        guard case .paused = pausedTick else {
            return XCTFail("Expected suspend/lock pause to stay active")
        }
        XCTAssertEqual(engine.state.pendingEyeDebt, 9 * 60)
        XCTAssertEqual(engine.state.pendingBodyDebt, 9 * 60)

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        XCTAssertEqual(engine.resume(now: awayAt), .resumed)
        _ = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testNaturalIdleCreditsAwayRecoveryOutsideWorkingHoursWithoutPrompting() {
        var settings = RestSettings.defaults
        settings.workingHours = WorkingHoursSettings(
            isEnabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 17 * 60
        )
        var engine = RestEngine(settings: settings, now: start)
        let dueAt = engine.state.scheduled!.dueAt
        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))

        let result = engine.evaluate(
            now: dueAt,
            context: RestContext(
                idleDuration: settings.naturalBreaks.inactivityResetTime,
                inWorkingHours: false
            )
        )

        XCTAssertEqual(result, .naturalRestsCredited([.eyeGate, .bodyBreak]))
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testTakeNowDuringNaturalAwayCreditsRestInsteadOfStartingOverlay() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        _ = engine.evaluate(now: start.addingTimeInterval(10 * 60), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.eyeDebt, 10 * 60)
        XCTAssertEqual(engine.state.bodyDebt, 10 * 60)

        let result = engine.takeNow(
            .eyeGate,
            now: start.addingTimeInterval(21 * 60),
            context: RestContext(idleDuration: 11 * 60)
        )

        guard case .naturalRestsCredited(let credited) = result else {
            return XCTFail("Expected away automation to credit natural rests instead of starting Eye Gate")
        }
        XCTAssertEqual(credited, [.eyeGate, .bodyBreak])
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
    }

    func testTakeNowDuringIdleKeepsStretchForAwayResolution() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let automationAt = start.addingTimeInterval(9 * 60)
        let started = engine.takeNow(.eyeGate, now: automationAt, context: RestContext(idleDuration: 9 * 60))
        guard case .started(let session) = started else {
            return XCTFail("Expected automation-started Eye Gate")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.pendingBodyDebt, 9 * 60)

        _ = engine.completeActive(
            now: automationAt.addingTimeInterval(settings.eyeGate.duration),
            reason: .completed,
            context: RestContext(idleDuration: 9 * 60 + settings.eyeGate.duration)
        )
        XCTAssertEqual(engine.state.pendingBodyDebt, 9 * 60)

        _ = engine.evaluate(
            now: start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    // MARK: - Active rests

    func testActiveManualRestCrossingAwayThresholdDropsStretchWithoutNaturalBreaks() {
        var settings = RestSettings.defaults
        settings.eyeGate.manualFinishEnabled = true
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let started = engine.takeNow(
            .eyeGate,
            now: start.addingTimeInterval(9 * 60),
            context: RestContext(idleDuration: 9 * 60)
        )
        guard case .started = started else {
            return XCTFail("Expected Eye Gate to start during the unattended stretch")
        }
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 9 * 60)

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let activeAfterAway = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )
        guard case .started = activeAfterAway else {
            return XCTFail("Expected manual active rest to remain active when natural breaks are disabled")
        }
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)

        _ = engine.completeActive(now: awayAt.addingTimeInterval(1), reason: .manual)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    func testActivePresentAppLifecycleTickDropsAwayStretchWithoutDeferral() {
        var settings = RestSettings.defaults
        settings.eyeGate.manualFinishEnabled = true
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        _ = engine.takeNow(
            .eyeGate,
            now: start.addingTimeInterval(9 * 60),
            context: RestContext(idleDuration: 9 * 60)
        )
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 9 * 60)

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let presentTickResult = engine.deferActiveForAppExclusion(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(presentTickResult, .noChange)
        XCTAssertEqual(engine.state.activeSession?.kind, .eyeGate)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
    }

    func testElapsedCompletionCrossingAwayThresholdDropsStretch() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let automationAt = start.addingTimeInterval(9 * 60 + 50)
        _ = engine.takeNow(.eyeGate, now: automationAt, context: RestContext(idleDuration: 9 * 60 + 50))
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 9 * 60 + 50)

        let completedAt = automationAt.addingTimeInterval(settings.eyeGate.duration)
        let completed = engine.completeActive(
            now: completedAt,
            reason: .completed,
            context: RestContext(idleDuration: 10 * 60 + 10)
        )

        guard case .completed(let session, let reason) = completed else {
            return XCTFail("Expected automatic Eye Gate completion")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .completed)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)

        _ = engine.evaluate(now: completedAt.addingTimeInterval(1), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.bodyDebt, 1)
    }

    func testEngagementDuringActiveRestTurnsEarlierIdleIntoScreenTime() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 2 * 60
        settings.bodyBreak.interval = 5 * 60
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        guard case .started(let eye) = engine.evaluate(
            now: start.addingTimeInterval(2 * 60),
            context: RestContext(idleDuration: 60)
        ) else {
            return XCTFail("Expected Eye Gate to start during the idle stretch")
        }
        XCTAssertEqual(eye.kind, .eyeGate)
        XCTAssertEqual(engine.state.bodyDebt, 60)
        XCTAssertEqual(engine.state.pendingBodyDebt, 60)

        _ = engine.evaluate(now: start.addingTimeInterval(2 * 60 + 10), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.bodyDebt, 2 * 60)
        XCTAssertEqual(engine.state.pendingBodyDebt, 0)

        let completedAt = start.addingTimeInterval(2 * 60 + 20)
        _ = engine.completeActive(now: completedAt, context: RestContext(idleDuration: 10))
        _ = engine.evaluate(
            now: completedAt.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime + 10)
        )

        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 2 * 60)
    }

    func testNaturalIdleCompletesActiveRestOnlyAfterAwayThreshold() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.eyeGate, now: start)

        let shortIdleResult = engine.evaluate(
            now: start.addingTimeInterval(30),
            context: RestContext(idleDuration: engine.settings.eyeGate.duration)
        )
        guard case .started(let active) = shortIdleResult else {
            return XCTFail("Expected short idle to keep active rest running")
        }
        XCTAssertEqual(active.kind, .eyeGate)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)

        let awayThreshold = engine.settings.naturalBreaks.inactivityResetTime
        let result = engine.evaluate(
            now: start.addingTimeInterval(awayThreshold),
            context: RestContext(idleDuration: awayThreshold)
        )
        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected active rest to complete naturally")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(reason, .natural)
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)

        let repeatedIdleResult = engine.evaluate(
            now: start.addingTimeInterval(awayThreshold + 1),
            context: RestContext(idleDuration: awayThreshold + 1)
        )

        XCTAssertEqual(repeatedIdleResult, .noChange)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
    }

    func testNaturalIdleCompletesActiveRestOnlyAfterRestDurationWhenDurationExceedsAwayThreshold() {
        var settings = RestSettings.defaults
        settings.bodyBreak.duration = 20 * 60
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let thresholdResult = engine.evaluate(
            now: start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )
        guard case .started(let active) = thresholdResult else {
            return XCTFail("Expected Body Break to keep running until its configured duration is naturally satisfied")
        }
        XCTAssertEqual(active.kind, .bodyBreak)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)

        let durationResult = engine.evaluate(
            now: start.addingTimeInterval(settings.bodyBreak.duration),
            context: RestContext(idleDuration: settings.bodyBreak.duration)
        )
        guard case .completed(let session, let reason) = durationResult else {
            return XCTFail("Expected Body Break to complete naturally after the longer duration threshold")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(reason, .natural)
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
    }

    func testActiveNaturalCompletionUsesFrozenSessionDurationAfterSettingsChange() {
        var settings = RestSettings.defaults
        settings.bodyBreak.duration = 3 * 60
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        var updated = engine.settings
        updated.bodyBreak.duration = 20 * 60
        engine.updateSettings(updated, now: start.addingTimeInterval(1))

        let result = engine.evaluate(
            now: start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected active Body Break to use its frozen session duration")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.duration, 3 * 60)
        XCTAssertEqual(reason, .natural)
        XCTAssertNil(engine.state.activeSession)
    }

    func testNaturalBodyCompletionAlsoSettlesExistingEyeDebt() {
        var settings = RestSettings.defaults
        settings.bodyBreak.duration = 3 * 60
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.eyeDebt, 60)

        _ = engine.takeNow(.bodyBreak, now: start.addingTimeInterval(60))
        let result = engine.evaluate(
            now: start.addingTimeInterval(60 + settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        guard case .completed(let session, let reason) = result else {
            return XCTFail("Expected active Body Break to complete naturally")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(reason, .natural)
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
    }

    func testRestStartedDuringIdleCompletesNaturallyWhenTheStretchBecomesAway() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 2 * 60
        settings.bodyBreak.interval = 5 * 60
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        let startedDuringIdle = engine.evaluate(
            now: start.addingTimeInterval(2 * 60),
            context: RestContext(idleDuration: 60)
        )
        guard case .started(let session) = startedDuringIdle else {
            return XCTFail("Expected Eye Gate to start during the idle stretch")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), settings.eyeGate.interval)
        XCTAssertEqual(engine.state.pendingBodyDebt, 60)

        let completedAfterAway = engine.evaluate(
            now: start.addingTimeInterval(60 + settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )
        guard case .completed(let completed, let reason) = completedAfterAway else {
            return XCTFail("Expected active Eye Gate to complete naturally after the idle stretch becomes away")
        }
        XCTAssertEqual(completed.kind, .eyeGate)
        XCTAssertEqual(reason, .natural)
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(
            engine.state.scheduled?.dueAt,
            start.addingTimeInterval(60 + settings.naturalBreaks.inactivityResetTime + settings.eyeGate.interval)
        )
    }

    func testElapsedCompletionDuringShortIdleKeepsRemainingStretchForAwayResolution() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 2 * 60
        settings.bodyBreak.interval = 5 * 60
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        _ = engine.evaluate(now: start.addingTimeInterval(60), context: RestContext(idleDuration: 0))
        guard case .started = engine.evaluate(
            now: start.addingTimeInterval(2 * 60),
            context: RestContext(idleDuration: 60)
        ) else {
            return XCTFail("Expected Eye Gate to start during the idle stretch")
        }

        guard case .started = engine.evaluate(
            now: start.addingTimeInterval(2 * 60 + 10),
            context: RestContext(idleDuration: 70)
        ) else {
            return XCTFail("Expected Eye Gate to keep running")
        }

        let elapsedCompletion = engine.completeActive(
            now: start.addingTimeInterval(2 * 60 + settings.eyeGate.duration),
            reason: .completed,
            context: RestContext(idleDuration: 60 + settings.eyeGate.duration)
        )
        guard case .completed(let completed, .completed) = elapsedCompletion else {
            return XCTFail("Expected elapsed Eye Gate completion")
        }
        XCTAssertEqual(completed.kind, .eyeGate)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.bodyDebt, 60)

        let longIdleResult = engine.evaluate(
            now: start.addingTimeInterval(60 + settings.naturalBreaks.inactivityResetTime),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        XCTAssertEqual(longIdleResult, .noChange)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 60)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
    }

    func testActiveRestIdleDoesNotCountOverlayTimeAsExposure() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        guard case .started = engine.evaluate(
            now: start.addingTimeInterval(700),
            context: RestContext(idleDuration: 500)
        ) else {
            return XCTFail("Expected active Body Break to keep running before natural-away completion")
        }
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)

        let naturalCompletion = engine.evaluate(
            now: start.addingTimeInterval(800),
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime)
        )

        guard case .completed(let completed, let reason) = naturalCompletion else {
            return XCTFail("Expected active Body Break to complete naturally")
        }
        XCTAssertEqual(completed.kind, .bodyBreak)
        XCTAssertEqual(reason, .natural)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
    }

    func testActiveNaturalCompletionCreditsExposureFromBeforeAnInterveningReturn() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 30 * 60
        settings.bodyBreak.interval = 60
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)

        let startedDuringFirstIdle = engine.evaluate(
            now: start.addingTimeInterval(60),
            context: RestContext(idleDuration: 60)
        )
        guard case .started(let session) = startedDuringFirstIdle else {
            return XCTFail("Expected Body Break to start during the first idle stretch")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(engine.state.pendingEyeDebt, 60)

        let completedDuringSecondIdle = engine.evaluate(
            now: start.addingTimeInterval(11 * 60 + 40),
            context: RestContext(idleDuration: 10 * 60)
        )

        guard case .completed(let completed, let reason) = completedDuringSecondIdle else {
            return XCTFail("Expected active Body Break to complete naturally during the second idle stretch")
        }
        XCTAssertEqual(completed.kind, .bodyBreak)
        XCTAssertEqual(reason, .natural)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
    }

    // MARK: - Context deferral

    func testNaturalIdleDoesNotBypassFocusModeDeferral() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        advanceUntilBodyBreakIsNext(&engine)
        let bodyDue = engine.state.scheduled!.dueAt

        let result = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )

        XCTAssertEqual(result, .deferred(.bodyBreak, .focusMode))
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .focusMode)
    }

    func testNaturalIdleDoesNotBypassAppExclusionDeferral() {
        let rule = presentationRule()
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]
        var engine = RestEngine(settings: settings, now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let result = engine.evaluate(
            now: engine.state.scheduled!.dueAt,
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)]))
        )

        XCTAssertEqual(result, .deferred(.bodyBreak, .appExclusion("Presentation")))
        XCTAssertEqual(engine.state.statistics.completedBodyBreaks, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 0)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .appExclusion("Presentation"))
    }

    func testFocusModeDefersBodyBreakButNotEyeGateByDefault() {
        var bodyEngine = RestEngine(settings: withoutCues(bodyFirstSettings()), now: start)
        advanceUntilBodyBreakIsNext(&bodyEngine)

        let bodyDue = bodyEngine.state.scheduled!.dueAt
        let bodyResult = bodyEngine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )
        XCTAssertEqual(bodyResult, .deferred(.bodyBreak, .focusMode))

        var eyeEngine = RestEngine(settings: withoutCues(.defaults), now: start)
        let eyeDue = eyeEngine.state.scheduled!.dueAt
        let eyeResult = eyeEngine.evaluate(
            now: eyeDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )
        guard case .started(let session) = eyeResult else {
            return XCTFail("Expected Eye Gate to ignore focus-mode deferral")
        }
        XCTAssertEqual(session.kind, .eyeGate)
    }

    func testCallDefersBodyBreakButNotEyeGate() {
        var bodyEngine = RestEngine(settings: withoutCues(bodyFirstSettings()), now: start)
        let bodyDue = start.addingTimeInterval(10 * 60)
        XCTAssertEqual(
            bodyEngine.evaluate(now: bodyDue, context: atNaturalPause(RestContext(inCall: true))),
            .deferred(.bodyBreak, .inCall)
        )

        var eyeEngine = RestEngine(settings: withoutCues(.defaults), now: start)
        let eyeResult = eyeEngine.evaluate(
            now: start.addingTimeInterval(20 * 60),
            context: atNaturalPause(RestContext(inCall: true))
        )
        guard case .started(let session) = eyeResult else {
            return XCTFail("Expected Eye Gate during a call")
        }
        XCTAssertEqual(session.kind, .eyeGate)
    }

    func testCallStopsDeferringBodyBreakAfterOneMoreInterval() {
        var engine = RestEngine(settings: withoutCues(bodyFirstSettings()), now: start)
        let bodyDue = start.addingTimeInterval(10 * 60)
        let call = atNaturalPause(RestContext(inCall: true))
        XCTAssertEqual(engine.evaluate(now: bodyDue, context: call), .deferred(.bodyBreak, .inCall))

        XCTAssertEqual(
            engine.evaluate(now: bodyDue.addingTimeInterval(10 * 60 - 1), context: call),
            .deferred(.bodyBreak, .inCall)
        )

        guard case .started(let session) = engine.evaluate(now: bodyDue.addingTimeInterval(10 * 60), context: call) else {
            return XCTFail("Expected an endless call signal to stop holding the Body Break")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.scheduledAt, bodyDue)
    }

    func testBodyOnlyDeferralDoesNotStarveDueEyeGate() {
        var settings = bodyFirstSettings()
        settings.eyeGate.interval = 20 * 60
        var engine = RestEngine(settings: withoutCues(settings), now: start)
        let focus = atNaturalPause(RestContext(focusModeActive: true))

        let bodyResult = engine.evaluate(now: start.addingTimeInterval(settings.bodyBreak.interval), context: focus)
        XCTAssertEqual(bodyResult, .deferred(.bodyBreak, .focusMode))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)

        let eyeResult = engine.evaluate(now: start.addingTimeInterval(settings.eyeGate.interval), context: focus)

        guard case .started(let session) = eyeResult else {
            return XCTFail("Expected Eye Gate to start even while Body Break remains deferred")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)
    }

    func testBodyBreakCompletionClearsDeferredEyeGateSatisfiedByBodyBreak() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 10 * 60
        settings.bodyBreak.interval = 20 * 60
        settings.focusMode.deferEyeGate = true
        settings.focusMode.deferBodyBreak = false
        var engine = RestEngine(settings: withoutCues(settings), now: start)
        let focus = atNaturalPause(RestContext(focusModeActive: true))

        let eyeDue = start.addingTimeInterval(settings.eyeGate.interval)
        XCTAssertEqual(engine.evaluate(now: eyeDue, context: focus), .deferred(.eyeGate, .focusMode))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)

        let bodyDue = start.addingTimeInterval(settings.bodyBreak.interval)
        guard case .started(let bodySession) = engine.evaluate(now: bodyDue, context: focus) else {
            return XCTFail("Expected Body Break to start through an Eye-only deferral")
        }
        XCTAssertEqual(bodySession.kind, .bodyBreak)
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)

        _ = engine.completeActive(
            now: bodyDue.addingTimeInterval(settings.bodyBreak.duration),
            reason: .completed
        )
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertNil(engine.state.activeDeferral)

        let afterFocusClears = engine.evaluate(
            now: bodyDue.addingTimeInterval(settings.bodyBreak.duration + 1),
            context: atNaturalPause()
        )
        if case .started(let session) = afterFocusClears, session.kind == .eyeGate {
            XCTFail("Body Break already satisfied the deferred Eye Gate debt")
        }
    }

    func testActiveBodyNaturalEyeCreditClearsDeferredEyeGate() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 10 * 60
        settings.bodyBreak.duration = 20 * 60
        settings.focusMode.deferEyeGate = true
        settings.focusMode.deferBodyBreak = false
        var engine = RestEngine(settings: settings, now: start)

        let eyeDue = start.addingTimeInterval(settings.eyeGate.interval)
        _ = engine.evaluate(now: eyeDue, context: atNaturalPause(RestContext(focusModeActive: true)))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)

        let bodyStartedAt = eyeDue.addingTimeInterval(1)
        _ = engine.takeNow(.bodyBreak, now: bodyStartedAt)
        XCTAssertEqual(engine.state.activeSession?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)

        let awayAt = bodyStartedAt.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let activeResult = engine.evaluate(
            now: awayAt,
            context: RestContext(
                idleDuration: settings.naturalBreaks.inactivityResetTime,
                focusModeActive: true
            )
        )
        guard case .started(let active) = activeResult else {
            return XCTFail("Expected long Body Break to remain active until its own duration is satisfied")
        }
        XCTAssertEqual(active.kind, .bodyBreak)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testDeferredRestReturnsToFutureWhenAwayStretchIsDropped() {
        var settings = bodyFirstSettings()
        settings.naturalBreaks.isEnabled = false
        settings.naturalBreaks.inactivityResetTime = 10 * 60
        var engine = RestEngine(settings: settings, now: start)

        let idleStartedAt = start.addingTimeInterval(settings.bodyBreak.interval - 60)
        _ = engine.evaluate(now: idleStartedAt, context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.bodyDebt, settings.bodyBreak.interval - 60)

        let deferredAt = idleStartedAt.addingTimeInterval(60)
        let deferred = engine.evaluate(
            now: deferredAt,
            context: RestContext(idleDuration: 60, focusModeActive: true)
        )
        XCTAssertEqual(deferred, .deferred(.bodyBreak, .focusMode))
        XCTAssertEqual(engine.state.scheduled?.dueAt, deferredAt)
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)

        let awayAt = idleStartedAt.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let awayResult = engine.evaluate(
            now: awayAt,
            context: RestContext(idleDuration: settings.naturalBreaks.inactivityResetTime, focusModeActive: true)
        )
        XCTAssertEqual(awayResult, .noChange)
        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), settings.bodyBreak.interval - 60)
        XCTAssertEqual(engine.state.scheduled?.dueAt, awayAt.addingTimeInterval(60))

        let returnAt = awayAt.addingTimeInterval(1)
        let returnResult = engine.evaluate(
            now: returnAt,
            context: RestContext(idleDuration: 0, focusModeActive: false)
        )
        if case .started = returnResult {
            XCTFail("Dropping the away stretch should move the deferred Body Break back into the future")
        }
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.scheduled?.dueAt, returnAt.addingTimeInterval(59))
    }

    func testNaturalCreditAlsoClearsDeferredRestMovedIntoFuture() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.interval = 20 * 60
        settings.focusMode.deferEyeGate = true
        var engine = RestEngine(settings: settings, now: start)

        let idleStartedAt = start.addingTimeInterval(5 * 60)
        _ = engine.evaluate(now: idleStartedAt, context: RestContext(idleDuration: 0))
        XCTAssertEqual(engine.state.eyeDebt, 0)
        XCTAssertEqual(engine.state.bodyDebt, 5 * 60)

        var updated = engine.settings
        updated.eyeGate.isEnabled = true
        updated.eyeGate.interval = 60
        engine.updateSettings(updated, now: idleStartedAt)

        let shortIdleAt = idleStartedAt.addingTimeInterval(60)
        let shortIdleDeferral = engine.evaluate(
            now: shortIdleAt,
            context: RestContext(idleDuration: 60, focusModeActive: true)
        )
        XCTAssertEqual(shortIdleDeferral, .deferred(.eyeGate, .focusMode))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 60)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 6 * 60)

        let awayAt = idleStartedAt.addingTimeInterval(updated.naturalBreaks.inactivityResetTime)
        let awayResult = engine.evaluate(
            now: awayAt,
            context: RestContext(
                idleDuration: updated.naturalBreaks.inactivityResetTime,
                focusModeActive: true
            )
        )

        XCTAssertEqual(awayResult, .naturalRestsCredited([.eyeGate, .bodyBreak]))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(engine.state.scheduled?.dueAt, awayAt.addingTimeInterval(60))
    }

    func testNaturalBodyBreakSatisfiesDeferredEyeGateEvenWhenEyeNaturalThresholdIsLonger() {
        var settings = RestSettings.defaults
        settings.naturalBreaks.inactivityResetTime = 60
        settings.eyeGate.interval = 60
        settings.eyeGate.duration = 10 * 60
        settings.bodyBreak.duration = 3 * 60
        settings.focusMode.deferEyeGate = true
        settings.focusMode.deferBodyBreak = false
        var engine = RestEngine(settings: settings, now: start)

        let eyeDue = start.addingTimeInterval(settings.eyeGate.interval)
        let eyeDeferred = engine.evaluate(
            now: eyeDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )
        XCTAssertEqual(eyeDeferred, .deferred(.eyeGate, .focusMode))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .eyeGate)

        let bodyNaturallySatisfiedAt = eyeDue.addingTimeInterval(settings.bodyBreak.duration)
        let awayResult = engine.evaluate(
            now: bodyNaturallySatisfiedAt,
            context: RestContext(
                idleDuration: settings.bodyBreak.duration,
                focusModeActive: true
            )
        )

        XCTAssertEqual(awayResult, .naturalRestsCredited([.eyeGate, .bodyBreak]))
        XCTAssertEqual(engine.state.debt(for: .eyeGate), 0)
        XCTAssertEqual(engine.state.debt(for: .bodyBreak), 0)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 0)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
        XCTAssertNil(engine.state.activeDeferral)

        let focusCleared = engine.evaluate(
            now: bodyNaturallySatisfiedAt.addingTimeInterval(1),
            context: RestContext(focusModeActive: false)
        )
        if case .started(let session) = focusCleared, session.kind == .eyeGate {
            XCTFail("Natural Body Break already satisfied the deferred Eye Gate")
        }
    }

    func testContinuousContextDeferralEscalatesOnceAndStartsAtFirstPauseWhenCleared() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        let firstDeferral = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
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

        let typingWhenCleared = engine.evaluate(
            now: bodyDue.addingTimeInterval(11),
            context: RestContext(idleDuration: 0.5, focusModeActive: false)
        )
        XCTAssertEqual(typingWhenCleared, .notificationDue(.bodyBreak))
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)

        let resumed = engine.evaluate(
            now: bodyDue.addingTimeInterval(41),
            context: atNaturalPause()
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected deferred Body Break to start at the first pause after Focus clears")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.scheduledAt, bodyDue)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testClearedDeferralStartsAfterOneSlackDuringContinuousInput() {
        var engine = RestEngine(settings: withoutCues(bodyFirstSettings()), now: start)
        let bodyDue = start.addingTimeInterval(10 * 60)
        let focus = atNaturalPause(RestContext(focusModeActive: true))
        XCTAssertEqual(engine.evaluate(now: bodyDue, context: focus), .deferred(.bodyBreak, .focusMode))

        let slack = RestTiming.slack(forInterval: 10 * 60)
        var now = bodyDue.addingTimeInterval(1)
        while now < bodyDue.addingTimeInterval(slack) {
            if case .started = engine.evaluate(now: now, context: RestContext(idleDuration: 0.5)) {
                return XCTFail("Expected cleared deferral to wait for a pause")
            }
            now = now.addingTimeInterval(1)
        }

        guard case .started(let session) = engine.evaluate(
            now: bodyDue.addingTimeInterval(slack),
            context: RestContext(idleDuration: 0.5)
        ) else {
            return XCTFail("Expected cleared deferral to start after one slack interval")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
    }

    func testSettingsUpdatePreservesDeferredRestUntilContextClears() {
        var engine = RestEngine(settings: withoutCues(bodyFirstSettings()), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        _ = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )

        var updated = engine.settings
        updated.presentation.showCurrentTimeDuringBodyBreak = true
        let savedAt = bodyDue.addingTimeInterval(5)
        engine.updateSettings(updated, now: savedAt)

        XCTAssertEqual(engine.state.scheduled?.kind, .bodyBreak)
        XCTAssertEqual(engine.state.scheduled?.dueAt, bodyDue)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .focusMode)

        let resumed = engine.evaluate(
            now: savedAt.addingTimeInterval(1),
            context: atNaturalPause(RestContext(focusModeActive: false))
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected settings save during deferral to keep the rest due")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(session.scheduledAt, bodyDue)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testSettingsUpdateClearsDeferredRestMovedIntoFutureByRhythmChange() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        _ = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )
        XCTAssertEqual(engine.state.activeDeferral?.kind, .bodyBreak)

        let savedAt = bodyDue.addingTimeInterval(5)
        engine.updateSettings(.defaults, now: savedAt)

        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertGreaterThan(engine.state.scheduled?.dueAt ?? savedAt, savedAt)

        let resumed = engine.evaluate(
            now: savedAt.addingTimeInterval(1),
            context: RestContext(focusModeActive: false)
        )
        if case .started(let session) = resumed {
            XCTFail("Expected rhythm change to move deferred rest into the future, got \(session.kind)")
        }
        XCTAssertNil(engine.state.activeSession)
    }

    func testSettingsUpdateDropsDeferredRestWhenThatRestIsDisabled() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        _ = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(focusModeActive: true))
        )

        var updated = RestSettings.defaults
        updated.bodyBreak.isEnabled = false
        let savedAt = bodyDue.addingTimeInterval(5)
        engine.updateSettings(updated, now: savedAt)

        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(
            engine.state.scheduled?.dueAt,
            bodyDue.addingTimeInterval(updated.eyeGate.interval - engine.state.debt(for: .eyeGate))
        )
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testSettingsUpdateClearsDisabledBodyDebtAndSuppression() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)
        _ = engine.postponeActive(now: start.addingTimeInterval(1))
        XCTAssertEqual(engine.state.bodyDebt, engine.settings.bodyBreak.interval)
        XCTAssertNotNil(engine.state.bodySuppressedUntil)

        var updated = engine.settings
        updated.bodyBreak.isEnabled = false
        let savedAt = start.addingTimeInterval(2)
        engine.updateSettings(updated, now: savedAt)

        XCTAssertFalse(engine.settings.bodyBreak.isEnabled)
        XCTAssertEqual(engine.state.bodyDebt, 0)
        XCTAssertNil(engine.state.bodySuppressedUntil)
        XCTAssertNotEqual(engine.state.scheduled?.kind, .bodyBreak)
    }

    func testDisablingBreakHealthModeResetsDangerScore() {
        var engine = RestEngine(settings: bodyFirstSettings(), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        _ = engine.evaluate(now: bodyDue, context: atNaturalPause(RestContext(focusModeActive: true)))
        XCTAssertGreaterThan(engine.state.dangerScore, 0)

        var settings = RestSettings.defaults
        settings.presentation.breakHealthMode = false
        engine.updateSettings(settings, now: bodyDue)

        XCTAssertEqual(engine.state.dangerScore, 0)
    }

    func testAppExclusionPauseCanTargetSpecificBreakKind() {
        let rule = presentationRule()
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: settings, now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let result = engine.evaluate(
            now: engine.state.scheduled!.dueAt,
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)]))
        )

        XCTAssertEqual(result, .deferred(.bodyBreak, .appExclusion("Presentation")))
    }

    func testPauseAppExclusionInterruptsActiveBodyBreakUntilCleared() {
        let rule = presentationRule()
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: withoutCues(settings), now: start)
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
        XCTAssertEqual(engine.state.lastEvaluatedAt, interruptedAt)

        let dangerAfterInterruption = engine.state.dangerScore
        let stillDeferred = engine.evaluate(
            now: interruptedAt.addingTimeInterval(10),
            context: RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])
        )
        XCTAssertEqual(stillDeferred, .deferred(.bodyBreak, .appExclusion("Presentation")))
        XCTAssertEqual(engine.state.eyeDebt, 10, accuracy: 0.001)
        XCTAssertEqual(engine.state.bodyDebt, settings.bodyBreak.interval + 10, accuracy: 0.001)
        XCTAssertEqual(engine.state.dangerScore, dangerAfterInterruption)

        let resumed = engine.evaluate(
            now: interruptedAt.addingTimeInterval(20),
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: false)]))
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected Body Break to restart once pause app exclusion clears")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testNaturalAwayCompletionWinsOverActiveBodyBreakAppExclusionDeferral() {
        let rule = presentationRule()
        var settings = RestSettings.defaults
        settings.appExclusions = [rule]
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let awayAt = start.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        let context = RestContext(
            idleDuration: settings.naturalBreaks.inactivityResetTime,
            appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)]
        )

        XCTAssertEqual(engine.deferActiveForAppExclusion(now: awayAt, context: context), .noChange)
        let completed = engine.evaluate(now: awayAt, context: context)

        guard case .completed(let session, let reason) = completed else {
            return XCTFail("Expected active Body Break to complete naturally before app exclusion deferral")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertEqual(reason, .natural)
        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.statistics.naturalBodyBreaks, 1)
    }

    func testElapsedAutomaticBodyBreakCompletionWinsOverAppExclusionDeferral() {
        let rule = presentationRule()
        var settings = RestSettings.defaults
        settings.appExclusions = [rule]
        XCTAssertFalse(settings.bodyBreak.manualFinishEnabled)
        var engine = RestEngine(settings: settings, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)

        let elapsedAt = start.addingTimeInterval(settings.bodyBreak.duration)
        let context = RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)])

        XCTAssertEqual(engine.deferActiveForAppExclusion(now: elapsedAt, context: context), .noChange)
        XCTAssertNil(engine.state.activeDeferral)
        XCTAssertEqual(engine.state.activeSession?.kind, .bodyBreak)
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
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: withoutCues(settings), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        let waiting = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: false)]))
        )
        XCTAssertEqual(waiting, .deferred(.bodyBreak, .appExclusion("Deep Work")))
        XCTAssertEqual(engine.state.activeDeferral?.reason, .appExclusion("Deep Work"))

        let resumed = engine.evaluate(
            now: bodyDue.addingTimeInterval(1),
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)]))
        )

        guard case .started(let session) = resumed else {
            return XCTFail("Expected resume-only rule to start Body Break once matched")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testEmptyResumeOnlyAppExclusionDoesNotDeferForever() {
        let rule = AppExclusionRule(
            id: "empty-rule",
            name: "Empty rule",
            matchTerms: ["", "  "],
            mode: .resumeOnlyWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: withoutCues(settings), now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let bodyDue = engine.state.scheduled!.dueAt
        let result = engine.evaluate(
            now: bodyDue,
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: false)]))
        )

        guard case .started(let session) = result else {
            return XCTFail("Expected empty resume-only app rule to be ignored instead of deferring forever")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
        XCTAssertNil(engine.state.activeDeferral)
    }

    func testBlankAppExclusionNameFallsBackToReadableTermInDeferralReason() {
        let rule = AppExclusionRule(
            id: "blank-name-rule",
            name: "  ",
            matchTerms: ["  Keynote  "],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        var settings = bodyFirstSettings()
        settings.appExclusions = [rule]

        var engine = RestEngine(settings: settings, now: start)
        advanceUntilBodyBreakIsNext(&engine)

        let result = engine.evaluate(
            now: engine.state.scheduled!.dueAt,
            context: atNaturalPause(RestContext(appExclusions: [AppExclusionEvaluation(rule: rule, isMatched: true)]))
        )

        XCTAssertEqual(result, .deferred(.bodyBreak, .appExclusion("Keynote")))
        XCTAssertEqual(engine.state.activeDeferral?.reason, .appExclusion("Keynote"))
    }

    // MARK: - Restoring

    func testRestoringPersistedSuspendPauseResumesScheduling() {
        var engine = RestEngine(settings: .defaults, now: start)
        let sleptAt = start.addingTimeInterval(5 * 60)
        _ = engine.evaluate(now: sleptAt, context: RestContext(idleDuration: 0))
        _ = engine.pause(for: nil, now: sleptAt, reason: .suspendOrLock)
        XCTAssertEqual(engine.state.pause?.reason, .suspendOrLock)

        let relaunchedAt = sleptAt.addingTimeInterval(5 * 60 * 60)
        let restored = RestEngine(settings: .defaults, restoring: engine.state, now: relaunchedAt)

        XCTAssertNil(restored.state.pause)
        XCTAssertEqual(restored.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(restored.state.scheduled?.dueAt, relaunchedAt.addingTimeInterval(20 * 60))
        XCTAssertEqual(restored.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(restored.state.statistics.naturalBodyBreaks, 1)
    }

    func testRestoringAfterShortRelaunchCountsGapAsScreenTime() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(300), context: RestContext(idleDuration: 0))

        let relaunchedAt = start.addingTimeInterval(330)
        var restored = RestEngine(settings: .defaults, restoring: engine.state, now: relaunchedAt)
        _ = restored.evaluate(now: relaunchedAt, context: RestContext(idleDuration: 1))

        XCTAssertEqual(restored.state.debt(for: .eyeGate), 330)
        XCTAssertEqual(restored.state.statistics.naturalEyeGates, 0)
    }

    func testRestoringLegacyStateKeepsStatisticsAndDebt() throws {
        let legacy = Data(#"""
        {
          "awayCandidate" : { "bodyDebt" : 900, "eyeDebt" : 60, "startedAt" : 1000 },
          "bodyDebt" : 960,
          "dangerScore" : 2,
          "eyeDebt" : 120,
          "lastEvaluatedAt" : 1060,
          "lastIdleDuration" : 30,
          "postponesInCurrentCycle" : 0,
          "scheduled" : {
            "dueAt" : 2140,
            "kind" : "eyeGate",
            "notificationAt" : 2130,
            "notificationSent" : false
          },
          "statistics" : {
            "completedBodyBreaks" : 12,
            "completedEyeGates" : 40,
            "emergencyOverrides" : 1,
            "naturalBodyBreaks" : 5,
            "naturalEyeGates" : 7,
            "postpones" : 3,
            "skippedBodyBreaks" : 2,
            "skippedEyeGates" : 1
          }
        }
        """#.utf8)

        let state = try JSONDecoder().decode(RestEngineState.self, from: legacy)

        XCTAssertEqual(state.eyeDebt, 120)
        XCTAssertEqual(state.bodyDebt, 960)
        XCTAssertEqual(state.pendingEyeDebt, 0)
        XCTAssertEqual(state.dangerScore, 2)
        XCTAssertEqual(state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(state.statistics.completedEyeGates, 40)
        XCTAssertEqual(state.statistics.naturalBodyBreaks, 5)
    }

    // MARK: - Settings and content

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

    func testPresentationSettingsHonorsHiddenMenuBarVisibility() throws {
        let hiddenJSON = #"""
        {
          "themeSource": "system",
          "trayIconStyle": "default",
          "showCurrentTimeDuringBodyBreak": false,
          "breakHealthMode": true,
          "showMenuBarItem": false
        }
        """#.data(using: .utf8)!

        let presentation = try JSONDecoder().decode(PresentationSettings.self, from: hiddenJSON)

        XCTAssertEqual(presentation.showMenuBarItem, false)
        XCTAssertFalse(presentation.resolvedShowMenuBarItem)
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

    func testSettingsStoreNormalizesUnsafeDecodedSettingsAndPersistsMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try unsafeSettingsData().write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.interval, 1)
        XCTAssertEqual(loaded.eyeGate.duration, 1)
        XCTAssertEqual(loaded.eyeGate.enforcement, .eyeGateDefault)
        XCTAssertEqual(loaded.notifications.eyeGateLeadTime, 0)
        XCTAssertEqual(loaded.notifications.bodyBreakLeadTime, 0)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 1)
        XCTAssertEqual(loaded.workingHours.startMinuteOfDay, 0)
        XCTAssertEqual(loaded.workingHours.endMinuteOfDay, 1_439)
        XCTAssertEqual(loaded.bodyBreak.colorHex, RestRule.bodyBreakDefault.colorHex)
        XCTAssertEqual(loaded.bodyBreak.postpone.duration, 1)
        XCTAssertEqual(loaded.bodyBreak.postpone.maxCount, 0)
        XCTAssertEqual(loaded.bodyBreak.postpone.allowedDuringFirstPercent, 100)
        XCTAssertEqual(loaded.bodyBreak.enforcement.opacity, 1)
        XCTAssertEqual(loaded.bodyBreak.enforcement.configuredDisplayIndex, 0)
        XCTAssertEqual(loaded.bodyBreak.startSound, .named("crystal-glass", volume: 1))
        XCTAssertEqual(loaded.bodyBreak.finishSound, .named("crystal-glass", volume: 0))
        XCTAssertEqual(loaded.operations.resolvedPauseUntilMorningHour, 23)
        XCTAssertEqual(loaded.operations.pauseUntilMorningLatitude, 89.8)
        XCTAssertEqual(loaded.operations.pauseUntilMorningLongitude, -80)
        XCTAssertEqual(loaded.appExclusions.first?.matchTerms, ["Zoom"])

        let migrated = try JSONDecoder().decode(RestSettings.self, from: Data(contentsOf: url))
        XCTAssertEqual(migrated, loaded)
    }

    func testSettingsStoreLoadsLegacyMissingFieldsAndPersistsMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacySettingsDataWithMissingFields().write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertFalse(loaded.eyeGate.isEnabled)
        XCTAssertEqual(loaded.bodyBreak.colorHex, "#123456")
        XCTAssertEqual(loaded.notifications.silentNotifications, NotificationSettings.defaults.silentNotifications)
        XCTAssertEqual(
            loaded.notifications.eyeGateFullScreenCueEnabled,
            NotificationSettings.defaults.eyeGateFullScreenCueEnabled
        )
        XCTAssertEqual(
            loaded.notifications.bodyBreakFullScreenCueEnabled,
            NotificationSettings.defaults.bodyBreakFullScreenCueEnabled
        )
        XCTAssertEqual(loaded.shortcuts.reset, ShortcutSettings.defaults.reset)
        XCTAssertNil(loaded.shortcuts.endBodyBreak)
        XCTAssertNil(loaded.shortcuts.emergencyEyeGateOverride)
        XCTAssertEqual(loaded.shortcuts.resolvedEndBodyBreakShortcut, ShortcutSettings.defaultEndBodyBreakShortcut)
        XCTAssertEqual(loaded.contentLibrary.localImagePaths, [])
        XCTAssertEqual(loaded.contentLibrary.customBodyBreakIdeas.first?.isEnabled, true)
        XCTAssertEqual(loaded.appExclusions.first?.appliesTo, [.bodyBreak])
        XCTAssertEqual(loaded.admin.customPreferencesMessage, AdminSettings.defaults.customPreferencesMessage)

        let migratedData = try Data(contentsOf: url)
        let migratedRaw = try XCTUnwrap(JSONSerialization.jsonObject(with: migratedData) as? [String: Any])
        let migratedShortcuts = try XCTUnwrap(migratedRaw["shortcuts"] as? [String: Any])
        let migratedContentLibrary = try XCTUnwrap(migratedRaw["contentLibrary"] as? [String: Any])
        let migratedAdmin = try XCTUnwrap(migratedRaw["admin"] as? [String: Any])
        XCTAssertNotNil(migratedShortcuts["reset"])
        XCTAssertNotNil(migratedContentLibrary["localImagePaths"])
        XCTAssertNotNil(migratedAdmin["customPreferencesMessage"])
        XCTAssertEqual(try JSONDecoder().decode(RestSettings.self, from: migratedData), loaded)
    }

    func testSettingsStoreMigratesLegacyGateBasedRhythmDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.eyeGate.interval = 10 * 60
        legacy.bodyBreak.interval = 20 * 60
        legacy.bodyBreak.duration = 5 * 60
        legacy.bodyBreak.manualFinishEnabled = true
        legacy.naturalBreaks.inactivityResetTime = 5 * 60

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try settingsDataWithLegacyBodyBreakAfterEyeGates(legacy, count: 4).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.interval, 20 * 60)
        XCTAssertEqual(loaded.eyeGate.duration, 20)
        XCTAssertEqual(loaded.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(loaded.bodyBreak.duration, 3 * 60)
        XCTAssertFalse(loaded.bodyBreak.manualFinishEnabled)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 10 * 60)
        let migratedData = try Data(contentsOf: url)
        XCTAssertFalse(String(data: migratedData, encoding: .utf8)?.contains("bodyBreakAfterEyeGates") ?? true)
    }

    func testSettingsStoreMigratesDisabledLegacyBodyDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.bodyBreak.isEnabled = false
        legacy.bodyBreak.interval = 20 * 60
        legacy.bodyBreak.duration = 5 * 60
        legacy.bodyBreak.manualFinishEnabled = true

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertFalse(loaded.bodyBreak.isEnabled)
        XCTAssertEqual(loaded.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(loaded.bodyBreak.duration, 3 * 60)
        XCTAssertFalse(loaded.bodyBreak.manualFinishEnabled)
    }

    func testSettingsStoreMigratesLeakedIndependentBodyDefault() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var leaked = RestSettings.defaults
        leaked.bodyBreak.interval = 20 * 60

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(leaked).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.interval, 20 * 60)
        XCTAssertEqual(loaded.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(loaded.bodyBreak.duration, 3 * 60)
        XCTAssertFalse(loaded.bodyBreak.manualFinishEnabled)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 10 * 60)
    }

    func testSettingsStoreMigratesStandaloneOldAwayThresholdDefault() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.eyeGate.interval = 25 * 60
        legacy.bodyBreak.interval = 45 * 60
        legacy.naturalBreaks.inactivityResetTime = 5 * 60

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.interval, 25 * 60)
        XCTAssertEqual(loaded.bodyBreak.interval, 45 * 60)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 10 * 60)
    }

    func testSettingsStoreMigratesDisabledStandaloneOldAwayThresholdDefault() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.naturalBreaks.isEnabled = false
        legacy.naturalBreaks.inactivityResetTime = 5 * 60

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertFalse(loaded.naturalBreaks.isEnabled)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 10 * 60)
    }

    func testSettingsStoreMigratesLeakedIndependentBodyDefaultWithOldAwayThreshold() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var leaked = RestSettings.defaults
        leaked.bodyBreak.interval = 20 * 60
        leaked.naturalBreaks.inactivityResetTime = 5 * 60

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(leaked).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.interval, 20 * 60)
        XCTAssertEqual(loaded.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(loaded.bodyBreak.duration, 3 * 60)
        XCTAssertFalse(loaded.bodyBreak.manualFinishEnabled)
        XCTAssertEqual(loaded.naturalBreaks.inactivityResetTime, 10 * 60)
    }

    func testSettingsStoreReturnsLoadedSettingsWhenMigrationCannotBePersisted() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacySettingsDataWithMissingFields().write(to: url, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o555)], ofItemAtPath: directory.path)
        defer {
            try? fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o700)], ofItemAtPath: directory.path)
            try? fileManager.removeItem(at: directory)
        }
        guard !fileManager.isWritableFile(atPath: directory.path) else {
            throw XCTSkip("Temporary directory permissions still allow writes")
        }

        let loaded = try store.load()

        XCTAssertFalse(loaded.eyeGate.isEnabled)
        XCTAssertEqual(loaded.bodyBreak.colorHex, "#123456")
        XCTAssertEqual(loaded.shortcuts.reset, ShortcutSettings.defaults.reset)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let shortcuts = try XCTUnwrap(raw["shortcuts"] as? [String: Any])
        XCTAssertNil(shortcuts["reset"])
    }

    func testRestEngineNormalizesUnsafeSettingsBeforeScheduling() {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 0
        settings.eyeGate.duration = -20
        settings.eyeGate.enforcement = EnforcementProfile(
            coversAllDisplays: false,
            usesScreenSaverLevel: false,
            isOpaque: false,
            opacity: 0,
            allowRegularWindowMode: true,
            coveredDisplay: .configured,
            contentDisplay: .none,
            blankSecondaryDisplays: false,
            configuredDisplayIndex: 9
        )
        settings.bodyBreak.enforcement.opacity = 2
        settings.notifications.eyeGateLeadTime = -10

        let engine = RestEngine(settings: settings, now: start)

        XCTAssertEqual(engine.settings.eyeGate.interval, 1)
        XCTAssertEqual(engine.settings.eyeGate.duration, 1)
        XCTAssertEqual(engine.settings.eyeGate.enforcement, .eyeGateDefault)
        XCTAssertEqual(engine.settings.bodyBreak.enforcement.opacity, 1)
        XCTAssertEqual(engine.settings.notifications.eyeGateLeadTime, 0)
        XCTAssertEqual(engine.state.scheduled?.dueAt, start.addingTimeInterval(1))
    }

    func testSettingsStoreMigratesLegacyEmergencyConfirmationSteps() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 3
        )
        legacy.bodyBreak.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 2
        )

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rawData = try settingsDataWithLegacyEmergencyHold(
            legacy,
            eyeGateHold: 3,
            bodyBreakHold: 2
        )
        try rawData.write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.eyeGate.emergencyOverride.confirmationSteps, 1)
        XCTAssertTrue(loaded.eyeGate.emergencyOverride.isEnabled)
        XCTAssertEqual(loaded.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertFalse(loaded.bodyBreak.emergencyOverride.isEnabled)
        let migratedData = try Data(contentsOf: url)
        let migratedRaw = try JSONDecoder().decode(RestSettings.self, from: migratedData)
        XCTAssertEqual(migratedRaw.eyeGate.emergencyOverride.confirmationSteps, 1)
        XCTAssertTrue(migratedRaw.eyeGate.emergencyOverride.isEnabled)
        XCTAssertEqual(migratedRaw.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertFalse(migratedRaw.bodyBreak.emergencyOverride.isEnabled)
        XCTAssertFalse(String(data: migratedData, encoding: .utf8)?.contains("minimumHoldDuration") ?? true)

        try store.save(legacy)
        let savedData = try Data(contentsOf: url)
        let savedRaw = try JSONDecoder().decode(RestSettings.self, from: savedData)

        XCTAssertEqual(savedRaw.eyeGate.emergencyOverride.confirmationSteps, 1)
        XCTAssertTrue(savedRaw.eyeGate.emergencyOverride.isEnabled)
        XCTAssertEqual(savedRaw.bodyBreak.emergencyOverride.confirmationSteps, 0)
        XCTAssertFalse(savedRaw.bodyBreak.emergencyOverride.isEnabled)
        XCTAssertFalse(String(data: savedData, encoding: .utf8)?.contains("minimumHoldDuration") ?? true)
    }

    func testSettingsStoreDropsDisabledEyeGateEmergencyConfirmationState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var legacy = RestSettings.defaults
        legacy.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: false,
            confirmationSteps: 3
        )

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: url, options: [.atomic])

        let loaded = try store.load()

        XCTAssertFalse(loaded.eyeGate.emergencyOverride.isEnabled)
        XCTAssertEqual(loaded.eyeGate.emergencyOverride.confirmationSteps, 0)
        let migratedData = try Data(contentsOf: url)
        let migratedRaw = try JSONDecoder().decode(RestSettings.self, from: migratedData)
        XCTAssertFalse(migratedRaw.eyeGate.emergencyOverride.isEnabled)
        XCTAssertEqual(migratedRaw.eyeGate.emergencyOverride.confirmationSteps, 0)
        XCTAssertFalse(String(data: migratedData, encoding: .utf8)?.contains("minimumHoldDuration") ?? true)
    }

    func testSettingsStoreDropsLegacyEmergencyHoldKeyWhenNoOtherMigrationIsNeeded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        let legacyData = try settingsDataWithLegacyEmergencyHold(
            .defaults,
            eyeGateHold: 30,
            bodyBreakHold: 30
        )

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacyData.write(to: url, options: [.atomic])

        let loaded = try store.load()
        let savedData = try Data(contentsOf: url)

        XCTAssertEqual(loaded.eyeGate.emergencyOverride.confirmationSteps, EmergencyOverridePolicy.defaults.confirmationSteps)
        XCTAssertEqual(loaded.bodyBreak.emergencyOverride, .disabled)
        XCTAssertFalse(String(data: savedData, encoding: .utf8)?.contains("minimumHoldDuration") ?? true)
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

    func testShortcutSettingsDecodesLegacyMissingResetShortcut() throws {
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
          "skipToNextBodyBreak": ""
        }
        """#.data(using: .utf8)!

        let shortcuts = try JSONDecoder().decode(ShortcutSettings.self, from: legacyJSON)

        XCTAssertEqual(shortcuts.reset, "")
        XCTAssertNil(shortcuts.emergencyEyeGateOverride)
        XCTAssertEqual(shortcuts.resolvedEndBodyBreakShortcut, ShortcutSettings.defaultEndBodyBreakShortcut)
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

    private func atNaturalPause(_ context: RestContext = RestContext()) -> RestContext {
        var context = context
        context.idleDuration = max(context.idleDuration, RestTiming.naturalPause)
        return context
    }

    private func advanceUntilBodyBreakIsNext(_ engine: inout RestEngine) {
        for _ in 0..<20 {
            guard let scheduled = engine.state.scheduled else {
                XCTFail("Expected a projected schedule")
                return
            }
            if scheduled.kind == .bodyBreak {
                return
            }
            let result = engine.evaluate(now: scheduled.dueAt, context: atNaturalPause())
            guard case .started(let session) = result else {
                XCTFail("Expected projected Eye Gate to start before Body Break")
                return
            }
            _ = engine.completeActive(
                now: scheduled.dueAt.addingTimeInterval(session.duration),
                reason: .completed
            )
        }
        XCTFail("Body Break did not become the next projected rest")
    }

    /// Isolate exposure and action policies from the separately tested cue lead time.
    private func withoutCues(_ settings: RestSettings) -> RestSettings {
        var settings = settings
        settings.notifications.eyeGateEnabled = false
        settings.notifications.bodyBreakEnabled = false
        return settings
    }

    private func bodyFirstSettings() -> RestSettings {
        var settings = RestSettings.defaults
        settings.eyeGate.interval = 60 * 60
        settings.bodyBreak.interval = 10 * 60
        return settings
    }

    /// Eye Gate and Body Break fall due together, as they do every hour with the default rhythm.
    private func alignedSettings() -> RestSettings {
        var settings = RestSettings.defaults
        settings.bodyBreak.interval = settings.eyeGate.interval
        return settings
    }

    private func presentationRule() -> AppExclusionRule {
        AppExclusionRule(
            id: "presentation",
            name: "Presentation",
            matchTerms: ["Keynote"],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
    }

    private func settingsDataWithLegacyEmergencyHold(
        _ settings: RestSettings,
        eyeGateHold: TimeInterval,
        bodyBreakHold: TimeInterval
    ) throws -> Data {
        let data = try JSONEncoder().encode(settings)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try injectLegacyEmergencyHold(eyeGateHold, into: &object, ruleKey: "eyeGate")
        try injectLegacyEmergencyHold(bodyBreakHold, into: &object, ruleKey: "bodyBreak")
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func injectLegacyEmergencyHold(
        _ hold: TimeInterval,
        into object: inout [String: Any],
        ruleKey: String
    ) throws {
        var rule = try XCTUnwrap(object[ruleKey] as? [String: Any])
        var emergencyOverride = try XCTUnwrap(rule["emergencyOverride"] as? [String: Any])
        emergencyOverride["minimumHoldDuration"] = hold
        rule["emergencyOverride"] = emergencyOverride
        object[ruleKey] = rule
    }

    private func legacySettingsDataWithMissingFields() throws -> Data {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.colorHex = "#123456"
        settings.contentLibrary = ContentLibrarySettings(
            useBuiltInIdeas: false,
            customBodyBreakIdeas: [
                RestIdea(id: "legacy-custom", kind: .bodyBreak, title: "Legacy custom", body: "Move")
            ],
            localImagePaths: ["/tmp/body.png"]
        )
        settings.appExclusions = [
            AppExclusionRule(
                id: "legacy-rule",
                name: "Legacy rule",
                matchTerms: ["Zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        settings.admin.customPreferencesMessage = "Keep strict"

        let data = try JSONEncoder().encode(settings)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        var notifications = try XCTUnwrap(object["notifications"] as? [String: Any])
        notifications.removeValue(forKey: "silentNotifications")
        notifications.removeValue(forKey: "eyeGateFullScreenCueEnabled")
        notifications.removeValue(forKey: "bodyBreakFullScreenCueEnabled")
        object["notifications"] = notifications

        var shortcuts = try XCTUnwrap(object["shortcuts"] as? [String: Any])
        shortcuts.removeValue(forKey: "reset")
        shortcuts.removeValue(forKey: "endBodyBreak")
        shortcuts.removeValue(forKey: "emergencyEyeGateOverride")
        object["shortcuts"] = shortcuts

        var contentLibrary = try XCTUnwrap(object["contentLibrary"] as? [String: Any])
        contentLibrary.removeValue(forKey: "localImagePaths")
        var ideas = try XCTUnwrap(contentLibrary["customBodyBreakIdeas"] as? [[String: Any]])
        ideas[0].removeValue(forKey: "isEnabled")
        contentLibrary["customBodyBreakIdeas"] = ideas
        object["contentLibrary"] = contentLibrary

        var appExclusions = try XCTUnwrap(object["appExclusions"] as? [[String: Any]])
        appExclusions[0].removeValue(forKey: "appliesTo")
        object["appExclusions"] = appExclusions

        var admin = try XCTUnwrap(object["admin"] as? [String: Any])
        admin.removeValue(forKey: "customPreferencesMessage")
        object["admin"] = admin

        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func settingsDataWithLegacyBodyBreakAfterEyeGates(_ settings: RestSettings, count: Int) throws -> Data {
        let data = try JSONEncoder().encode(settings)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["bodyBreakAfterEyeGates"] = count
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func unsafeSettingsData() throws -> Data {
        let data = try JSONEncoder().encode(RestSettings.defaults)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        var eyeGate = try XCTUnwrap(object["eyeGate"] as? [String: Any])
        eyeGate["interval"] = 0
        eyeGate["duration"] = -20
        var eyeEnforcement = try XCTUnwrap(eyeGate["enforcement"] as? [String: Any])
        eyeEnforcement["coversAllDisplays"] = false
        eyeEnforcement["usesScreenSaverLevel"] = false
        eyeEnforcement["isOpaque"] = false
        eyeEnforcement["opacity"] = 0
        eyeEnforcement["allowRegularWindowMode"] = true
        eyeEnforcement["coveredDisplay"] = "configured"
        eyeEnforcement["contentDisplay"] = "none"
        eyeEnforcement["blankSecondaryDisplays"] = false
        eyeEnforcement["configuredDisplayIndex"] = 9
        eyeGate["enforcement"] = eyeEnforcement
        object["eyeGate"] = eyeGate

        var bodyBreak = try XCTUnwrap(object["bodyBreak"] as? [String: Any])
        bodyBreak["colorHex"] = "not-a-color"
        var bodyPostpone = try XCTUnwrap(bodyBreak["postpone"] as? [String: Any])
        bodyPostpone["duration"] = 0
        bodyPostpone["maxCount"] = -4
        bodyPostpone["allowedDuringFirstPercent"] = 250
        bodyBreak["postpone"] = bodyPostpone
        var bodyEnforcement = try XCTUnwrap(bodyBreak["enforcement"] as? [String: Any])
        bodyEnforcement["opacity"] = 2
        bodyEnforcement["configuredDisplayIndex"] = -8
        bodyBreak["enforcement"] = bodyEnforcement
        bodyBreak["startSound"] = ["named": ["_0": "crystal-glass", "volume": 5]]
        bodyBreak["finishSound"] = ["named": ["_0": "crystal-glass", "volume": -2]]
        object["bodyBreak"] = bodyBreak

        var notifications = try XCTUnwrap(object["notifications"] as? [String: Any])
        notifications["eyeGateLeadTime"] = -10
        notifications["bodyBreakLeadTime"] = -30
        object["notifications"] = notifications

        var naturalBreaks = try XCTUnwrap(object["naturalBreaks"] as? [String: Any])
        naturalBreaks["inactivityResetTime"] = 0
        object["naturalBreaks"] = naturalBreaks

        var workingHours = try XCTUnwrap(object["workingHours"] as? [String: Any])
        workingHours["startMinuteOfDay"] = -1
        workingHours["endMinuteOfDay"] = 2_000
        object["workingHours"] = workingHours

        object["appExclusions"] = [[
            "id": "empty-term-rule",
            "name": "Empty term rule",
            "matchTerms": ["", "  ", " Zoom "],
            "mode": "pauseWhenMatched",
            "appliesTo": ["bodyBreak"],
            "isEnabled": true
        ]]

        var operations = try XCTUnwrap(object["operations"] as? [String: Any])
        operations["pauseUntilMorningHour"] = 99
        operations["pauseUntilMorningLatitude"] = 120
        operations["pauseUntilMorningLongitude"] = 1_000
        object["operations"] = operations

        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
