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
            clear()
            return .unavailable
        }

        guard Self.effectiveConfirmationSteps(policy) > 0 else {
            clear()
            return .complete
        }

        if armedSessionID == session.id {
            clear()
            return .complete
        }

        armedSessionID = session.id
        return .waiting(remainingSeconds: 0)
    }

    mutating func completionIfArmedAndReady(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> EmergencyOverrideDecision? {
        guard Self.isAvailable(session: session, policy: policy, now: now),
              armedSessionID == session.id else {
            clear(sessionID: session.id)
            return nil
        }

        return nil
    }

    func remainingSeconds(
        session: RestSession,
        policy: EmergencyOverridePolicy,
        now: Date
    ) -> Int? {
        guard Self.isAvailable(session: session, policy: policy, now: now) else {
            return nil
        }
        return 0
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

    private static func effectiveConfirmationSteps(_ policy: EmergencyOverridePolicy) -> Int {
        min(1, max(0, policy.confirmationSteps))
    }
}
