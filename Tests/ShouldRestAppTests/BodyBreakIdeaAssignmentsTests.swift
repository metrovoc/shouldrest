import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class BodyBreakIdeaAssignmentsTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 4_000)

    func testStartAttemptDoesNotConsumePendingIdeaUntilBodyBreakStarts() {
        let pendingIdea = idea(id: "pending", title: "Pending")
        var assignments = BodyBreakIdeaAssignments()
        assignments.storePending(pendingIdea)

        XCTAssertEqual(assignments.ideaForStartAttempt(explicit: nil), pendingIdea)
        XCTAssertEqual(assignments.pending, pendingIdea)

        assignments.bindStartedIdea(pendingIdea, to: session(kind: .eyeGate))

        XCTAssertEqual(assignments.pending, pendingIdea)
        XCTAssertNil(assignments.activeIdea(for: session(kind: .eyeGate)))
    }

    func testSuccessfulBodyBreakStartConsumesPendingIdea() {
        let pendingIdea = idea(id: "pending", title: "Pending")
        let bodySession = session(kind: .bodyBreak)
        var assignments = BodyBreakIdeaAssignments()
        assignments.storePending(pendingIdea)

        let resolvedIdea = assignments.ideaForStartAttempt(explicit: nil)
        assignments.bindStartedIdea(resolvedIdea, to: bodySession)

        XCTAssertNil(assignments.pending)
        XCTAssertEqual(assignments.activeIdea(for: bodySession), pendingIdea)
    }

    func testExplicitSuccessfulStartUsesExplicitIdeaAndClearsStalePendingIdea() {
        let pendingIdea = idea(id: "pending", title: "Pending")
        let explicitIdea = idea(id: "explicit", title: "Explicit")
        let bodySession = session(kind: .bodyBreak)
        var assignments = BodyBreakIdeaAssignments()
        assignments.storePending(pendingIdea)

        let resolvedIdea = assignments.ideaForStartAttempt(explicit: explicitIdea)
        assignments.bindStartedIdea(resolvedIdea, to: bodySession)

        XCTAssertNil(assignments.pending)
        XCTAssertEqual(assignments.activeIdea(for: bodySession), explicitIdea)
    }

    func testMissingOneShotIdeaDoesNotClearExistingPendingIdea() {
        let pendingIdea = idea(id: "pending", title: "Pending")
        var assignments = BodyBreakIdeaAssignments()
        assignments.storePending(pendingIdea)

        XCTAssertFalse(assignments.storePendingIfPresent(nil))

        XCTAssertEqual(assignments.pending, pendingIdea)
    }

    func testDeferredActiveIdeaReturnsToPendingForNextBodyBreak() {
        let pendingIdea = idea(id: "pending", title: "Pending")
        let bodySession = session(kind: .bodyBreak)
        var assignments = BodyBreakIdeaAssignments()
        assignments.bindStartedIdea(pendingIdea, to: bodySession)

        assignments.deferActiveIdeaToPending(for: bodySession)

        XCTAssertEqual(assignments.pending, pendingIdea)
        XCTAssertNil(assignments.activeIdea(for: bodySession))
    }

    private func session(kind: RestKind) -> RestSession {
        RestSession(
            id: UUID(uuidString: "6B334C67-43CB-4B49-924F-6F4A3B3D6247")!,
            kind: kind,
            startedAt: start,
            scheduledAt: start,
            duration: 60,
            manualFinishEnabled: true
        )
    }

    private func idea(id: String, title: String) -> RestIdea {
        RestIdea(
            id: id,
            kind: .bodyBreak,
            title: title,
            body: "Move",
            isEnabled: true
        )
    }
}
