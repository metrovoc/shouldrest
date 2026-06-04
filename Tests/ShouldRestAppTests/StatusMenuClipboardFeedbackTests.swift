import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class StatusMenuClipboardFeedbackTests: XCTestCase {
    func testDiagnosticsCopyWritesPasteboardAndReturnsCompletionFeedback() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))

        let feedback = StatusMenuClipboardFeedback.copy(
            "state=active",
            kind: .diagnostics,
            pasteboard: pasteboard
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "state=active")
        XCTAssertEqual(feedback, L10n.tr("menu.copyDebugDone"))
        XCTAssertEqual(feedback, "Diagnostics copied to the clipboard.")
        XCTAssertFalse(feedback.localizedCaseInsensitiveContains("debug info"))
    }

    func testSettingsPathCopyWritesPasteboardAndReturnsLocalizedCompletionFeedback() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "zh-Hans"
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))

        let feedback = StatusMenuClipboardFeedback.copy(
            "/tmp/shouldrest/settings.json",
            kind: .settingsPath,
            pasteboard: pasteboard
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "/tmp/shouldrest/settings.json")
        XCTAssertEqual(feedback, L10n.tr("menu.copySettingsPathDone"))
        XCTAssertEqual(feedback, "设置位置已复制到剪贴板。")
        XCTAssertFalse(feedback.contains("设置路径"))
    }
}
