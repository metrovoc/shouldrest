import Darwin
import XCTest
@testable import shouldrest

@MainActor
final class CommandLineAutomationTests: XCTestCase {
    func testHelpDescribesDebugCommandsAsDiagnostics() {
        let output = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: ["shouldrest", "help"]))
        }

        XCTAssertTrue(output.contains("debug                        Copy diagnostics from the running app."))
        XCTAssertTrue(output.contains("debug-panel                  Open the diagnostics window in the running app."))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("copy debug info"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("debug panel"))
    }

    func testEmergencyAutomationSignalWritesAndConsumesMarker() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let marker = directory.appendingPathComponent("emergency-request")

        XCTAssertFalse(EmergencyAutomationSignal.consume(fileURL: marker))

        try EmergencyAutomationSignal.write(fileURL: marker)

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertTrue(EmergencyAutomationSignal.isPending(fileURL: marker))
        XCTAssertTrue(EmergencyAutomationSignal.consume(fileURL: marker))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertFalse(EmergencyAutomationSignal.consume(fileURL: marker))
    }

    func testEmergencyAutomationSignalExpiresStaleMarker() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let marker = directory.appendingPathComponent("emergency-request")
        let now = Date()

        try EmergencyAutomationSignal.write(fileURL: marker, now: now.addingTimeInterval(-11))

        XCTAssertFalse(EmergencyAutomationSignal.isPending(fileURL: marker, now: now, maxAge: 10))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

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

    func testParsesDebugPanelURLAutomation() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://debug-panel"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .debugPanel)
        XCTAssertNil(request.duration)
        XCTAssertNil(request.title)
        XCTAssertNil(request.text)
        XCTAssertFalse(request.noSkip)
    }

    func testParsesAboutURLAutomation() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://about"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .about)
        XCTAssertNil(request.duration)
        XCTAssertNil(request.title)
        XCTAssertNil(request.text)
        XCTAssertFalse(request.noSkip)
    }

    func testParsesEmergencyExitURLAutomation() throws {
        let url = try XCTUnwrap(URL(string: "shouldrest://emergency"))
        let request = try XCTUnwrap(CommandLineAutomation.request(from: url))

        XCTAssertEqual(request.command, .emergency)
        XCTAssertNil(request.duration)
        XCTAssertNil(request.title)
        XCTAssertNil(request.text)
        XCTAssertFalse(request.noSkip)
    }

    func testPlansImmediateMiniAliasAsEyeGateRequest() throws {
        let plan = CommandLineAutomation.eyeGateCommandPlan(["mini"])

        let request = try XCTUnwrap(plan.request)
        XCTAssertEqual(request.command, .eye)
        XCTAssertNil(request.duration)
        XCTAssertFalse(request.noSkip)
        XCTAssertFalse(plan.keepsCurrentSchedule)
        XCTAssertNil(plan.invalidWait)
        XCTAssertFalse(plan.ignoredReadableContent)
    }

    func testMiniNoSkipWithoutWaitKeepsCurrentSchedule() throws {
        let plan = CommandLineAutomation.eyeGateCommandPlan(["mini", "--noskip"])

        XCTAssertNil(plan.request)
        XCTAssertTrue(plan.keepsCurrentSchedule)
        XCTAssertNil(plan.invalidWait)
        XCTAssertFalse(plan.ignoredReadableContent)
    }

    func testMiniNoSkipWithWaitSchedulesDelayedEyeGate() throws {
        let plan = CommandLineAutomation.eyeGateCommandPlan(["mini", "--noskip", "--wait", "20m"])

        let request = try XCTUnwrap(plan.request)
        XCTAssertEqual(request.command, .eye)
        XCTAssertEqual(request.duration, 20 * 60)
        XCTAssertTrue(request.noSkip)
        XCTAssertFalse(plan.keepsCurrentSchedule)
        XCTAssertNil(plan.invalidWait)
    }

    func testMiniTitleIsIgnoredInsteadOfInjectedIntoEyeGate() throws {
        let plan = CommandLineAutomation.eyeGateCommandPlan(["mini", "--title", "Stretch up"])

        let request = try XCTUnwrap(plan.request)
        XCTAssertEqual(request.command, .eye)
        XCTAssertNil(request.title)
        XCTAssertNil(request.text)
        XCTAssertTrue(plan.ignoredReadableContent)
    }

    func testRejectsInvalidAutomationURLs() throws {
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "stretchly://pause?duration=1h"))))
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "shouldrest://pause?duration=bad"))))
        XCTAssertNil(CommandLineAutomation.request(from: try XCTUnwrap(URL(string: "shouldrest://unknown"))))
    }

    private func captureStandardOutput(_ work: () -> Void) -> String {
        let originalStdout = dup(STDOUT_FILENO)
        let pipe = Pipe()

        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        work()

        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
