import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class ActiveRestActionPolicyTests: XCTestCase {
    func testEyeGateManualFinishShowsOnlyFinishAfterDuration() {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: true
        )

        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(19),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: false, canSkip: false)
        )
        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(20),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: true, canSkip: false)
        )
    }

    func testEyeGateWithoutManualFinishNeverShowsOverlayFinish() {
        let start = Date()
        let session = RestSession(
            kind: .eyeGate,
            startedAt: start,
            scheduledAt: start,
            duration: 20,
            manualFinishEnabled: false
        )

        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(60),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: false, canSkip: false)
        )
    }

    func testBodyBreakKeepsPostponeSkipAndFinishRules() {
        let start = Date()
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: true
        )

        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(10),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: false
            ),
            OverlayActionAvailability(canPostpone: true, canFinish: false, canSkip: false)
        )
        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(10),
                canPostponeBodyBreak: false,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: false, canSkip: true)
        )
        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(60),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: true, canSkip: false)
        )
    }

    func testBodyBreakWithoutManualFinishDoesNotExposeDeadFinishActionAfterDuration() {
        let start = Date()
        let session = RestSession(
            kind: .bodyBreak,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: false
        )

        XCTAssertEqual(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(60),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ),
            OverlayActionAvailability(canPostpone: false, canFinish: false, canSkip: false)
        )
        XCTAssertFalse(
            ActiveRestActionPolicy.availability(
                for: session,
                now: start.addingTimeInterval(60),
                canPostponeBodyBreak: true,
                canSkipBodyBreak: true
            ).hasAvailableAction
        )
    }

    func testAvailabilityReportsWhetherAnyActionCanRun() {
        XCTAssertFalse(OverlayActionAvailability(
            canPostpone: false,
            canFinish: false,
            canSkip: false
        ).hasAvailableAction)
        XCTAssertTrue(OverlayActionAvailability(
            canPostpone: true,
            canFinish: false,
            canSkip: false
        ).hasAvailableAction)
        XCTAssertTrue(OverlayActionAvailability(
            canPostpone: false,
            canFinish: true,
            canSkip: false
        ).hasAvailableAction)
        XCTAssertTrue(OverlayActionAvailability(
            canPostpone: false,
            canFinish: false,
            canSkip: true
        ).hasAvailableAction)
    }
}
