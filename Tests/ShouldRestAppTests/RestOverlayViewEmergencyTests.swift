import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewEmergencyTests: XCTestCase {
    func testOverlayEmergencyConfirmationAdvancesWithoutAlertFallback() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .waitingForConfirmation)
        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .confirmed(2))
    }

    func testOverlayKeyboardCommandUsesEmergencyConfirmationStateMachine() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)
        var confirmedSteps: Int?
        view.onEmergencyOverrideConfirmed = { steps in
            confirmedSteps = steps
        }

        view.performEmergencyOverrideKeyCommand()
        XCTAssertNil(confirmedSteps)

        view.performEmergencyOverrideKeyCommand()
        XCTAssertEqual(confirmedSteps, 2)
    }

    func testEmergencyConfirmationExpandsOverlayLocalPanel() throws {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let hint = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.hint"))

        view.layoutSubtreeIfNeeded()
        let idleWidth = panel.frame.width
        XCTAssertFalse(panel.isHidden)
        XCTAssertTrue(hint.isHidden)

        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .waitingForConfirmation)

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(panel.isHidden)
        XCTAssertFalse(hint.isHidden)
        XCTAssertGreaterThan(panel.frame.width, idleWidth)
        XCTAssertTrue(view.hitTest(NSPoint(x: panel.frame.midX, y: panel.frame.midY)) === view)
    }

    func testEmergencyConfirmationTurnsWholeOverlayIntoConfirmSurface() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)

        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .waitingForConfirmation)
        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 400, y: 300)) === view)
    }

    func testEmergencyClickAreaRoutesToOverlayView() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 710, y: 38)) === view)
    }

    func testEmergencyBottomRightSafetyAreaRoutesToOverlayView() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 790, y: 12)) === view)
    }

    func testOverlayAcceptsFirstMouseForInactiveWindowEmergencyClicks() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testSingleStepEmergencyConfirmationCompletesOnFirstTrigger() {
        let view = configuredEyeGateOverlay(confirmationSteps: 1)

        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .confirmed(1))
    }

    func testOverlayEmergencyConfirmationIsUnavailableWhenButtonIsHidden() {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: nil,
            emergencyOverrideConfirmationSteps: 0
        )

        XCTAssertEqual(view.advanceEmergencyOverrideConfirmationIfAvailable(), .unavailable)
    }

    private func configuredEyeGateOverlay(confirmationSteps: Int) -> RestOverlayView {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideConfirmationSteps: confirmationSteps
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
