import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case waiting(remainingSeconds: Int)
    case complete(heldDuration: TimeInterval)
}

struct EmergencyOverrideCoordinator {
    private(set) var armedSessionID: UUID?

    static func isAvailable(session: RestSession, policy: EmergencyOverridePolicy, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(session.startedAt)
        return session.kind == .eyeGate &&
            policy.isEnabled &&
            elapsed >= 0 &&
            elapsed < session.duration
    }

    func isArmed(for session: RestSession) -> Bool {
        armedSessionID == session.id
    }

    mutating func request(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision {
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            armedSessionID = nil
            return .unavailable
        }

        let heldDuration = max(0, now.timeIntervalSince(session.startedAt))
        guard heldDuration >= policy.minimumHoldDuration else {
            armedSessionID = session.id
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
        guard armedSessionID == session.id else { return nil }
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            armedSessionID = nil
            return nil
        }

        let heldDuration = max(0, now.timeIntervalSince(session.startedAt))
        guard heldDuration >= policy.minimumHoldDuration else {
            return nil
        }

        armedSessionID = nil
        return .complete(heldDuration: heldDuration)
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
