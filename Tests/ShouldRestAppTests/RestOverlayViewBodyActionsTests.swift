import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class RestOverlayViewBodyActionsTests: XCTestCase {
    func testAvailableBodyOverlayActionsInvokeCallbacks() {
        var didPostpone = false
        var didSkip = false
        let view = configuredBodyOverlay(
            actions: BodyOverlayActions(
                canPostpone: true,
                canFinish: false,
                canSkip: true,
                postpone: { didPostpone = true },
                finish: nil,
                skip: { didSkip = true }
            )
        )

        view.performBodyPostponeAction()
        view.performBodySkipAction()

        XCTAssertTrue(didPostpone)
        XCTAssertTrue(didSkip)
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
        XCTAssertTrue(panel.isHidden)
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

        XCTAssertTrue(didFinish)
    }

    func testManualAwaitingEyeGateOverlaySuppressesEmergencyAffordance() throws {
        let view = configuredEyeGateOverlay(
            manualAwaiting: true,
            emergencyOverrideRemainingSeconds: 0,
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

        XCTAssertTrue(didSkip)
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
            emergencyOverrideRemainingSeconds: nil,
            bodyActions: actions
        )
        return view
    }

    private func configuredEyeGateOverlay(
        manualAwaiting: Bool,
        emergencyOverrideRemainingSeconds: Int? = nil,
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
            emergencyOverrideRemainingSeconds: emergencyOverrideRemainingSeconds,
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
        XCTAssertEqual(button.toolTip, toolTip, file: file, line: line)
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
