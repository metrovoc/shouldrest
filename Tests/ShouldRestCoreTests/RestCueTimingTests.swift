import Foundation
import XCTest
@testable import ShouldRestCore

final class RestCueTimingTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testEarlyEyeGateGetsFullCueBeforeStarting() {
        var engine = RestEngine(now: start)
        let early = start.addingTimeInterval(1_140)
        XCTAssertEqual(engine.evaluate(now: early, context: RestContext(idleDuration: 15)), .notificationDue(.eyeGate))
        XCTAssertEqual(engine.evaluate(now: early.addingTimeInterval(9), context: RestContext(idleDuration: 24)), .noChange)
        guard case .started(let session) = engine.evaluate(now: early.addingTimeInterval(10), context: RestContext(idleDuration: 25)) else {
            return XCTFail("Expected early start after full cue")
        }
        XCTAssertEqual(session.kind, .eyeGate)
        XCTAssertNil(engine.pendingCueKind)
    }

    func testLateTimerTickStillProvidesFullCueAtDeadline() {
        var engine = RestEngine(now: start)
        let deadline = start.addingTimeInterval(1_260)
        XCTAssertEqual(engine.evaluate(now: deadline), .notificationDue(.eyeGate))
        XCTAssertEqual(engine.evaluate(now: deadline.addingTimeInterval(9)), .noChange)
        guard case .started = engine.evaluate(now: deadline.addingTimeInterval(10)) else {
            return XCTFail("Expected deadline start after cue")
        }
    }

    func testMergedBodyGetsItsOwnFullCue() {
        var settings = RestSettings.defaults
        settings.bodyBreak.interval = 1_260
        var engine = RestEngine(settings: settings, now: start)
        XCTAssertEqual(engine.evaluate(now: start.addingTimeInterval(1_190)), .notificationDue(.eyeGate))
        XCTAssertEqual(engine.evaluate(now: start.addingTimeInterval(1_200), context: RestContext(idleDuration: 2)), .notificationDue(.bodyBreak))
        // Typing again must not replace the Body Break cue with the projected Eye Gate cue.
        XCTAssertEqual(engine.evaluate(now: start.addingTimeInterval(1_201)), .noChange)
        XCTAssertEqual(engine.pendingCueKind, .bodyBreak)
        XCTAssertEqual(engine.evaluate(now: start.addingTimeInterval(1_229), context: RestContext(idleDuration: 2)), .noChange)
        guard case .started(let session) = engine.evaluate(now: start.addingTimeInterval(1_230), context: RestContext(idleDuration: 2)) else {
            return XCTFail("Expected combined Body Break after its full lead time")
        }
        XCTAssertEqual(session.kind, .bodyBreak)
    }

    func testFocusDismissesCueAndRequiresFreshLeadOnRelease() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        var engine = RestEngine(settings: settings, now: start)
        let due = start.addingTimeInterval(3_600)
        XCTAssertEqual(engine.evaluate(now: due.addingTimeInterval(-30)), .notificationDue(.bodyBreak))
        XCTAssertEqual(engine.evaluate(now: due, context: RestContext(idleDuration: 2, focusModeActive: true)), .deferred(.bodyBreak, .focusMode))
        XCTAssertNil(engine.pendingCueKind)
        XCTAssertEqual(engine.evaluate(now: due.addingTimeInterval(10), context: RestContext(idleDuration: 2)), .notificationDue(.bodyBreak))
        XCTAssertEqual(engine.evaluate(now: due.addingTimeInterval(39), context: RestContext(idleDuration: 2)), .noChange)
        guard case .started = engine.evaluate(now: due.addingTimeInterval(40), context: RestContext(idleDuration: 2)) else {
            return XCTFail("Expected fresh cue after context clears")
        }
    }

    func testRelaunchDoesNotTrustPersistedNotificationFlag() throws {
        var engine = RestEngine(now: start)
        let now = start.addingTimeInterval(1_190)
        XCTAssertEqual(engine.evaluate(now: now), .notificationDue(.eyeGate))
        let data = try JSONEncoder().encode(engine.state)
        let restored = try JSONDecoder().decode(RestEngineState.self, from: data)
        var restarted = RestEngine(restoring: restored, now: now)
        XCTAssertEqual(restarted.evaluate(now: now.addingTimeInterval(10), context: RestContext(idleDuration: 2)), .notificationDue(.eyeGate))
        XCTAssertNil(restarted.state.activeSession)
    }

    func testDisabledCuesAndManualStartsDoNotWait() {
        var settings = RestSettings.defaults
        settings.notifications.eyeGateEnabled = false
        var automatic = RestEngine(settings: settings, now: start)
        guard case .started = automatic.evaluate(now: start.addingTimeInterval(1_200), context: RestContext(idleDuration: 2)) else {
            return XCTFail("Disabled cues must not delay a rest")
        }
        var manual = RestEngine(now: start)
        guard case .started = manual.takeNow(.eyeGate, now: start) else {
            return XCTFail("An explicit start must be immediate")
        }
    }

    func testBodyOnlyPauseDoesNotRestartEyeCueEveryTick() {
        var engine = RestEngine(now: start)
        _ = engine.pause(for: nil, now: start, appliesTo: [.bodyBreak])
        let due = start.addingTimeInterval(1_200)
        XCTAssertEqual(engine.evaluate(now: due, context: RestContext(idleDuration: 2)), .notificationDue(.eyeGate))
        for second in 1..<10 {
            XCTAssertEqual(engine.evaluate(now: due.addingTimeInterval(Double(second)), context: RestContext(idleDuration: 2)), .noChange)
        }
        guard case .started = engine.evaluate(now: due.addingTimeInterval(10), context: RestContext(idleDuration: 2)) else {
            return XCTFail("Body-only pause must allow the Eye Gate cue to finish")
        }
    }

    func testResetAndAwayDiscardCue() {
        var engine = RestEngine(now: start)
        _ = engine.evaluate(now: start.addingTimeInterval(1_190))
        _ = engine.reset(now: start.addingTimeInterval(1_191))
        XCTAssertNil(engine.pendingCueKind)
        _ = engine.evaluate(now: start.addingTimeInterval(2_381))
        XCTAssertEqual(engine.pendingCueKind, .eyeGate)
        _ = engine.evaluate(now: start.addingTimeInterval(2_700), context: RestContext(idleDuration: 319))
        XCTAssertNil(engine.pendingCueKind)
    }

    func testEyeGateSpacingDoesNotRestartTheCallDeferralLimit() {
        var settings = RestSettings.defaults
        settings.bodyBreak.interval = 1_200
        var engine = RestEngine(settings: settings, now: start)
        let due = start.addingTimeInterval(1_200)
        let call = RestContext(idleDuration: 2, inCall: true)
        _ = engine.evaluate(now: due, context: call)
        _ = engine.evaluate(now: due.addingTimeInterval(10), context: call)
        let originalHold = engine.state.activeDeferral?.startedAt
        XCTAssertNotNil(originalHold)
        _ = engine.completeActive(now: due.addingTimeInterval(30), context: call)
        _ = engine.evaluate(now: due.addingTimeInterval(31), context: call)
        XCTAssertEqual(engine.state.activeDeferral?.startedAt, originalHold,
                       "Spacing must not let a continuous call hold Body Breaks indefinitely")
    }

    func testBodyHeldDuringEyeGateCannotFollowImmediatelyAfterCallEnds() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.interval = 1_260
        var engine = RestEngine(settings: settings, now: start)
        let due = start.addingTimeInterval(1_200)
        XCTAssertEqual(engine.evaluate(now: due, context: RestContext(idleDuration: 2, inCall: true)), .notificationDue(.eyeGate))
        guard case .started = engine.evaluate(now: due.addingTimeInterval(10), context: RestContext(idleDuration: 2, inCall: true)) else {
            return XCTFail("Expected Eye Gate while microphone holds Body Break")
        }
        let end = due.addingTimeInterval(30)
        _ = engine.completeActive(now: end)
        let saved = try JSONDecoder().decode(RestEngineState.self, from: JSONEncoder().encode(engine.state))
        engine = RestEngine(settings: settings, restoring: saved, now: end)
        for second in 1..<300 {
            let result = engine.evaluate(now: end.addingTimeInterval(Double(second)), context: RestContext(idleDuration: 2))
            if case .started = result { XCTFail("Body Break arrived too soon after Eye Gate"); return }
        }
        guard case .started(let body) = engine.evaluate(now: end.addingTimeInterval(300), context: RestContext(idleDuration: 2)) else {
            return XCTFail("Expected Body Break after spacing and cue")
        }
        XCTAssertEqual(body.kind, .bodyBreak)
        XCTAssertGreaterThan(engine.state.bodyDebt, 0, "Spacing must preserve body debt")
    }
}
