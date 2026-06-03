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
