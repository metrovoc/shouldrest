import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case armed
    case complete
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

    mutating func arm(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision {
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            clear()
            return .unavailable
        }

        armedSessionID = session.id
        return .armed
    }

    mutating func request(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision {
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            clear()
            return .unavailable
        }

        if armedSessionID == session.id {
            clear()
            return .complete
        }

        armedSessionID = session.id
        return .armed
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
