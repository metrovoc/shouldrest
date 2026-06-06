import ShouldRestCore
import XCTest
@testable import shouldrest

final class PendingAutomationStartRequestsTests: XCTestCase {
    func testQueuePreservesRequestOrderAndUpdatesBodyBreakIdea() {
        let firstIdea = RestIdea(
            id: "first",
            kind: .bodyBreak,
            title: "First",
            body: "Move first"
        )
        let replacementIdea = RestIdea(
            id: "replacement",
            kind: .bodyBreak,
            title: "Replacement",
            body: "Move later"
        )
        var queue = PendingAutomationStartRequests()

        queue.enqueue(AutomationStartRequest(kind: .bodyBreak, bodyBreakIdea: firstIdea))
        queue.enqueue(AutomationStartRequest(kind: .eyeGate))
        queue.enqueue(AutomationStartRequest(kind: .bodyBreak, bodyBreakIdea: replacementIdea))

        XCTAssertEqual(queue.requests.map(\.kind), [.bodyBreak, .eyeGate])
        XCTAssertEqual(queue.next?.bodyBreakIdea, replacementIdea)

        queue.remove(AutomationStartRequest(kind: .bodyBreak, bodyBreakIdea: firstIdea))

        XCTAssertEqual(queue.next, AutomationStartRequest(kind: .eyeGate))
    }

    func testEyeGateRequestIgnoresBodyBreakIdeaPayload() {
        let idea = RestIdea(
            id: "eye-payload",
            kind: .bodyBreak,
            title: "Should not attach",
            body: "Eye Gate stays text-free"
        )

        let request = AutomationStartRequest(kind: .eyeGate, bodyBreakIdea: idea)

        XCTAssertEqual(request.kind, .eyeGate)
        XCTAssertNil(request.bodyBreakIdea)
    }

    func testRetryPolicyKeepsOnlyTransientStartDenials() {
        XCTAssertEqual(
            AutomationStartRetryPolicy.decision(for: .denied(.alreadyPaused)),
            .keepPending
        )
        XCTAssertEqual(
            AutomationStartRetryPolicy.decision(for: .denied(.alreadyActive)),
            .keepPending
        )
        XCTAssertEqual(
            AutomationStartRetryPolicy.decision(for: .denied(.actionDisabled)),
            .discard
        )
        XCTAssertEqual(
            AutomationStartRetryPolicy.decision(for: .noChange),
            .discard
        )
    }
}
