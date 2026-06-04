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

    private func configuredBodyOverlay(
        remainingSeconds: Int,
        settings: RestSettings = .defaults
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
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: nil
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
