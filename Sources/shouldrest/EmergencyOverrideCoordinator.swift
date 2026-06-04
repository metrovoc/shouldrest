import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case armed
    case complete
}

struct EmergencyOverrideCoordinator {
    static let confirmationWindowDuration: TimeInterval = 6

    private(set) var armedSessionID: UUID?
    private(set) var armedAt: Date?

    static func isAvailable(session: RestSession, policy: EmergencyOverridePolicy, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(session.startedAt)
        return session.kind == .eyeGate &&
            policy.isEnabled &&
            elapsed >= 0 &&
            elapsed < session.duration
    }

    func hasArmedSession(for session: RestSession) -> Bool {
        armedSessionID == session.id
    }

    func isArmed(for session: RestSession, now: Date) -> Bool {
        guard armedSessionID == session.id else { return false }
        guard let armedAt else { return false }
        return now.timeIntervalSince(armedAt) <= Self.confirmationWindowDuration
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

        if isArmed(for: session, now: now) {
            clear()
            return .complete
        }

        armedSessionID = session.id
        armedAt = now
        return .armed
    }

    mutating func clear(sessionID: UUID? = nil) {
        guard let sessionID else {
            armedSessionID = nil
            armedAt = nil
            return
        }
        if armedSessionID == sessionID {
            armedSessionID = nil
            armedAt = nil
        }
    }

}
