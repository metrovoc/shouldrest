import Foundation
import ShouldRestCore

enum EmergencyOverrideDecision: Equatable {
    case unavailable
    case waiting(remainingSeconds: Int)
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
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            armedSessionID = nil
            return .unavailable
        }

        armedSessionID = nil
        return .complete
    }

    mutating func completionIfArmedAndReady(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision? {
        clear(sessionID: session.id)
        return nil
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
