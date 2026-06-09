import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class RestContextPolicyTests: XCTestCase {
    func testResumeContextPreservesPolicyInputsInsteadOfUsingDefaults() throws {
        var settings = RestSettings.defaults
        settings.workingHours = WorkingHoursSettings(
            isEnabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 17 * 60
        )
        let now = try localDate(hour: 20, minute: 0)
        let rule = AppExclusionRule(
            id: "presentation",
            name: "Presentation",
            matchTerms: ["Keynote"],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )
        let appExclusions = [AppExclusionEvaluation(rule: rule, isMatched: true)]

        let context = RestContextPolicy.make(
            settings: settings,
            now: now,
            idleDuration: 120,
            focusModeActive: true,
            appExclusions: appExclusions
        )

        XCTAssertEqual(context.idleDuration, 120)
        XCTAssertTrue(context.focusModeActive)
        XCTAssertFalse(context.inWorkingHours)
        XCTAssertEqual(context.appExclusions, appExclusions)
    }

    func testWakeEvaluationDefersDueRestOutsideWorkingHours() throws {
        var settings = RestSettings.defaults
        settings.workingHours = WorkingHoursSettings(
            isEnabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 17 * 60
        )
        let now = try localDate(hour: 20, minute: 0)
        var engine = RestEngine(settings: settings, now: now.addingTimeInterval(-settings.eyeGate.interval))

        let context = RestContextPolicy.make(
            settings: settings,
            now: now,
            idleDuration: 0,
            focusModeActive: false,
            appExclusions: []
        )

        XCTAssertEqual(engine.evaluate(now: now, context: context), .deferred(.eyeGate, .outsideWorkingHours))
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.activeDeferral?.reason, .outsideWorkingHours)
    }

    func testSystemSuspendAutoPauseDoesNotReplaceExistingUserPause() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let userPause = PauseState(
            reason: .user,
            startedAt: start,
            until: start.addingTimeInterval(60 * 60)
        )
        let state = RestEngineState(pause: userPause)

        XCTAssertFalse(SystemSuspendPausePolicy.shouldPauseScheduler(state: state))

        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.pause(for: 60 * 60, now: start, reason: .user)
        if SystemSuspendPausePolicy.shouldPauseScheduler(state: engine.state) {
            _ = engine.pause(for: nil, now: start.addingTimeInterval(10), reason: .suspendOrLock)
        }

        XCTAssertEqual(engine.state.pause, userPause)
    }

    func testDuplicateSystemSuspendNotificationKeepsAutoPauseResumeOwnership() {
        let start = Date(timeIntervalSinceReferenceDate: 1_500)
        var engine = RestEngine(settings: .defaults, now: start)

        XCTAssertTrue(SystemSuspendPausePolicy.shouldPauseScheduler(state: engine.state))
        _ = engine.pause(for: nil, now: start, reason: .suspendOrLock)

        XCTAssertFalse(SystemSuspendPausePolicy.shouldPauseScheduler(state: engine.state))
        XCTAssertTrue(SystemSuspendPausePolicy.hasSuspendOrLockPause(state: engine.state))

        let duplicatePauseNotificationShouldKeepResumeOwnership =
            SystemSuspendPausePolicy.hasSuspendOrLockPause(state: engine.state)
        XCTAssertTrue(duplicatePauseNotificationShouldKeepResumeOwnership)
        XCTAssertEqual(engine.resume(now: start.addingTimeInterval(600)), .resumed)
    }

    func testSystemSuspendAutoPauseOnlyTargetsIdleSchedule() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let active = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        )

        XCTAssertTrue(SystemSuspendPausePolicy.shouldPauseScheduler(state: RestEngineState(
            scheduled: ScheduledRest(
                kind: .eyeGate,
                dueAt: start.addingTimeInterval(60),
                notificationAt: nil
            )
        )))
        XCTAssertFalse(SystemSuspendPausePolicy.shouldPauseScheduler(state: RestEngineState(activeSession: active)))
    }

    func testSystemResumeIdlePolicyKeepsSuspendIdleForNaturalRecovery() {
        XCTAssertEqual(
            SystemResumeIdlePolicy.effectiveIdleDuration(
                suspendedIdleDuration: 120,
                didPauseScheduler: false
            ),
            120
        )
        XCTAssertEqual(
            SystemResumeIdlePolicy.effectiveIdleDuration(
                suspendedIdleDuration: 120,
                didPauseScheduler: true
            ),
            120
        )
        XCTAssertEqual(
            SystemResumeIdlePolicy.effectiveIdleDuration(
                suspendedIdleDuration: -1,
                didPauseScheduler: false
            ),
            0
        )
        XCTAssertEqual(
            SystemResumeIdlePolicy.effectiveIdleDuration(
                preSuspendIdleDuration: 9 * 60,
                suspendedIdleDuration: 60,
                didPauseScheduler: true
            ),
            10 * 60
        )
    }

    func testSystemResumeAfterAutoPauseCreditsSuspendIdleAsNaturalRecoveryWhenDebtExists() {
        let sleepAt = Date(timeIntervalSinceReferenceDate: 3_000)
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        let wakeAt = sleepAt.addingTimeInterval(settings.naturalBreaks.inactivityResetTime)
        var engine = RestEngine(settings: settings, now: sleepAt.addingTimeInterval(-60))

        _ = engine.evaluate(now: sleepAt, context: RestContext(idleDuration: 0))
        XCTAssertGreaterThan(engine.state.eyeDebt, 0)

        _ = engine.pause(for: nil, now: sleepAt, reason: .suspendOrLock)
        XCTAssertEqual(engine.resume(now: wakeAt), .resumed)

        let context = RestContextPolicy.make(
            settings: settings,
            now: wakeAt,
            idleDuration: SystemResumeIdlePolicy.effectiveIdleDuration(
                suspendedIdleDuration: wakeAt.timeIntervalSince(sleepAt),
                didPauseScheduler: true
            ),
            focusModeActive: false,
            appExclusions: []
        )

        XCTAssertEqual(engine.evaluate(now: wakeAt, context: context), .naturalRestsCredited([.eyeGate]))
        XCTAssertEqual(engine.state.statistics.completedEyeGates, 1)
        XCTAssertEqual(engine.state.statistics.naturalEyeGates, 1)
        XCTAssertEqual(engine.state.scheduled?.kind, .eyeGate)
        XCTAssertEqual(engine.state.scheduled?.dueAt, wakeAt.addingTimeInterval(settings.eyeGate.interval))
    }

    private func localDate(hour: Int, minute: Int) throws -> Date {
        let calendar = Calendar.current
        let anchor = Date(timeIntervalSinceReferenceDate: 0)
        return try XCTUnwrap(calendar.date(bySettingHour: hour, minute: minute, second: 0, of: anchor))
    }
}
