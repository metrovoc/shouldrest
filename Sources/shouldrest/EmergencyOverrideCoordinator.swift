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

    mutating func request(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision {
        // Current design is always two in-overlay requests: first arms, second exits.
        // Legacy timing and step-count settings are compatibility data only.
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
