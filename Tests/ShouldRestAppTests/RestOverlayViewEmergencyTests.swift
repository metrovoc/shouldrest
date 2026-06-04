import AppKit
import Carbon
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewEmergencyTests: XCTestCase {
    func testEmergencyCoordinatorRequiresTwoRequestsWithoutLegacyHoldWait() {
        let start = Date(timeIntervalSinceReferenceDate: 6_000)
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let policy = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 99,
            minimumHoldDuration: 30
        )
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(1)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.isArmed(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .complete
        )
        XCTAssertFalse(coordinator.isArmed(for: session))
    }

    func testOverlayEmergencyActivationIsAvailableWhenAffordanceVisible() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testOverlayKeyboardCommandRequestsEmergencyFromInsideOverlay() {
        let view = configuredEyeGateOverlay()
        var didRequestEmergency = false
        view.onEmergencyOverrideRequested = {
            didRequestEmergency = true
            return .armed
        }

        view.performEmergencyOverrideKeyCommand()
        XCTAssertTrue(didRequestEmergency)
    }

    func testOverlayEmergencyButtonClickRequestsInternalEmergencyStateMachine() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
    }

    func testFirstEmergencyClickImmediatelyShowsSecondClickConfirmationWithoutExternalRefresh() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testSecondEmergencyClickCompletesWithoutWaitingForTickRefresh() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_500)
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1,
            minimumHoldDuration: 30
        )
        var engine = RestEngine(settings: settings, now: start)
        guard case .started(let session) = engine.takeNow(.eyeGate, now: start) else {
            return XCTFail("Expected Eye Gate to start")
        }

        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        var coordinator = EmergencyOverrideCoordinator()
        var requestTime = start.addingTimeInterval(1)
        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: settings,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideArmed: false
        )
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: settings.eyeGate.emergencyOverride,
                now: requestTime
            )
            if case .complete = decision {
                _ = engine.emergencyOverride(now: requestTime)
            }
            return decision
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        drainMainQueue()
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        requestTime = start.addingTimeInterval(2)
        button.performClick(nil)
        drainMainQueue()

        XCTAssertNil(engine.state.activeSession)
        XCTAssertFalse(coordinator.isArmed(for: session))
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
    }

    func testOverlayEmergencyButtonNeedsSecondClickBeforeEngineOverrideEvenWithLegacyZeroSteps() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 0,
            minimumHoldDuration: 30
        )
        var engine = RestEngine(settings: settings, now: start)
        guard case .started(let session) = engine.takeNow(.eyeGate, now: start) else {
            return XCTFail("Expected Eye Gate to start")
        }

        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        var coordinator = EmergencyOverrideCoordinator()
        var requestTime = start.addingTimeInterval(1)
        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: settings,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideArmed: false
        )
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: settings.eyeGate.emergencyOverride,
                now: requestTime
            )
            switch decision {
            case .armed:
                view.configure(
                    session: session,
                    remainingSeconds: 58,
                    settings: settings,
                    showsContent: true,
                    manualAwaiting: false,
                    emergencyOverrideRemainingSeconds: 0,
                    emergencyOverrideArmed: coordinator.isArmed(for: session)
                )
            case .complete:
                _ = engine.emergencyOverride(now: requestTime)
            case .unavailable:
                break
            }
            return decision
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        requestTime = start.addingTimeInterval(2)
        button.performClick(nil)
        drainMainQueue()

        XCTAssertNil(engine.state.activeSession)
        XCTAssertFalse(coordinator.isArmed(for: session))
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 1)
    }

    func testEscapeKeyTriggersEmergencyInsideOverlay() throws {
        let view = configuredEyeGateOverlay()
        var didRequestEmergency = false
        view.onEmergencyOverrideRequested = {
            didRequestEmergency = true
            return .armed
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
            return .armed
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
            return .armed
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

    func testOverlayWindowConsumesEscapeRepeatWithoutConfirmingEmergency() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let session = eyeGateSession()
        let window = OverlayWindow(screen: screen, session: session, settings: .defaults)
        defer { window.close() }
        var requestCount = 0
        window.overlayView.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        window.overlayView.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        window.keyDown(with: try escapeKeyEvent(windowNumber: window.windowNumber))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        window.keyDown(with: try escapeKeyEvent(isRepeat: true, windowNumber: window.windowNumber))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
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
            return requestCount == 1 ? .armed : .complete
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
        drainMainQueue()
        XCTAssertEqual(requestCount, 2)
    }

    func testTwoEscapeKeyPressesConfirmWithoutHoldOrExternalWindow() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
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

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)

        view.keyDown(with: event)

        drainMainQueue()
        XCTAssertEqual(requestCount, 2)
    }

    func testHoldingEscapeDoesNotConfirmEmergencyThroughKeyRepeat() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.keyDown(with: try escapeKeyEvent())

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.keyDown(with: try escapeKeyEvent(isRepeat: true))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)

        view.keyDown(with: try escapeKeyEvent())
        drainMainQueue()

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

    func testEmergencyAffordanceAccessibilityTracksConfirmationState() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 0)
        view.onEmergencyOverrideRequested = { .armed }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("overlay.emergencyOverride"))

        button.performClick(nil)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testEmergencyClickWithoutHandlerDoesNotEnterFalseConfirmationState() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 0)
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        drainMainQueue()

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
    }

    func testUnavailableEmergencyRequestClearsLocalConfirmationState() throws {
        let view = configuredEyeGateOverlay(remainingSeconds: 0)
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .unavailable
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertTrue(button.isHidden)
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .unavailable)
    }

    func testArmedEmergencyShowsInternalSecondClickConfirmation() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            isArmed: true
        )

        view.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertLessThanOrEqual(button.attributedTitle.size().width + 24, panel.frame.width)
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
    }

    func testArmedEmergencyButtonClickRequestsExitAfterEventReturns() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 0)
        drainMainQueue()
        XCTAssertEqual(requestCount, 1)
    }

    func testArmedEmergencyButtonClickIgnoresLegacyHoldRemaining() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 5,
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 0)
        drainMainQueue()
        XCTAssertEqual(requestCount, 1)
    }

    func testSecondEmergencyMouseEventConfirmsEvenWhenSystemMarksItAsDoubleClick() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 2))

        XCTAssertEqual(requestCount, 1)
        drainMainQueue()
        XCTAssertEqual(requestCount, 2)
    }

    func testTwoSeparateEmergencyMouseClicksConfirmWithoutHoldOrTick() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        XCTAssertEqual(requestCount, 1)
        drainMainQueue()
        XCTAssertEqual(requestCount, 2)
    }

    func testExternalFocusDoesNotCountAsFirstOverlayConfirmation() throws {
        let start = Date(timeIntervalSinceReferenceDate: 4_000)
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1, minimumHoldDuration: 30)
        var coordinator = EmergencyOverrideCoordinator()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideArmed: false
        )
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)
        XCTAssertFalse(coordinator.isArmed(for: session))

        var decisions: [EmergencyOverrideDecision] = []
        var didComplete = false
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: policy,
                now: start.addingTimeInterval(2)
            )
            decisions.append(decision)
            if case .complete = decision {
                DispatchQueue.main.async {
                    didComplete = true
                }
            }
            return decision
        }

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertFalse(didComplete)

        drainMainQueue()
        XCTAssertFalse(didComplete)

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))
        XCTAssertEqual(decisions, [.armed])

        drainMainQueue()
        XCTAssertEqual(decisions, [.armed, .complete])
        drainMainQueue()
        XCTAssertTrue(didComplete)
    }

    func testArmedEmergencyMouseClickDefersConfirmationUntilMouseEventReturns() throws {
        let view = configuredEyeGateOverlay(
            remainingSeconds: 0,
            isArmed: true
        )
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        XCTAssertEqual(requestCount, 0)
        drainMainQueue()
        XCTAssertEqual(requestCount, 1)
    }

    func testSingleEmergencyMouseDownOnlyArmsAndNeverCompletesAsHold() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.activateEmergencyOverrideIfAvailable(), .activated)

        drainMainQueue()
        XCTAssertEqual(requestCount, 1)
    }

    func testSingleEmergencyMouseDownWithLegacyHoldOnlyArmsAndNeverCompletes() throws {
        let start = Date(timeIntervalSinceReferenceDate: 7_000)
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1,
            minimumHoldDuration: 30
        )
        var engine = RestEngine(settings: settings, now: start)
        guard case .started(let session) = engine.takeNow(.eyeGate, now: start) else {
            return XCTFail("Expected Eye Gate to start")
        }

        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        var coordinator = EmergencyOverrideCoordinator()
        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: settings,
            showsContent: true,
            manualAwaiting: false,
            emergencyOverrideRemainingSeconds: 0,
            emergencyOverrideArmed: false
        )
        view.layoutSubtreeIfNeeded()
        var decisions: [EmergencyOverrideDecision] = []
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: settings.eyeGate.emergencyOverride,
                now: start.addingTimeInterval(1)
            )
            decisions.append(decision)
            if case .complete = decision {
                _ = engine.emergencyOverride(now: start.addingTimeInterval(1))
            }
            return decision
        }

        view.mouseDown(with: try mouseEvent(at: NSPoint(x: 790, y: 12), clickCount: 1))
        drainMainQueue()

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(decisions, [.armed])
        XCTAssertTrue(coordinator.isArmed(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        drainMainQueue()
        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
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

    private func drainMainQueue(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "drain main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        let result = XCTWaiter().wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    private func mouseEvent(at point: NSPoint, clickCount: Int) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: 1
        ))
    }

    private func escapeKeyEvent(isRepeat: Bool = false, windowNumber: Int = 0) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: isRepeat,
            keyCode: UInt16(kVK_Escape)
        ))
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
