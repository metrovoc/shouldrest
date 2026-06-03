import XCTest
@testable import shouldrest

@MainActor
final class CommandLineAutomationTests: XCTestCase {
    func testParsesStretchlyStyleDurations() throws {
        XCTAssertEqual(CommandLineAutomation.parseDuration("60"), 60 * 60)
        XCTAssertEqual(CommandLineAutomation.parseDuration("1h"), 60 * 60)
        XCTAssertEqual(CommandLineAutomation.parseDuration("1h20m"), 80 * 60)
        XCTAssertEqual(CommandLineAutomation.parseDuration("20m"), 20 * 60)
        let untilMorning = try XCTUnwrap(CommandLineAutomation.parseDuration("until-morning", morningHour: 6))
        XCTAssertGreaterThan(untilMorning, 0)
        XCTAssertLessThanOrEqual(untilMorning, 24 * 60 * 60)
        XCTAssertNil(CommandLineAutomation.parseDuration("indefinitely"))
        XCTAssertNil(CommandLineAutomation.parseDuration("0"))
        XCTAssertNil(CommandLineAutomation.parseDuration("abc"))
    }

    func testParsesPauseURLAutomation() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://pause?duration=1h20m"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .pause)
        XCTAssertEqual(request.duration, 80 * 60)
        XCTAssertNil(request.title)
        XCTAssertNil(request.text)
        XCTAssertFalse(request.noSkip)
    }

    func testParsesBodyBreakURLAutomationWithAliasesAndCustomization() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://long?wait=20m&title=Stretch%20up&text=Go%20stretch&noskip=1"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .body)
        XCTAssertEqual(request.duration, 20 * 60)
        XCTAssertEqual(request.title, "Stretch up")
        XCTAssertEqual(request.text, "Go stretch")
        XCTAssertTrue(request.noSkip)
    }

    func testParsesMiniAliasAsEyeGateWithoutReadableContent() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://mini?wait=5m&noskip=1"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .eye)
        XCTAssertEqual(request.duration, 5 * 60)
        XCTAssertTrue(request.noSkip)
    }

    func testRejectsInvalidAutomationURLs() throws {
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "stretchly://pause?duration=1h"))))
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "shouldrest://pause?duration=bad"))))
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "shouldrest://unknown"))))
    }
}
