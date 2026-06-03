import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case waiting(remainingSeconds: Int)
    case complete(heldDuration: TimeInterval)
}

struct EmergencyOverrideCoordinator {
    private(set) var armedSessionID: UUID?

    func isArmed(for session: RestSession) -> Bool {
        false
    }

    mutating func request(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision {
        guard session.kind == .eyeGate, policy.isEnabled else {
            armedSessionID = nil
            return .unavailable
        }

        let heldDuration = max(0, now.timeIntervalSince(session.startedAt))
        guard heldDuration >= policy.minimumHoldDuration else {
            armedSessionID = nil
            return .waiting(remainingSeconds: Int(ceil(policy.minimumHoldDuration - heldDuration)))
        }

        armedSessionID = nil
        return .complete(heldDuration: heldDuration)
    }

    mutating func completionIfArmedAndReady(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision? {
        nil
    }

    mutating func clear(sessionID: UUID? = nil) {
        guard let sessionID else {
            armedSessionID = nil
            return
        }
        if armedSessionID == sessionID {
            armedSessionID = nil
        }
    }
}
