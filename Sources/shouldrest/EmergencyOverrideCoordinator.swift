import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case armed(remainingSeconds: Int)
    case complete(completedConfirmationSteps: Int, heldDuration: TimeInterval)
}

struct EmergencyOverrideCoordinator {
    private(set) var armedSessionID: UUID?

    func isArmed(for session: RestSession) -> Bool {
        armedSessionID == session.id
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
            armedSessionID = session.id
            return .armed(remainingSeconds: Int(ceil(policy.minimumHoldDuration - heldDuration)))
        }

        armedSessionID = nil
        return .complete(
            completedConfirmationSteps: policy.confirmationSteps,
            heldDuration: heldDuration
        )
    }

    mutating func completionIfArmedAndReady(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision? {
        guard armedSessionID == session.id else { return nil }
        guard session.kind == .eyeGate, policy.isEnabled else {
            armedSessionID = nil
            return .unavailable
        }

        let heldDuration = max(0, now.timeIntervalSince(session.startedAt))
        guard heldDuration >= policy.minimumHoldDuration else { return nil }

        armedSessionID = nil
        return .complete(
            completedConfirmationSteps: policy.confirmationSteps,
            heldDuration: heldDuration
        )
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
