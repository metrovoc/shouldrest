import AppKit
import Carbon
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewEmergencyTests: XCTestCase {
    func testOverlayEmergencyActivationIsAvailableWhenAffordanceVisible() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testOverlayKeyboardCommandRequestsEmergencyFromInsideOverlay() {
        let view = configuredEyeGateOverlay()
        var didRequestEmergency = false
        view.onEmergencyOverrideRequested = {
            didRequestEmergency = true
        }

        view.performEmergencyOverrideKeyCommand()
        XCTAssertTrue(didRequestEmergency)
    }

    func testOverlayEmergencyButtonClickRequestsExitWithoutExternalConfirmation() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
    }

    func testEscapeKeyTriggersEmergencyInsideOverlay() throws {
        let view = configuredEyeGateOverlay()
        var didRequestEmergency = false
        view.onEmergencyOverrideRequested = {
            didRequestEmergency = true
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

        XCTAssertTrue(didRequestEmergency)
    }

    func testSpaceKeyDoesNotTriggerEmergencyInsideOverlay() throws {
        let view = configuredEyeGateOverlay()
        var didRequestEmergency = false
        view.onEmergencyOverrideRequested = {
            didRequestEmergency = true
        }

        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: UInt16(kVK_Space)
        ))
        view.keyDown(with: event)

        XCTAssertFalse(didRequestEmergency)
    }

    func testOverlayWindowRoutesEscapeToOverlayEmergencyAction() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let session = eyeGateSession()
        let window = OverlayWindow(screen: screen, session: session, settings: .defaults)
        defer { window.close() }
        var didRequestEmergency = false
        window.overlayView.onEmergencyOverrideRequested = {
            didRequestEmergency = true
        }
        window.overlayView.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0
        )

        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: UInt16(kVK_Escape)
        ))
        window.keyDown(with: event)

        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(didRequestEmergency)
    }

    func testOverlayWindowKeepsOverlayViewInWindowLocalCoordinates() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let window = OverlayWindow(screen: screen, session: eyeGateSession(), settings: .defaults)
        defer { window.close() }

        XCTAssertEqual(window.overlayView.frame.origin.x, 0)
        XCTAssertEqual(window.overlayView.frame.origin.y, 0)
        XCTAssertEqual(window.overlayView.frame.width, screen.frame.width)
        XCTAssertEqual(window.overlayView.frame.height, screen.frame.height)

        let resizedFrame = NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 640, height: 480)
        window.setFrame(resizedFrame, display: false)

        XCTAssertEqual(window.overlayView.frame.origin.x, 0)
        XCTAssertEqual(window.overlayView.frame.origin.y, 0)
        XCTAssertEqual(window.overlayView.frame.width, 640)
        XCTAssertEqual(window.overlayView.frame.height, 480)
    }

    func testEmergencyTriggerArmsInsideOverlayInsteadOfExternalConfirmation() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            isArmed: false
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
        }

        view.performEmergencyOverrideKeyCommand()

        XCTAssertEqual(requestCount, 1)

        view.configure(
            session: eyeGateSession(),
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideArmed: true
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        view.performEmergencyOverrideKeyCommand()
        XCTAssertEqual(requestCount, 2)
    }

    func testLegacyPositiveEmergencyRemainingStillAllowsFirstConfirmationClick() {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 2,
            isArmed: false
        )

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testLegacyPositiveEmergencyRemainingStillLooksActionable() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 2,
            isArmed: false
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testEmergencyAffordanceUsesDimRedGhostStyle() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 2)

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
        let view = configuredEyeGateOverlay(remainingSeconds: 0)

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

    func testArmedEmergencyShowsInternalSecondClickConfirmation() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            isArmed: true
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testEmergencyConfirmationStaysInEmergencyAffordance() throws {
        let view = configuredEyeGateOverlay()
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))

        view.layoutSubtreeIfNeeded()
        let idleWidth = panel.frame.width
        XCTAssertFalse(panel.isHidden)
        XCTAssertNil(view.descendant(withIdentifier: "overlay.emergency.hint"))

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(panel.isHidden)
        XCTAssertEqual(panel.frame.width, idleWidth)
        XCTAssertTrue(view.hitTest(NSPoint(x: panel.frame.midX, y: panel.frame.midY)) === view)
    }

    func testEmergencyDoesNotTurnWholeOverlayIntoHiddenConfirmSurface() {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
        view.layoutSubtreeIfNeeded()

        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)
    }

    func testEmergencyClickAreaRoutesToOverlayView() {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 710, y: 38)) === view)
    }

    func testEmergencyBottomRightSafetyAreaRoutesToOverlayView() {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 790, y: 12)) === view)
    }

    func testEmergencyCornerEscapeZoneExtendsBeyondVisibleButton() {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()

        XCTAssertTrue(view.hitTest(NSPoint(x: 460, y: 132)) === view)
    }

    func testOverlayAcceptsFirstMouseForInactiveWindowEmergencyClicks() {
        let view = configuredEyeGateOverlay()

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testEmergencyActivationDoesNotDependOnLegacyConfirmationStepCount() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
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
            emergencyOverrideRemainingSeconds: nil
        )

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .unavailable)
    }

    private func configuredEyeGateOverlay(
        remainingSeconds: Int = 0,
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
