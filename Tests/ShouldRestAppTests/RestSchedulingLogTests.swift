import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class RestSchedulingLogTests: XCTestCase {
    func testHoldTransitionsLogEntryReleaseAndReasonChangesWithoutTickSpam() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let call = RestDeferral(kind: .bodyBreak, reason: .inCall, startedAt: now, lastSeenAt: now)
        var later = call
        later.lastSeenAt = now.addingTimeInterval(1)
        XCTAssertEqual(RestStartLogDetails.deferralTransitions(from: nil, to: call).count, 1)
        XCTAssertTrue(RestStartLogDetails.deferralTransitions(from: call, to: later).isEmpty)
        XCTAssertEqual(RestStartLogDetails.deferralTransitions(from: call, to: nil).count, 1)
        later.reason = .focusMode
        XCTAssertEqual(RestStartLogDetails.deferralTransitions(from: call, to: later).count, 2)
    }

    func testStartDiagnosticsExplainContextDebtAndSpacing() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let session = RestSession(kind: .eyeGate, startedAt: now, scheduledAt: now.addingTimeInterval(60), duration: 20, manualFinishEnabled: false)
        let details = RestStartLogDetails.text(for: session, context: RestContext(idleDuration: 17, inCall: true))
        XCTAssertTrue(details.contains("offset=-60s idle=17s"))
        XCTAssertTrue(details.contains("inCall=true focus=false"))
        let state = RestEngineState(eyeDebt: 1_140, bodyDebt: 3_400, lastRestKind: .eyeGate, lastRestEndedAt: now.addingTimeInterval(-76))
        let stateDetails = RestStartLogDetails.stateText(state, now: now)
        XCTAssertTrue(stateDetails.contains("eyeDebt=1140s bodyDebt=3400s"))
        XCTAssertTrue(stateDetails.contains("sinceRest=76s previous=eyeGate"))
    }
}
