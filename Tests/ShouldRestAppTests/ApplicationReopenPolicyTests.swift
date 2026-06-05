import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class ApplicationReopenPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 3_000)

    func testExistingVisibleWindowUsesSystemReopenBehavior() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(
                state: RestEngineState(),
                hasVisibleWindows: true
            ),
            .allowSystemReopen
        )
        XCTAssertEqual(
            ApplicationReopenPolicy.action(
                state: RestEngineState(activeSession: session(kind: .eyeGate)),
                hasVisibleWindows: true
            ),
            .allowSystemReopen
        )
    }

    func testHiddenMenuBarIdleReopenOpensPreferences() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(
                state: RestEngineState(),
                hasVisibleWindows: false
            ),
            .openPreferences
        )
    }

    func testActiveRestReopenRestoresOverlayInsteadOfOpeningPreferences() {
        for kind in [RestKind.eyeGate, .bodyBreak] {
            XCTAssertEqual(
                ApplicationReopenPolicy.action(
                    state: RestEngineState(activeSession: session(kind: kind)),
                    hasVisibleWindows: false
                ),
                .restoreActiveOverlay
            )
        }
    }

    private func session(kind: RestKind) -> RestSession {
        RestSession(
            kind: kind,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )
    }
}
