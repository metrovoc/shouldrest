import Darwin
import XCTest
@testable import shouldrest

@MainActor
final class CommandLineAutomationTests: XCTestCase {
    func testHelpDescribesSupportCommandsAsDirectUserActions() {
        let output = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: ["shouldrest", "help"]))
        }

        XCTAssertTrue(output.contains("eye|mini [-w wait]           Start Eye Gate now or after wait; it is always strict and text-free."))
        XCTAssertTrue(output.contains("preferences                  Open ShouldRest preferences."))
        XCTAssertTrue(output.contains("debug                        Copy diagnostics."))
        XCTAssertTrue(output.contains("debug-panel                  Open the diagnostics window."))
        XCTAssertTrue(output.contains("about                        Open the About window."))
        XCTAssertTrue(output.contains("url shouldrest://<command>    Run a shouldrest:// command."))
        XCTAssertTrue(output.contains("emergency                    Bring the active Eye Gate overlay forward for Emergency Exit."))
        XCTAssertTrue(output.contains("settings                     Show settings location."))
        XCTAssertTrue(output.contains("logs                         Show log location."))
        XCTAssertFalse(output.contains("eye|mini [-w wait] [-n]"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("url-style automation"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("automation URL"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("readable content is not customizable"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("running app"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("settings path"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("log path"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("hidden by admin"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("copy debug info"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("debug panel"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("run it again"))
    }

    func testCommandLineErrorsUseLocalizedCopy() {
        L10n.languageOverride = "zh-Hans"
        defer { L10n.languageOverride = nil }

        let invalidURLOutput = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: ["shouldrest", "shouldrest://unknown"]))
        }
        let invalidPauseOutput = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: ["shouldrest", "pause", "--duration", "later"]))
        }
        let unknownCommandOutput = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: ["shouldrest", "bogus"]))
        }

        XCTAssertTrue(invalidURLOutput.contains("ShouldRest URL 无效：shouldrest://unknown"))
        XCTAssertFalse(invalidURLOutput.contains("Invalid ShouldRest URL"))
        XCTAssertTrue(invalidPauseOutput.contains("暂停时长无效：later"))
        XCTAssertFalse(invalidPauseOutput.contains("Invalid pause duration"))
        XCTAssertTrue(unknownCommandOutput.contains("未知命令：bogus"))
        XCTAssertTrue(unknownCommandOutput.contains("用法：shouldrest <命令> [选项]"))
        XCTAssertTrue(unknownCommandOutput.contains("显示设置位置"))
        XCTAssertTrue(unknownCommandOutput.contains("显示日志位置"))
        XCTAssertFalse(unknownCommandOutput.contains("除非策略隐藏"))
        XCTAssertFalse(unknownCommandOutput.contains("设置文件路径"))
        XCTAssertFalse(unknownCommandOutput.contains("日志路径"))
        XCTAssertFalse(unknownCommandOutput.contains("管理员"))
        XCTAssertFalse(unknownCommandOutput.contains("Unknown command"))
    }

    func testEyeGateCommandLineWarningsUseLocalizedCopy() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        let englishOutput = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: [
                "shouldrest",
                "mini",
                "--title",
                "Read this",
                "--noskip"
            ]))
        }

        XCTAssertTrue(englishOutput.contains("Eye Gate does not show custom text, so title/text was ignored."))
        XCTAssertTrue(englishOutput.contains("No wait was provided, so the current Eye Gate schedule was kept."))
        XCTAssertFalse(englishOutput.localizedCaseInsensitiveContains("readable content customization"))
        XCTAssertFalse(englishOutput.localizedCaseInsensitiveContains("noskip"))
        XCTAssertFalse(englishOutput.contains("current schedule kept"))

        L10n.languageOverride = "zh-Hans"
        let simplifiedChineseOutput = captureStandardOutput {
            XCTAssertTrue(CommandLineAutomation.handle(arguments: [
                "shouldrest",
                "mini",
                "--title",
                "Read this",
                "--noskip"
            ]))
        }

        XCTAssertTrue(simplifiedChineseOutput.contains("护眼休息不显示自定义文字，标题或正文已忽略。"))
        XCTAssertTrue(simplifiedChineseOutput.contains("没有设置等待时长，当前护眼计划保持不变。"))
        XCTAssertFalse(simplifiedChineseOutput.contains("可阅读内容自定义"))
        XCTAssertFalse(simplifiedChineseOutput.contains("不跳过"))
        XCTAssertFalse(simplifiedChineseOutput.contains("未设置等待时长；当前计划保持不变"))
        XCTAssertFalse(simplifiedChineseOutput.contains("Eye Gate readable content customization is ignored."))
        XCTAssertFalse(simplifiedChineseOutput.contains("current schedule kept"))
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
