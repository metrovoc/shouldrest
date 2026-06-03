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

    func testUnavailableBodyOverlayActionsDoNotInvokeCallbacks() {
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
            emergencyOverrideConfirmationSteps: 0,
            bodyActions: actions
        )
        return view
    }
}
