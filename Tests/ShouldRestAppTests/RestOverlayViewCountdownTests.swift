import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewCountdownTests: XCTestCase {
    func testOverlayCountdownFormatterKeepsShortEyeGateSeconds() {
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 20), "20s")
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 0), "0s")
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: -4), "0s")
    }

    func testOverlayCountdownFormatterUsesReadableMinuteClock() {
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 60), "1:00")
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 75), "1:15")
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 300), "5:00")
        XCTAssertEqual(OverlayCountdownFormatter.remainingText(seconds: 3_661), "1:01:01")
    }

    func testBodyBreakOverlayShowsReadableCountdownInsteadOfRawSeconds() throws {
        let view = configuredBodyOverlay(remainingSeconds: 300)
        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)

        XCTAssertEqual(countdown.stringValue, "5:00")
    }

    func testBodyBreakOverlayCurrentTimeKeepsReadableCountdownPrefix() throws {
        var settings = RestSettings.defaults
        settings.presentation.showCurrentTimeDuringBodyBreak = true
        let view = configuredBodyOverlay(remainingSeconds: 75, settings: settings)
        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)

        XCTAssertTrue(countdown.stringValue.hasPrefix("1:15 · "))
    }

    func testEyeGateOverlayStillUsesCompactSecondCountdown() throws {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 20,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0
        )

        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)
        XCTAssertEqual(countdown.stringValue, "20s")
    }

    func testEyeGateOverlayUsesActionableLocalizedCopy() throws {
        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }

        let view = configuredEyeGateOverlay()

        let title = try XCTUnwrap(view.descendant(withIdentifier: "overlay.title.label") as? NSTextField)
        let detail = try XCTUnwrap(view.descendant(withIdentifier: "overlay.detail.label") as? NSTextField)
        XCTAssertEqual(title.stringValue, "Look far away")
        XCTAssertTrue(detail.stringValue.contains("Blink slowly"))
        XCTAssertTrue(detail.stringValue.contains("until the timer ends"))
    }

    func testEyeGateOverlayDoesNotLeakBuiltInEnglishCopyInChinese() throws {
        L10n.languageOverride = "zh-Hans"
        defer { L10n.languageOverride = nil }

        let view = configuredEyeGateOverlay()

        let title = try XCTUnwrap(view.descendant(withIdentifier: "overlay.title.label") as? NSTextField)
        let detail = try XCTUnwrap(view.descendant(withIdentifier: "overlay.detail.label") as? NSTextField)
        XCTAssertEqual(title.stringValue, "看向远处")
        XCTAssertTrue(detail.stringValue.contains("慢慢眨眼"))
        XCTAssertFalse(detail.stringValue.contains("Rest your eyes"))
        XCTAssertFalse(title.stringValue.contains("Look"))
    }

    func testManualAwaitingEyeGateOverlayUsesKindSpecificCompletionCopy() throws {
        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }

        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            manualAwaiting: true,
            manualFinishEnabled: true
        )

        let title = try XCTUnwrap(view.descendant(withIdentifier: "overlay.title.label") as? NSTextField)
        let detail = try XCTUnwrap(view.descendant(withIdentifier: "overlay.detail.label") as? NSTextField)
        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)
        XCTAssertEqual(title.stringValue, "Eye Gate complete")
        XCTAssertEqual(detail.stringValue, "Finish when you are ready to look back at the screen.")
        XCTAssertEqual(countdown.stringValue, "ready")
    }

    func testManualAwaitingBodyBreakOverlayUsesKindSpecificCompletionCopy() throws {
        L10n.languageOverride = "zh-Hans"
        defer { L10n.languageOverride = nil }

        let view = configuredBodyOverlay(
            remainingSeconds: 0,
            manualAwaiting: true
        )

        let title = try XCTUnwrap(view.descendant(withIdentifier: "overlay.title.label") as? NSTextField)
        let detail = try XCTUnwrap(view.descendant(withIdentifier: "overlay.detail.label") as? NSTextField)
        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)
        XCTAssertEqual(title.stringValue, "活动休息已完成")
        XCTAssertEqual(detail.stringValue, "准备好返回工作时再完成。")
        XCTAssertEqual(countdown.stringValue, "就绪")
    }

    func testBodyBreakOverlayLongCustomTextStaysWithinReadableLayout() throws {
        let longWord = String(repeating: "ShouldRestNeedsUnbrokenCustomContentToWrap", count: 6)
        var settings = RestSettings.defaults
        settings.contentLibrary.useBuiltInIdeas = false
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(
                id: "long-custom",
                kind: .bodyBreak,
                title: longWord,
                body: "\(longWord) \(longWord)"
            )
        ]

        let view = configuredBodyOverlay(remainingSeconds: 300, settings: settings)
        view.layoutSubtreeIfNeeded()

        let title = try XCTUnwrap(view.descendant(withIdentifier: "overlay.title.label") as? NSTextField)
        let detail = try XCTUnwrap(view.descendant(withIdentifier: "overlay.detail.label") as? NSTextField)
        let countdown = try XCTUnwrap(view.descendant(withIdentifier: "overlay.countdown.label") as? NSTextField)
        let readableWidth = view.bounds.width * 0.7

        XCTAssertEqual(title.lineBreakMode, .byCharWrapping)
        XCTAssertEqual(detail.lineBreakMode, .byCharWrapping)
        XCTAssertEqual(title.maximumNumberOfLines, 3)
        XCTAssertEqual(detail.maximumNumberOfLines, 5)
        XCTAssertLessThanOrEqual(title.frame.width, readableWidth + 1)
        XCTAssertLessThanOrEqual(detail.frame.width, readableWidth + 1)
        XCTAssertTrue(view.bounds.contains(title.frame))
        XCTAssertTrue(view.bounds.contains(detail.frame))
        XCTAssertTrue(view.bounds.contains(countdown.frame))
        XCTAssertFalse(title.frame.intersects(detail.frame))
        XCTAssertFalse(detail.frame.intersects(countdown.frame))
    }

    private func configuredBodyOverlay(
        remainingSeconds: Int,
        settings: RestSettings = .defaults,
        manualAwaiting: Bool = false
    ) -> RestOverlayView {
        let start = Date()
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 300,
            manualFinishEnabled: true
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: remainingSeconds,
            settings: settings,
            showsContent: true,
            manualAwaiting: manualAwaiting,
            emergencyOverrideRemainingSeconds: nil
        )
        return view
    }

    private func configuredEyeGateOverlay(
        settings: RestSettings = .defaults,
        remainingSeconds: Int = 20,
        manualAwaiting: Bool = false,
        manualFinishEnabled: Bool = false
    ) -> RestOverlayView {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: manualFinishEnabled
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: remainingSeconds,
            settings: settings,
            showsContent: true,
            manualAwaiting: manualAwaiting,
            emergencyOverrideRemainingSeconds: 0
        )
        return view
    }
}

private extension NSView {
    func descendant(withIdentifier rawIdentifier: String) -> NSView? {
        if identifier?.rawValue == rawIdentifier {
            return self
        }
        for subview in subviews {
            if let match = subview.descendant(withIdentifier: rawIdentifier) {
                return match
            }
        }
        return nil
    }
}
