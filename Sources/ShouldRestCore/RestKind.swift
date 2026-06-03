import Foundation

public enum RestKind: String, Codable, CaseIterable, Hashable, Sendable {
    case eyeGate
    case bodyBreak

    public var defaultHealthWeight: Int {
        switch self {
        case .eyeGate:
            1
        case .bodyBreak:
            2
        }
    }
}

public enum RestCompletionReason: String, Codable, Equatable, Sendable {
    case completed
    case natural
    case manual
    case skipped
    case emergencyOverride
    case appExclusion
}

public enum PauseReason: String, Codable, Equatable, Sendable {
    case user
    case untilMorning
    case suspendOrLock
    case appExclusion
    case focusMode
}

public enum ContextDeferralReason: Codable, Equatable, Sendable {
    case outsideWorkingHours
    case focusMode
    case appExclusion(String)
}

public enum ActionDenial: Equatable, Sendable {
    case alreadyActive
    case noActiveSession
    case actionDisabled
    case eyeGateCannotBeSkipped
    case eyeGateCannotBePostponed
    case emergencyOverrideDisabled
    case postponeLimitReached
    case postponeWindowExpired
}
