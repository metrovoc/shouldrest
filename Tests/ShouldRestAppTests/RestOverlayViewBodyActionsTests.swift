import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewBodyActionsTests: XCTestCase {
    func testAvailableBodyOverlayActionsRunAfterEventReturns() {
        assertBodyActionDefersUntilNextMainQueueTurn(
            action: .postpone,
            expectedInvocation: "postpone"
        )
        assertBodyActionDefersUntilNextMainQueueTurn(
            action: .skip,
            expectedInvocation: "skip"
        )
        assertBodyActionDefersUntilNextMainQueueTurn(
            action: .finish,
            expectedInvocation: "finish"
        )
    }

    func testPendingBodyOverlayActionDisablesButtonsAndPreventsSecondQueuedAction() throws {
        var invokedActions: [String] = []
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: true,
                canFinish: false,
                canSkip: true,
                postpone: { invokedActions.append("postpone") },
                finish: nil,
                skip: { invokedActions.append("skip") }
            )
        )
        let postponeButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyPostpone.button") as? NSButton)
        let skipButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodySkip.button") as? NSButton)

        view.performBodyPostponeAction()

        XCTAssertFalse(postponeButton.isEnabled)
        XCTAssertFalse(skipButton.isEnabled)
        XCTAssertEqual(postponeButton.attributedTitle.string, L10n.tr("overlay.bodyPostponePending"))
        XCTAssertEqual(postponeButton.image?.accessibilityDescription, L10n.tr("overlay.bodyPostponePending"))
        XCTAssertEqual(postponeButton.toolTip, L10n.tr("overlay.bodyPostponePendingHelp"))
        XCTAssertEqual(postponeButton.accessibilityHelp(), L10n.tr("overlay.bodyPostponePendingHelp"))
        XCTAssertEqual(skipButton.attributedTitle.string, L10n.tr("overlay.bodySkip"))
        XCTAssertEqual(skipButton.toolTip, L10n.tr("overlay.bodyActionPendingHelp"))
        XCTAssertEqual(skipButton.accessibilityHelp(), L10n.tr("overlay.bodyActionPendingHelp"))
        view.performBodySkipAction()
        XCTAssertTrue(invokedActions.isEmpty)
        drainMainQueue()
        XCTAssertEqual(invokedActions, ["postpone"])
    }

    func testBodyOverlayActionRestoresButtonsWhenHandlerLeavesOverlayVisible() throws {
        var invokedActions: [String] = []
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: true,
                canFinish: false,
                canSkip: true,
                postpone: { invokedActions.append("postpone") },
                finish: nil,
                skip: { invokedActions.append("skip") }
            )
        )
        let postponeButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyPostpone.button") as? NSButton)
        let skipButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodySkip.button") as? NSButton)

        view.performBodyPostponeAction()

        XCTAssertFalse(postponeButton.isEnabled)
        XCTAssertFalse(skipButton.isEnabled)
        drainMainQueue()

        XCTAssertEqual(invokedActions, ["postpone"])
        XCTAssertTrue(postponeButton.isEnabled)
        XCTAssertTrue(skipButton.isEnabled)
        XCTAssertEqual(postponeButton.attributedTitle.string, L10n.tr("overlay.bodyPostpone"))
        XCTAssertEqual(postponeButton.toolTip, L10n.tr("overlay.bodyPostponeHelp"))
        XCTAssertEqual(skipButton.toolTip, L10n.tr("overlay.bodySkipHelp"))

        view.performBodySkipAction()
        drainMainQueue()

        XCTAssertEqual(invokedActions, ["postpone", "skip"])
    }

    func testEachPendingBodyOverlayActionShowsSpecificProgressFeedback() throws {
        try assertPendingBodyActionFeedback(
            action: .postpone,
            expectedPendingTitle: L10n.tr("overlay.bodyPostponePending"),
            expectedPendingHelp: L10n.tr("overlay.bodyPostponePendingHelp"),
            expectedLockedButtonIdentifier: "overlay.bodySkip.button"
        )
        try assertPendingBodyActionFeedback(
            action: .skip,
            expectedPendingTitle: L10n.tr("overlay.bodySkipPending"),
            expectedPendingHelp: L10n.tr("overlay.bodySkipPendingHelp"),
            expectedLockedButtonIdentifier: "overlay.bodyPostpone.button"
        )
        try assertPendingBodyActionFeedback(
            action: .finish,
            expectedPendingTitle: L10n.tr("overlay.bodyFinishPending"),
            expectedPendingHelp: L10n.tr("overlay.bodyFinishPendingHelp"),
            expectedLockedButtonIdentifier: nil
        )
    }

    func testAvailableBodyOverlayActionsUseStableActionRailAffordances() throws {
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: true,
                canFinish: true,
                canSkip: true,
                postpone: nil,
                finish: nil,
                skip: nil
            )
        )

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyActions.panel"))
        let postponeButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyPostpone.button") as? NSButton)
        let skipButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodySkip.button") as? NSButton)
        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)

        XCTAssertFalse(panel.isHidden)
        XCTAssertGreaterThan(panel.layer?.backgroundColor?.alpha ?? 0, 0)
        XCTAssertGreaterThan(panel.layer?.borderColor?.alpha ?? 0, 0)
        assertBodyActionButton(
            postponeButton,
            title: L10n.tr("overlay.bodyPostpone"),
            toolTip: L10n.tr("overlay.bodyPostponeHelp")
        )
        assertBodyActionButton(
            skipButton,
            title: L10n.tr("overlay.bodySkip"),
            toolTip: L10n.tr("overlay.bodySkipHelp")
        )
        assertBodyActionButton(
            finishButton,
            title: L10n.tr("overlay.bodyFinish"),
            toolTip: L10n.tr("overlay.bodyFinishHelp")
        )
    }

    func testPartiallyUnavailableBodyOverlayActionsClearHiddenButtons() throws {
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: false,
                canSkip: true,
                postpone: nil,
                finish: nil,
                skip: nil
            )
        )

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyActions.panel"))
        let postponeButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyPostpone.button") as? NSButton)
        let skipButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodySkip.button") as? NSButton)
        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)

        XCTAssertFalse(panel.isHidden)
        assertHiddenBodyActionButtonIsCleared(postponeButton)
        assertBodyActionButton(
            skipButton,
            title: L10n.tr("overlay.bodySkip"),
            toolTip: L10n.tr("overlay.bodySkipHelp")
        )
        assertHiddenBodyActionButtonIsCleared(finishButton)
    }

    func testUnavailableBodyOverlayActionsDoNotInvokeCallbacks() throws {
        var invokedActions: [String] = []
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: false,
                canSkip: false,
                postpone: { invokedActions.append("postpone") },
                finish: { invokedActions.append("finish") },
                skip: { invokedActions.append("skip") }
            )
        )

        view.performBodyPostponeAction()
        view.performBodyFinishAction()
        view.performBodySkipAction()

        let panel = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyActions.panel"))
        let postponeButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyPostpone.button") as? NSButton)
        let skipButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodySkip.button") as? NSButton)
        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)
        XCTAssertTrue(panel.isHidden)
        assertHiddenBodyActionButtonIsCleared(postponeButton)
        assertHiddenBodyActionButtonIsCleared(skipButton)
        assertHiddenBodyActionButtonIsCleared(finishButton)
        XCTAssertTrue(invokedActions.isEmpty)
    }

    func testManualAwaitingBodyOverlayCanFinishInsideOverlay() {
        var didFinish = false
        let view = configuredBodyOverlay(
            manualAwaiting: true,
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: true,
                canSkip: false,
                postpone: nil,
                finish: { didFinish = true },
                skip: nil
            )
        )

        view.performBodyFinishAction()

        XCTAssertFalse(didFinish)
        drainMainQueue()
        XCTAssertTrue(didFinish)
    }

    func testManualAwaitingEyeGateOverlayCanFinishInsideOverlay() throws {
        var didFinish = false
        let view = configuredEyeGateOverlay(
            manualAwaiting: true,
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: true,
                canSkip: false,
                postpone: nil,
                finish: { didFinish = true },
                skip: nil
            )
        )

        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)
        XCTAssertFalse(finishButton.isHidden)
        view.performBodyFinishAction()

        XCTAssertFalse(didFinish)
        drainMainQueue()
        XCTAssertTrue(didFinish)
    }

    func testManualAwaitingEyeGateOverlaySuppressesEmergencyAffordance() throws {
        let view = configuredEyeGateOverlay(
            manualAwaiting: true,
            isEmergencyOverrideAvailable: true,
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: true,
                canSkip: false,
                postpone: nil,
                finish: nil,
                skip: nil
            )
        )

        let emergencyButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.emergency.button") as? NSButton)
        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)
        XCTAssertTrue(emergencyButton.isHidden)
        XCTAssertFalse(finishButton.isHidden)
    }

    func testEyeGateOverlayDoesNotShowFinishBeforeManualAwaiting() throws {
        let view = configuredEyeGateOverlay(
            manualAwaiting: false,
            actions: nil
        )

        let finishButton = try XCTUnwrap(view.descendant(withIdentifier: "overlay.bodyFinish.button") as? NSButton)
        XCTAssertTrue(finishButton.isHidden)
        assertHiddenBodyActionButtonIsCleared(finishButton)
    }

    func testBodyOverlayActionsRemainAvailableWhenContentIsHidden() {
        var didSkip = false
        let view = configuredBodyOverlay(
            showsContent: false,
            actions: BodyOverlayActions(
                canPostpone: false,
                canFinish: false,
                canSkip: true,
                postpone: nil,
                finish: nil,
                skip: { didSkip = true }
            )
        )

        view.performBodySkipAction()

        XCTAssertFalse(didSkip)
        drainMainQueue()
        XCTAssertTrue(didSkip)
    }

    private enum BodyActionUnderTest {
        case postpone
        case skip
        case finish
    }

    private func assertPendingBodyActionFeedback(
        action: BodyActionUnderTest,
        expectedPendingTitle: String,
        expectedPendingHelp: String,
        expectedLockedButtonIdentifier: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: action != .finish,
                canFinish: action == .finish,
                canSkip: action != .finish,
                postpone: {},
                finish: {},
                skip: {}
            )
        )
        let pendingButtonIdentifier: String
        switch action {
        case .postpone:
            pendingButtonIdentifier = "overlay.bodyPostpone.button"
            view.performBodyPostponeAction()
        case .skip:
            pendingButtonIdentifier = "overlay.bodySkip.button"
            view.performBodySkipAction()
        case .finish:
            pendingButtonIdentifier = "overlay.bodyFinish.button"
            view.performBodyFinishAction()
        }

        let pendingButton = try XCTUnwrap(
            view.descendant(withIdentifier: pendingButtonIdentifier) as? NSButton,
            file: file,
            line: line
        )
        XCTAssertFalse(pendingButton.isEnabled, file: file, line: line)
        XCTAssertEqual(pendingButton.attributedTitle.string, expectedPendingTitle, file: file, line: line)
        XCTAssertEqual(pendingButton.image?.accessibilityDescription, expectedPendingTitle, file: file, line: line)
        XCTAssertEqual(pendingButton.toolTip, expectedPendingHelp, file: file, line: line)
        XCTAssertEqual(pendingButton.accessibilityLabel(), expectedPendingTitle, file: file, line: line)
        XCTAssertEqual(pendingButton.accessibilityHelp(), expectedPendingHelp, file: file, line: line)

        if let expectedLockedButtonIdentifier {
            let lockedButton = try XCTUnwrap(
                view.descendant(withIdentifier: expectedLockedButtonIdentifier) as? NSButton,
                file: file,
                line: line
            )
            XCTAssertFalse(lockedButton.isEnabled, file: file, line: line)
            XCTAssertEqual(lockedButton.toolTip, L10n.tr("overlay.bodyActionPendingHelp"), file: file, line: line)
            XCTAssertEqual(lockedButton.accessibilityHelp(), L10n.tr("overlay.bodyActionPendingHelp"), file: file, line: line)
        }
    }

    private func assertBodyActionDefersUntilNextMainQueueTurn(
        action: BodyActionUnderTest,
        expectedInvocation: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var invokedActions: [String] = []
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: action == .postpone,
                canFinish: action == .finish,
                canSkip: action == .skip,
                postpone: { invokedActions.append("postpone") },
                finish: { invokedActions.append("finish") },
                skip: { invokedActions.append("skip") }
            )
        )

        switch action {
        case .postpone:
            view.performBodyPostponeAction()
        case .skip:
            view.performBodySkipAction()
        case .finish:
            view.performBodyFinishAction()
        }

        XCTAssertTrue(invokedActions.isEmpty, file: file, line: line)
        drainMainQueue(file: file, line: line)
        XCTAssertEqual(invokedActions, [expectedInvocation], file: file, line: line)
    }

    private func configuredBodyOverlay(
        showsContent: Bool = true,
        manualAwaiting: Bool = false,
        actions: BodyOverlayActions?
    ) -> RestOverlayView {
        let start = Date()
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: true
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: 60,
            settings: .defaults,
            showsContent: showsContent,
            manualAwaiting: manualAwaiting,
            isEmergencyOverrideAvailable: false,
            bodyActions: actions
        )
        return view
    }

    private func configuredEyeGateOverlay(
        manualAwaiting: Bool,
        isEmergencyOverrideAvailable: Bool = false,
        actions: BodyOverlayActions?
    ) -> RestOverlayView {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: true
        )
        let view = RestOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.configure(
            session: session,
            remainingSeconds: manualAwaiting ? 0 : 20,
            settings: .defaults,
            showsContent: true,
            manualAwaiting: manualAwaiting,
            isEmergencyOverrideAvailable: isEmergencyOverrideAvailable,
            bodyActions: actions
        )
        return view
    }

    private func assertBodyActionButton(
        _ button: NSButton,
        title: String,
        toolTip: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(button.isHidden, file: file, line: line)
        XCTAssertEqual(button.attributedTitle.string, title, file: file, line: line)
        XCTAssertEqual(button.imagePosition, .imageLeading, file: file, line: line)
        XCTAssertNotNil(button.image, file: file, line: line)
        XCTAssertEqual(button.image?.accessibilityDescription, title, file: file, line: line)
        XCTAssertEqual(button.toolTip, toolTip, file: file, line: line)
        XCTAssertEqual(button.accessibilityLabel(), title, file: file, line: line)
        XCTAssertEqual(button.accessibilityHelp(), toolTip, file: file, line: line)
        XCTAssertTrue(
            button.hasConstraint(attribute: .width, relation: .greaterThanOrEqual, constant: 112),
            file: file,
            line: line
        )
        XCTAssertTrue(
            button.hasConstraint(attribute: .height, relation: .equal, constant: 34),
            file: file,
            line: line
        )
    }

    private func assertHiddenBodyActionButtonIsCleared(
        _ button: NSButton,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(button.isHidden, file: file, line: line)
        XCTAssertFalse(button.isEnabled, file: file, line: line)
        XCTAssertEqual(button.title, "", file: file, line: line)
        XCTAssertEqual(button.attributedTitle.string, "", file: file, line: line)
        XCTAssertNil(button.image, file: file, line: line)
        XCTAssertNil(button.toolTip, file: file, line: line)
        XCTAssertNil(button.accessibilityLabel(), file: file, line: line)
        XCTAssertNil(button.accessibilityHelp(), file: file, line: line)
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

    func hasConstraint(
        attribute: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation,
        constant: CGFloat
    ) -> Bool {
        constraints.contains { constraint in
            constraint.firstItem === self &&
                constraint.firstAttribute == attribute &&
                constraint.relation == relation &&
                abs(constraint.constant - constant) < 0.1
        }
    }
}
