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
        let result = engine.emergencyOverride(now: start.addingTimeInterval(3))

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

    func testBodyBreakPostponeLimitIsEnforced() {
        var engine = RestEngine(settings: .defaults, now: start)
        _ = engine.takeNow(.bodyBreak, now: start)
        _ = engine.postponeActive(now: start.addingTimeInterval(1))
        _ = engine.evaluate(now: start.addingTimeInterval(1 + 5 * 60))

        XCTAssertEqual(engine.postponeActive(now: start.addingTimeInterval(1 + 5 * 60)), .denied(.postponeLimitReached))
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

    func testContentSanitizerRemovesScriptsAndDangerousAttributes() {
        let unsafe = #"""
        <p onclick="alert(1)">Stretch</p>
        <script>alert("x")</script>
        <a href="javascript:alert(1)">bad</a>
        <img src="data:text/html;base64,abc">
        """#

        let sanitized = ContentSanitizer.sanitizeRichText(unsafe)

        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("script"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("onclick"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("javascript:"))
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("data:"))
        XCTAssertTrue(sanitized.contains("Stretch"))
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
