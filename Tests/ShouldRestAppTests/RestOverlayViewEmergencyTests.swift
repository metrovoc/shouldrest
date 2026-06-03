import AppKit
import Carbon
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewEmergencyTests: XCTestCase {
    func testOverlayEmergencyCompletesOnFirstTriggerEvenWithLegacyConfirmationSteps() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated(legacyConfirmationSteps: 2))
    }

    func testOverlayKeyboardCommandCompletesEmergencyOnFirstTrigger() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)
        var confirmedSteps: Int?
        view.onEmergencyOverrideConfirmed = { steps in
            confirmedSteps = steps
        }

        view.performEmergencyOverrideKeyCommand()
        XCTAssertEqual(confirmedSteps, 2)
    }

    func testEscapeKeyTriggersEmergencyInsideOverlay() throws {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)
        var confirmedSteps: Int?
        view.onEmergencyOverrideConfirmed = { steps in
            confirmedSteps = steps
        }

        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: UInt16(kVK_Escape)
        ))
        view.keyDown(with: event)

        XCTAssertEqual(confirmedSteps, 2)
    }

    func testEarlyEmergencyTriggerArmsInsideOverlayInsteadOfExternalConfirmation() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 2,
            confirmationSteps: 2,
            isArmed: false
        )
        var requestedSteps: Int?
        view.onEmergencyOverrideConfirmed = { steps in
            requestedSteps = steps
        }

        view.performEmergencyOverrideKeyCommand()

        XCTAssertEqual(requestedSteps, 0)

        view.configure(
            session: eyeGateSession(),
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 2,
            emergencyOverrideConfirmationSteps: 2,
            emergencyOverrideArmed: true
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.format("overlay.emergencyOverrideArmed", 2))
    }

    func testEmergencyAffordanceUsesDimRedGhostStyle() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 2, confirmationSteps: 2)

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let tint = try XCTUnwrap(button.contentTintColor?.usingColorSpace(.sRGB))
        let titleColor = try XCTUnwrap(
            button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        ).usingColorSpace(.sRGB)
        let title = try XCTUnwrap(titleColor)

        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(button.attributedTitle.string.contains("Esc"))
        XCTAssertLessThanOrEqual(button.alphaValue, 0.40)
        XCTAssertGreaterThan(tint.redComponent, 0.80)
        XCTAssertLessThan(tint.greenComponent, 0.35)
        XCTAssertLessThanOrEqual(tint.alphaComponent, 0.50)
        XCTAssertGreaterThan(title.redComponent, 0.80)
        XCTAssertLessThan(title.greenComponent, 0.35)
        XCTAssertLessThanOrEqual(title.alphaComponent, 0.50)
        XCTAssertLessThanOrEqual(panel.layer?.backgroundColor?.alpha ?? 1, 0.02)
        XCTAssertLessThanOrEqual(panel.layer?.borderColor?.alpha ?? 1, 0.06)
    }

    func testEmergencyAffordanceRemainsDimWhenReady() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 0, confirmationSteps: 2)

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let tint = try XCTUnwrap(button.contentTintColor?.usingColorSpace(.sRGB))

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertTrue(button.attributedTitle.string.contains("Esc"))
        XCTAssertLessThanOrEqual(button.alphaValue, 0.50)
        XCTAssertLessThanOrEqual(tint.alphaComponent, 0.66)
        XCTAssertLessThanOrEqual(panel.layer?.backgroundColor?.alpha ?? 1, 0.03)
        XCTAssertLessThanOrEqual(panel.layer?.borderColor?.alpha ?? 1, 0.09)
    }

    func testEmergencyTriggerDoesNotEnterClickConfirmationState() throws {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))

        view.layoutSubtreeIfNeeded()
        let idleWidth = panel.frame.width
        XCTAssertFalse(panel.isHidden)
        XCTAssertNil(view.descendant(withIdentifier: "overlay.emergency.hint"))

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated(legacyConfirmationSteps: 2))

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(panel.isHidden)
        XCTAssertEqual(panel.frame.width, idleWidth)
        XCTAssertTrue(view.hitTest(NSPoint(x: panel.frame.midX, y: panel.frame.midY)) === view)
    }

    func testEmergencyDoesNotTurnWholeOverlayIntoHiddenConfirmSurface() {
        let view = configuredEyeGateOverlay(confirmationSteps: 2)

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated(legacyConfirmationSteps: 2))
        view.layoutSubtreeIfNeeded()

        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)
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

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated(legacyConfirmationSteps: 1))
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

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .unavailable)
    }

    private func configuredEyeGateOverlay(
        remainingSeconds: Int = 0,
        confirmationSteps: Int,
        isArmed: Bool = false
    ) -> RestOverlayView {
        let session = eyeGateSession()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: remainingSeconds,
            emergencyOverrideConfirmationSteps: confirmationSteps,
            emergencyOverrideArmed: isArmed
        )
        return view
    }

    private func eyeGateSession() -> RestSession {
        let start = Date()
        return RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
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
