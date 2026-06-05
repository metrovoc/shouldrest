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
            confirmationSteps: 99
        )
        var coordinator = EmergencyOverrideCoordinator()
        let requestTime = start.addingTimeInterval(1)

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .armed
        )
        XCTAssertTrue(coordinator.hasArmedSession(for: session))

        XCTAssertEqual(
            coordinator.request(session: session, policy: policy, now: requestTime),
            .complete
        )
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testOverlayEmergencyFocusIsAvailableWhenAffordanceVisible() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
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
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
    }

    func testFocusingEmergencyAffordanceDoesNotSpendFirstConfirmation() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))

        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testSecondEmergencyClickCompletesWithoutWaitingForTickRefresh() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_500)
        var settings = RestSettings.defaults
        settings.eyeGate.duration = 60
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1
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
            isEmergencyOverrideAvailable: true,
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
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        drainMainQueue()
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        requestTime = start.addingTimeInterval(2)
        button.performClick(nil)

        XCTAssertNil(engine.state.activeSession)
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
    }

    func testSecondEmergencyClickCanDeferEngineCompletionUntilAfterClickEvent() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_650)
        var settings = RestSettings.defaults
        settings.eyeGate.duration = 60
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1
        )
        var engine = RestEngine(settings: settings, now: start)
        guard case .started(let session) = engine.takeNow(.eyeGate, now: start) else {
            return XCTFail("Expected Eye Gate to start")
        }

        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        var coordinator = EmergencyOverrideCoordinator()
        var requestTime = start.addingTimeInterval(1)
        var didRunDeferredCompletion = false
        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: settings,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: settings.eyeGate.emergencyOverride,
                now: requestTime
            )
            if case .complete = decision {
                DispatchQueue.main.async {
                    didRunDeferredCompletion = true
                    _ = engine.emergencyOverride(now: requestTime)
                }
            }
            return decision
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        requestTime = start.addingTimeInterval(2)
        button.performClick(nil)

        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertFalse(didRunDeferredCompletion)
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
        assertHiddenEmergencyButtonIsCleared(button)

        drainMainQueue()

        XCTAssertTrue(didRunDeferredCompletion)
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
    }

    func testOverlayEmergencyButtonNeedsSecondClickBeforeEngineOverrideEvenWithLegacyZeroSteps() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 0
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
            isEmergencyOverrideAvailable: true,
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
                    isEmergencyOverrideAvailable: true,
                    emergencyOverrideArmed: coordinator.isArmed(for: session, now: requestTime)
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
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        drainMainQueue()
        requestTime = start.addingTimeInterval(2)
        button.performClick(nil)

        XCTAssertNil(engine.state.activeSession)
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 1)
    }

    func testEmergencyClickThenEscapeCountsAsTwoExplicitConfirmations() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.performEmergencyOverrideKeyCommand()

        XCTAssertEqual(requestCount, 2)
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
            isEmergencyOverrideAvailable: true
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
            isEmergencyOverrideAvailable: true
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        window.keyDown(with: try escapeKeyEvent(windowNumber: window.windowNumber))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        window.keyDown(with: try escapeKeyEvent(isRepeat: true, windowNumber: window.windowNumber))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
    }

    func testOverlayEmergencyFocusMakesButtonFirstResponderWithoutConfirming() throws {
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
            isEmergencyOverrideAvailable: true
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(window.overlayView.focusEmergencyOverrideAffordanceIfAvailable(), .focused)

        XCTAssertTrue(window.firstResponder === button)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testOverlayRefreshKeepsFocusedEmergencyButtonAsFirstResponder() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let session = eyeGateSession()
        let window = OverlayWindow(screen: screen, session: session, settings: .defaults)
        defer { window.close() }
        window.overlayView.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(window.overlayView.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertTrue(window.firstResponder === button)

        window.overlayView.configure(
            session: session,
            remainingSeconds: 59,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: true
        )
        window.overlayView.ensureOverlayKeyboardFocusIfNeeded()

        XCTAssertTrue(window.firstResponder === button)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testFocusedEmergencyButtonStillRoutesEscapeThroughWindowEventDispatch() throws {
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
            isEmergencyOverrideAvailable: true
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(window.overlayView.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertTrue(window.firstResponder === button)

        window.sendEvent(try escapeKeyEvent(windowNumber: window.windowNumber))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testWindowEventDispatchIgnoresEscapeRepeatBeforeSecondConfirmation() throws {
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
            isEmergencyOverrideAvailable: true
        )
        let button = try XCTUnwrap(window.overlayView.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        window.sendEvent(try escapeKeyEvent(windowNumber: window.windowNumber, timestamp: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        window.sendEvent(try escapeKeyEvent(
            isRepeat: true,
            windowNumber: window.windowNumber,
            timestamp: 1.01
        ))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        window.sendEvent(try escapeKeyEvent(windowNumber: window.windowNumber, timestamp: 2))

        XCTAssertEqual(requestCount, 2)
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
            isArmed: false
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }

        view.performEmergencyOverrideKeyCommand()

        XCTAssertEqual(requestCount, 1)
        drainMainQueue()

        view.configure(
            session: eyeGateSession(),
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: true
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        view.performEmergencyOverrideKeyCommand()
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
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)

        drainMainQueue()
        view.keyDown(with: event)

        XCTAssertEqual(requestCount, 2)
    }

    func testEscapeKeyRepeatDoesNotConfirmEmergency() throws {
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

        XCTAssertEqual(requestCount, 2)
    }

    func testDirectEscapeRepeatCommandDoesNotConfirmEmergency() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.performEmergencyOverrideKeyCommand(event: try escapeKeyEvent(timestamp: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.performEmergencyOverrideKeyCommand(event: try escapeKeyEvent(isRepeat: true, timestamp: 1.01))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.performEmergencyOverrideKeyCommand(event: try escapeKeyEvent(timestamp: 2))

        XCTAssertEqual(requestCount, 2)
    }

    func testAvailableEmergencyAllowsFirstConfirmationClick() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
    }

    func testAvailableEmergencyLooksActionable() throws {
        let view = configuredEyeGateOverlay()

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testEmergencyAffordanceUsesDimRedGhostStyle() throws {
        let view = configuredEyeGateOverlay()

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
        let view = configuredEyeGateOverlay()

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
        let view = configuredEyeGateOverlay()
        view.onEmergencyOverrideRequested = { .armed }
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(panel.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(panel.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(panel.toolTip, L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.toolTip, L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("overlay.emergencyOverride"))

        button.performClick(nil)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(panel.accessibilityLabel(), L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(panel.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideConfirmHelp"))
        XCTAssertEqual(panel.toolTip, L10n.tr("overlay.emergencyOverrideConfirmHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideConfirmHelp"))
        XCTAssertEqual(button.toolTip, L10n.tr("overlay.emergencyOverrideConfirmHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testEmergencyClickWithoutHandlerDoesNotEnterFalseConfirmationState() throws {
        let view = configuredEyeGateOverlay()
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        drainMainQueue()

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
    }

    func testArmedEmergencyReturningArmedKeepsSecondClickConfirmationAvailable() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testUnavailableEmergencyRequestClearsLocalConfirmationState() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .unavailable
        }
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertTrue(panel.isHidden)
        XCTAssertNil(panel.toolTip)
        XCTAssertNil(panel.accessibilityLabel())
        XCTAssertNil(panel.accessibilityHelp())
        XCTAssertTrue(button.isHidden)
        assertHiddenEmergencyButtonIsCleared(button)
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .unavailable)
    }

    func testArmedEmergencyShowsInternalSecondClickConfirmation() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )

        view.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertLessThanOrEqual(button.attributedTitle.size().width + 24, panel.frame.width)
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
    }

    func testArmedEmergencyButtonClickSubmitsExitAndClearsAffordance() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        assertHiddenEmergencyButtonIsCleared(button)
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .unavailable)
    }

    func testArmedEmergencyIgnoresReentrantConfirmationWhileRequestIsInFlight() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            view.performEmergencyOverrideKeyCommand()
            return .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        assertHiddenEmergencyButtonIsCleared(button)
    }

    func testCompleteDecisionClearsEmergencyAffordanceIfOverlayStaysVisible() throws {
        let session = eyeGateSession()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertTrue(panel.isHidden)
        XCTAssertNil(panel.toolTip)
        XCTAssertNil(panel.accessibilityLabel())
        XCTAssertNil(panel.accessibilityHelp())
        assertHiddenEmergencyButtonIsCleared(button)
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .unavailable)

        view.performEmergencyOverrideKeyCommand()

        XCTAssertEqual(requestCount, 1)

        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )

        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
    }

    func testRefreshClearsEmergencyConfirmationWhenCoordinatorNoLongerArmed() throws {
        let session = eyeGateSession()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: true
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.configure(
            session: session,
            remainingSeconds: 54,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
    }

    func testArmedEmergencyButtonClickRequestsCurrentConfirmationOnly() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
    }

    func testSecondEmergencyButtonClickConfirmsWhenClicksAreCloseTogether() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        try performEmergencyClick(on: view)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        drainMainQueue()
        try performEmergencyClick(on: view)

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

        try performEmergencyClick(on: view)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)

        drainMainQueue()
        try performEmergencyClick(on: view)

        XCTAssertEqual(requestCount, 2)
    }

    func testSecondEmergencyButtonClickConfirmsWithoutWaitingForMainQueue() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        try performEmergencyClick(on: view)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        try performEmergencyClick(on: view)

        XCTAssertEqual(requestCount, 2)
    }

    func testSecondDistinctEscapePressConfirmsWithoutWaitingForMainQueue() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.keyDown(with: try escapeKeyEvent(timestamp: 1))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        view.keyDown(with: try escapeKeyEvent(timestamp: 1.01))

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
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertFalse(coordinator.hasArmedSession(for: session))

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

        try performEmergencyClick(on: view)

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertFalse(didComplete)

        drainMainQueue()
        XCTAssertFalse(didComplete)

        try performEmergencyClick(on: view)
        XCTAssertEqual(decisions, [.armed, .complete])

        drainMainQueue()
        XCTAssertEqual(decisions, [.armed, .complete])
        drainMainQueue()
        XCTAssertTrue(didComplete)
    }

    func testRepeatedExternalFocusNeverSpendsEmergencyConfirmations() throws {
        let start = Date(timeIntervalSinceReferenceDate: 4_100)
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
        let policy = EmergencyOverridePolicy(isEnabled: true, confirmationSteps: 1)
        var coordinator = EmergencyOverrideCoordinator()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        view.layoutSubtreeIfNeeded()

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        for _ in 0..<3 {
            XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
            XCTAssertFalse(coordinator.hasArmedSession(for: session))
            XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        }

        var decisions: [EmergencyOverrideDecision] = []
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: policy,
                now: start.addingTimeInterval(TimeInterval(decisions.count + 1))
            )
            decisions.append(decision)
            return decision
        }

        try performEmergencyClick(on: view)

        XCTAssertEqual(decisions, [.armed])
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertEqual(decisions, [.armed])
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        try performEmergencyClick(on: view)

        XCTAssertEqual(decisions, [.armed, .complete])
        XCTAssertFalse(coordinator.hasArmedSession(for: session))
    }

    func testOverlayControllerUpdateCreatesFocusableEmergencyAffordanceForBlockedAction() {
        let session = eyeGateSession()
        let controller = OverlayController()
        defer { controller.dismiss() }
        var requestCount = 0

        controller.update(
            session: session,
            settings: .defaults,
            now: session.startedAt.addingTimeInterval(1),
            manualAwaiting: false,
            emergencyOverrideAction: {
                requestCount += 1
                return .armed
            },
            emergencyOverrideArmed: false
        )

        XCTAssertEqual(controller.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        XCTAssertEqual(requestCount, 0)
    }

    func testRefreshKeepsEmergencyConfirmationWhenCoordinatorStillArmed() throws {
        let session = eyeGateSession()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        drainMainQueue()
        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: true
        )

        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        button.performClick(nil)

        XCTAssertEqual(requestCount, 2)
    }

    func testArmedEmergencyButtonClickRequestsConfirmationAction() throws {
        let view = configuredEyeGateOverlay(
            isArmed: true
        )
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        XCTAssertEqual(requestCount, 1)
    }

    func testSingleEmergencyButtonClickOnlyArmsAndNeverCompletesAsHold() throws {
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

        drainMainQueue()
        XCTAssertEqual(requestCount, 1)
    }

    func testFirstEmergencyClickDoesNotConfirmOnItsOwnAfterRunLoop() throws {
        let view = configuredEyeGateOverlay()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertTrue(button.isEnabled)
    }

    func testEmergencyPanelBackgroundUsesSameTwoStepConfirmation() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let panelOnlyPoint = NSPoint(x: panel.frame.minX + 4, y: panel.frame.midY)

        XCTAssertTrue(view.hitTest(panelOnlyPoint) === panel)

        try performRoutedMouseClick(on: view, at: panelOnlyPoint)
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertTrue(button.isEnabled)

        try performRoutedMouseClick(on: view, at: panelOnlyPoint)
        drainMainQueue()

        XCTAssertEqual(requestCount, 2)
    }

    func testEmergencyMouseHoldDoesNotConfirmUntilSecondDistinctClick() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return requestCount == 1 ? .armed : .complete
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let panelOnlyPoint = NSPoint(x: panel.frame.minX + 4, y: panel.frame.midY)
        let target = try XCTUnwrap(view.hitTest(panelOnlyPoint))

        target.mouseDown(with: try mouseEvent(at: panelOnlyPoint, clickCount: 1))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        target.mouseUp(with: try mouseUpEvent(at: panelOnlyPoint, clickCount: 1))
        drainMainQueue()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))

        try performRoutedMouseClick(on: view, at: panelOnlyPoint)

        XCTAssertEqual(requestCount, 2)
    }

    func testSingleEmergencyClickWithLegacyHoldOnlyArmsAndNeverCompletes() throws {
        let start = Date(timeIntervalSinceReferenceDate: 7_000)
        var settings = RestSettings.defaults
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1
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
            isEmergencyOverrideAvailable: true,
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

        try performEmergencyClick(on: view)
        drainMainQueue()

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertEqual(decisions, [.armed])
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        drainMainQueue()
        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
    }

    func testWaitingAfterSingleEmergencyClickKeepsArmedStateWithoutCompletingAsHold() throws {
        let start = Date(timeIntervalSinceReferenceDate: 7_100)
        var settings = RestSettings.defaults
        settings.eyeGate.duration = 60
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1
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
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        var decisions: [EmergencyOverrideDecision] = []
        view.onEmergencyOverrideRequested = {
            let decision = coordinator.request(
                session: session,
                policy: settings.eyeGate.emergencyOverride,
                now: requestTime
            )
            decisions.append(decision)
            if case .complete = decision {
                _ = engine.emergencyOverride(now: requestTime)
            }
            return decision
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)

        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        requestTime = start.addingTimeInterval(20)
        drainMainQueue()

        XCTAssertTrue(coordinator.isArmed(for: session, now: requestTime))
        XCTAssertEqual(decisions, [.armed])
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)
        XCTAssertEqual(engine.state.statistics.skippedEyeGates, 0)
    }

    func testArmedEmergencyConfirmationSurvivesRefreshUntilSecondClick() throws {
        let start = Date(timeIntervalSinceReferenceDate: 7_200)
        var settings = RestSettings.defaults
        settings.eyeGate.duration = 60
        settings.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: true,
            confirmationSteps: 1
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
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: false
        )
        view.layoutSubtreeIfNeeded()
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

        try performEmergencyClick(on: view)
        drainMainQueue()

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        XCTAssertTrue(coordinator.hasArmedSession(for: session))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(engine.state.activeSession?.id, session.id)

        requestTime = start.addingTimeInterval(31)
        view.configure(
            session: session,
            remainingSeconds: 29,
            settings: settings,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true,
            emergencyOverrideArmed: coordinator.isArmed(for: session, now: requestTime)
        )
        drainMainQueue()

        XCTAssertTrue(coordinator.isArmed(for: session, now: requestTime))
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
        XCTAssertEqual(engine.state.activeSession?.id, session.id)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 0)

        try performEmergencyClick(on: view)

        XCTAssertFalse(coordinator.hasArmedSession(for: session))
        XCTAssertNil(engine.state.activeSession)
        XCTAssertEqual(engine.state.statistics.emergencyOverrides, 1)
    }

    func testEmergencyConfirmationStaysInEmergencyAffordance() throws {
        let view = configuredEyeGateOverlay()
        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.panel"))
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        view.layoutSubtreeIfNeeded()
        let idleWidth = panel.frame.width
        XCTAssertFalse(panel.isHidden)
        XCTAssertNil(view.descendant(withIdentifier: "overlay.emergency.hint"))

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(panel.isHidden)
        XCTAssertEqual(panel.frame.width, idleWidth)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testEmergencyDoesNotTurnWholeOverlayIntoHiddenConfirmSurface() {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
        view.layoutSubtreeIfNeeded()

        XCTAssertFalse(view.hitTest(NSPoint(x: 400, y: 300)) === view)
    }

    func testEmergencyButtonHitTestRoutesToButton() throws {
        let view = configuredEyeGateOverlay()

        view.layoutSubtreeIfNeeded()
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let point = NSPoint(x: button.frame.midX, y: button.frame.midY)

        XCTAssertTrue(view.hitTest(point) === button)
    }

    func testInvisibleBottomRightAreaDoesNotRouteToEmergency() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let hiddenCornerPoint = NSPoint(x: 798, y: 2)

        try performRoutedMouseClick(on: view, at: hiddenCornerPoint)

        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testInvisibleCornerEscapeZoneDoesNotRouteToEmergency() throws {
        let view = configuredEyeGateOverlay()
        view.layoutSubtreeIfNeeded()
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let hiddenEscapeZonePoint = NSPoint(x: 460, y: 132)

        try performRoutedMouseClick(on: view, at: hiddenEscapeZonePoint)

        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
    }

    func testOverlayAcceptsFirstMouseForInactiveWindowEmergencyClicks() {
        let view = configuredEyeGateOverlay()

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testEmergencyClickDoesNotDependOnFirstResponderAssignment() throws {
        let view = configuredEyeGateOverlay()
        view.emergencyFocusAttemptForTesting = { .unavailable }
        var requestCount = 0
        view.onEmergencyOverrideRequested = {
            requestCount += 1
            return .armed
        }

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)

        button.performClick(nil)

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverrideConfirm"))
    }

    func testEmergencyFocusDoesNotDependOnLegacyConfirmationStepCount() {
        let view = configuredEyeGateOverlay()

        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .focused)
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
            isEmergencyOverrideAvailable: false
        )

        let button = view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton
        XCTAssertNotNil(button)
        if let button {
            assertHiddenEmergencyButtonIsCleared(button)
        }
        XCTAssertEqual(view.focusEmergencyOverrideAffordanceIfAvailable(), .unavailable)
    }

    func testHiddenEmergencyAffordanceRestoresPresentationWhenAvailableAgain() throws {
        let session = eyeGateSession()
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: false
        )

        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        assertHiddenEmergencyButtonIsCleared(button)

        view.configure(
            session: session,
            remainingSeconds: 59,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: false,
            isEmergencyOverrideAvailable: true
        )

        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.attributedTitle.string, L10n.tr("overlay.emergencyOverride"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.toolTip, L10n.tr("overlay.emergencyOverrideHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("overlay.emergencyOverride"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("overlay.emergencyOverrideHelp"))
    }

    private func configuredEyeGateOverlay(
        isEmergencyOverrideAvailable: Bool = true,
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
            isEmergencyOverrideAvailable: isEmergencyOverrideAvailable,
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

    private func assertHiddenEmergencyButtonIsCleared(
        _ button: NSButton,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(button.isHidden, file: file, line: line)
        XCTAssertEqual(button.title, "", file: file, line: line)
        XCTAssertEqual(button.attributedTitle.string, "", file: file, line: line)
        XCTAssertNil(button.image, file: file, line: line)
        XCTAssertNil(button.toolTip, file: file, line: line)
        XCTAssertNil(button.accessibilityLabel(), file: file, line: line)
        XCTAssertNil(button.accessibilityHelp(), file: file, line: line)
    }

    private func performEmergencyClick(on view: RestOverlayView) throws {
        let button = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        button.performClick(nil)
    }

    private func performRoutedMouseClick(on view: NSView, at point: NSPoint) throws {
        let target = try XCTUnwrap(view.hitTest(point))
        target.mouseDown(with: try mouseEvent(at: point, clickCount: 1))
        target.mouseUp(with: try mouseUpEvent(at: point, clickCount: 1))
    }

    private func mouseEvent(
        at point: NSPoint,
        clickCount: Int,
        timestamp: TimeInterval = 0,
        eventNumber: Int = 0
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            eventNumber: eventNumber,
            clickCount: clickCount,
            pressure: 1
        ))
    }

    private func mouseUpEvent(
        at point: NSPoint,
        clickCount: Int,
        timestamp: TimeInterval = 0,
        eventNumber: Int = 0
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: point,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            eventNumber: eventNumber,
            clickCount: clickCount,
            pressure: 0
        ))
    }

    private func escapeKeyEvent(
        isRepeat: Bool = false,
        windowNumber: Int = 0,
        timestamp: TimeInterval = 0
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: timestamp,
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
