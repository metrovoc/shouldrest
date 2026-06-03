import Foundation

public struct RestEngineState: Codable, Equatable, Sendable {
    public var scheduled: ScheduledRest?
    public var activeSession: RestSession?
    public var pause: PauseState?
    public var activeDeferral: RestDeferral?
    public var eyeGatesSinceBodyBreak: Int
    public var postponesInCurrentCycle: Int
    public var dangerScore: Int
    public var statistics: RestStatistics

    public init(
        scheduled: ScheduledRest? = nil,
        activeSession: RestSession? = nil,
        pause: PauseState? = nil,
        activeDeferral: RestDeferral? = nil,
        eyeGatesSinceBodyBreak: Int = 0,
        postponesInCurrentCycle: Int = 0,
        dangerScore: Int = 0,
        statistics: RestStatistics = RestStatistics()
    ) {
        self.scheduled = scheduled
        self.activeSession = activeSession
        self.pause = pause
        self.activeDeferral = activeDeferral
        self.eyeGatesSinceBodyBreak = eyeGatesSinceBodyBreak
        self.postponesInCurrentCycle = postponesInCurrentCycle
        self.dangerScore = dangerScore
        self.statistics = statistics
    }
}

public struct ScheduledRest: Codable, Equatable, Sendable {
    public var kind: RestKind
    public var dueAt: Date
    public var notificationAt: Date?
    public var notificationSent: Bool

    public init(kind: RestKind, dueAt: Date, notificationAt: Date?, notificationSent: Bool = false) {
        self.kind = kind
        self.dueAt = dueAt
        self.notificationAt = notificationAt
        self.notificationSent = notificationSent
    }
}

public struct RestSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: RestKind
    public var startedAt: Date
    public var scheduledAt: Date
    public var duration: TimeInterval
    public var manualFinishEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: RestKind,
        startedAt: Date,
        scheduledAt: Date,
        duration: TimeInterval,
        manualFinishEnabled: Bool
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.scheduledAt = scheduledAt
        self.duration = duration
        self.manualFinishEnabled = manualFinishEnabled
    }

    public func passedPercent(at date: Date) -> Double {
        guard duration > 0 else { return 100 }
        return min(100, max(0, date.timeIntervalSince(startedAt) / duration * 100))
    }
}

public struct PauseState: Codable, Equatable, Sendable {
    public var reason: PauseReason
    public var startedAt: Date
    public var until: Date?

    public init(reason: PauseReason, startedAt: Date, until: Date?) {
        self.reason = reason
        self.startedAt = startedAt
        self.until = until
    }

    public func isActive(at date: Date) -> Bool {
        guard let until else { return true }
        return date < until
    }
}

public struct RestDeferral: Codable, Equatable, Sendable {
    public var kind: RestKind
    public var reason: ContextDeferralReason
    public var startedAt: Date
    public var lastSeenAt: Date

    public init(kind: RestKind, reason: ContextDeferralReason, startedAt: Date, lastSeenAt: Date) {
        self.kind = kind
        self.reason = reason
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct RestStatistics: Codable, Equatable, Sendable {
    public var completedEyeGates: Int
    public var completedBodyBreaks: Int
    public var naturalEyeGates: Int
    public var naturalBodyBreaks: Int
    public var skippedEyeGates: Int
    public var skippedBodyBreaks: Int
    public var emergencyOverrides: Int
    public var postpones: Int

    public init(
        completedEyeGates: Int = 0,
        completedBodyBreaks: Int = 0,
        naturalEyeGates: Int = 0,
        naturalBodyBreaks: Int = 0,
        skippedEyeGates: Int = 0,
        skippedBodyBreaks: Int = 0,
        emergencyOverrides: Int = 0,
        postpones: Int = 0
    ) {
        self.completedEyeGates = completedEyeGates
        self.completedBodyBreaks = completedBodyBreaks
        self.naturalEyeGates = naturalEyeGates
        self.naturalBodyBreaks = naturalBodyBreaks
        self.skippedEyeGates = skippedEyeGates
        self.skippedBodyBreaks = skippedBodyBreaks
        self.emergencyOverrides = emergencyOverrides
        self.postpones = postpones
    }
}

public struct RestContext: Equatable, Sendable {
    public var idleDuration: TimeInterval
    public var focusModeActive: Bool
    public var inWorkingHours: Bool
    public var appExclusions: [AppExclusionEvaluation]

    public init(
        idleDuration: TimeInterval = 0,
        focusModeActive: Bool = false,
        inWorkingHours: Bool = true,
        appExclusions: [AppExclusionEvaluation] = []
    ) {
        self.idleDuration = max(0, idleDuration)
        self.focusModeActive = focusModeActive
        self.inWorkingHours = inWorkingHours
        self.appExclusions = appExclusions
    }
}

public enum RestEngineResult: Equatable, Sendable {
    case noChange
    case scheduled(ScheduledRest)
    case notificationDue(RestKind)
    case started(RestSession)
    case completed(RestSession, RestCompletionReason)
    case naturalRestCredited(RestKind)
    case postponed(RestKind, until: Date)
    case deferred(RestKind, ContextDeferralReason)
    case paused(PauseState)
    case resumed
    case reset
    case denied(ActionDenial)
}

public struct RestEngine: Equatable, Sendable {
    public private(set) var settings: RestSettings
    public private(set) var state: RestEngineState

    public init(settings: RestSettings = .defaults, now: Date = Date()) {
        self.settings = settings
        self.state = RestEngineState()
        scheduleNextRest(from: now)
    }

    public mutating func updateSettings(_ settings: RestSettings, now: Date = Date()) {
        self.settings = settings
        if state.activeSession == nil && state.pause == nil {
            scheduleNextRest(from: now)
        }
    }

    @discardableResult
    public mutating func evaluate(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        if let pause = state.pause {
            if pause.isActive(at: now) {
                return .paused(pause)
            }
            state.pause = nil
            scheduleNextRest(from: now)
        }

        if let active = state.activeSession {
            if context.idleDuration >= active.duration, settings.naturalBreaks.isEnabled {
                return completeActive(now: now, reason: .natural)
            }
            return .started(active)
        }

        if settings.naturalBreaks.isEnabled, let natural = creditNaturalRestIfPossible(context: context, now: now) {
            return natural
        }

        guard var scheduled = state.scheduled else {
            scheduleNextRest(from: now)
            if let scheduled = state.scheduled {
                return .scheduled(scheduled)
            }
            return .noChange
        }

        if let notificationAt = scheduled.notificationAt,
           !scheduled.notificationSent,
           now >= notificationAt,
           now < scheduled.dueAt {
            scheduled.notificationSent = true
            state.scheduled = scheduled
            return .notificationDue(scheduled.kind)
        }

        guard now >= scheduled.dueAt else {
            return .noChange
        }

        if let reason = deferralReason(for: scheduled.kind, context: context) {
            return deferScheduledRest(scheduled, reason: reason, now: now)
        }

        return startScheduledRest(scheduled, now: now)
    }

    @discardableResult
    public mutating func takeNow(_ kind: RestKind, now: Date = Date()) -> RestEngineResult {
        guard state.activeSession == nil else {
            return .denied(.alreadyActive)
        }
        guard settings.rule(for: kind).isEnabled else {
            return .denied(.actionDisabled)
        }

        let scheduled = ScheduledRest(
            kind: kind,
            dueAt: now,
            notificationAt: nil,
            notificationSent: true
        )
        return startScheduledRest(scheduled, now: now)
    }

    @discardableResult
    public mutating func completeActive(now: Date = Date(), reason: RestCompletionReason = .completed) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }

        state.activeSession = nil
        recordCompletion(kind: session.kind, reason: reason)
        state.postponesInCurrentCycle = 0
        scheduleNextRest(from: now)
        return .completed(session, reason)
    }

    @discardableResult
    public mutating func postponeActive(now: Date = Date()) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }

        if session.kind == .eyeGate {
            return .denied(.eyeGateCannotBePostponed)
        }

        let rule = settings.rule(for: session.kind)
        guard rule.postpone.isEnabled else {
            return .denied(.actionDisabled)
        }
        guard state.postponesInCurrentCycle < rule.postpone.maxCount else {
            return .denied(.postponeLimitReached)
        }
        guard session.passedPercent(at: now) <= rule.postpone.allowedDuringFirstPercent else {
            return .denied(.postponeWindowExpired)
        }

        state.activeSession = nil
        state.postponesInCurrentCycle += 1
        state.statistics.postpones += 1
        increaseDanger(for: session.kind)
        let dueAt = now.addingTimeInterval(rule.postpone.duration)
        state.scheduled = scheduledRest(kind: session.kind, dueAt: dueAt)
        return .postponed(session.kind, until: dueAt)
    }

    @discardableResult
    public mutating func skipActive(now: Date = Date()) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }
        if session.kind == .eyeGate {
            return .denied(.eyeGateCannotBeSkipped)
        }
        guard settings.rule(for: session.kind).ordinarySkipEnabled else {
            return .denied(.actionDisabled)
        }
        return completeActive(now: now, reason: .skipped)
    }

    @discardableResult
    public mutating func emergencyOverride(now: Date = Date()) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }
        guard session.kind == .eyeGate else {
            return skipActive(now: now)
        }
        guard settings.eyeGate.emergencyOverride.isEnabled else {
            return .denied(.emergencyOverrideDisabled)
        }
        return completeActive(now: now, reason: .emergencyOverride)
    }

    @discardableResult
    public mutating func pause(for duration: TimeInterval?, now: Date = Date(), reason: PauseReason = .user) -> RestEngineResult {
        if let active = state.activeSession {
            if active.kind == .eyeGate {
                return .denied(.eyeGateCannotBeSkipped)
            }
            _ = completeActive(now: now, reason: .skipped)
        }

        let until = duration.map { now.addingTimeInterval(max(1, $0)) }
        let pause = PauseState(reason: reason, startedAt: now, until: until)
        state.pause = pause
        state.scheduled = nil
        state.activeDeferral = nil
        return .paused(pause)
    }

    @discardableResult
    public mutating func resume(now: Date = Date()) -> RestEngineResult {
        state.pause = nil
        scheduleNextRest(from: now)
        return .resumed
    }

    @discardableResult
    public mutating func reset(now: Date = Date()) -> RestEngineResult {
        state = RestEngineState()
        scheduleNextRest(from: now)
        return .reset
    }

    private mutating func scheduleNextRest(from now: Date) {
        guard state.pause == nil, state.activeSession == nil, let kind = nextRestKind() else {
            state.scheduled = nil
            state.activeDeferral = nil
            return
        }
        let dueAt = now.addingTimeInterval(intervalForNextRest(kind))
        state.scheduled = scheduledRest(kind: kind, dueAt: dueAt)
        state.activeDeferral = nil
    }

    private func scheduledRest(kind: RestKind, dueAt: Date) -> ScheduledRest {
        let notificationAt: Date?
        if settings.notifications.isEnabled(for: kind) {
            let leadTime = settings.notifications.leadTime(for: kind)
            notificationAt = leadTime > 0 ? dueAt.addingTimeInterval(-leadTime) : nil
        } else {
            notificationAt = nil
        }
        return ScheduledRest(kind: kind, dueAt: dueAt, notificationAt: notificationAt)
    }

    private mutating func startScheduledRest(_ scheduled: ScheduledRest, now: Date) -> RestEngineResult {
        let rule = settings.rule(for: scheduled.kind)
        guard rule.isEnabled else {
            scheduleNextRest(from: now)
            return .noChange
        }

        let session = RestSession(
            kind: scheduled.kind,
            startedAt: now,
            scheduledAt: scheduled.dueAt,
            duration: rule.duration,
            manualFinishEnabled: rule.manualFinishEnabled
        )
        state.scheduled = nil
        state.activeDeferral = nil
        state.activeSession = session
        return .started(session)
    }

    private mutating func deferScheduledRest(
        _ scheduled: ScheduledRest,
        reason: ContextDeferralReason,
        now: Date
    ) -> RestEngineResult {
        if let activeDeferral = state.activeDeferral,
           activeDeferral.kind == scheduled.kind,
           activeDeferral.reason == reason {
            state.activeDeferral?.lastSeenAt = now
        } else {
            state.activeDeferral = RestDeferral(
                kind: scheduled.kind,
                reason: reason,
                startedAt: now,
                lastSeenAt: now
            )
            increaseDanger(for: scheduled.kind)
        }

        return .deferred(scheduled.kind, reason)
    }

    private func nextRestKind() -> RestKind? {
        if settings.bodyBreak.isEnabled,
           (!settings.eyeGate.isEnabled || state.eyeGatesSinceBodyBreak >= settings.bodyBreakAfterEyeGates) {
            return .bodyBreak
        }
        if settings.eyeGate.isEnabled {
            return .eyeGate
        }
        if settings.bodyBreak.isEnabled {
            return .bodyBreak
        }
        return nil
    }

    private func intervalForNextRest(_ kind: RestKind) -> TimeInterval {
        if kind == .bodyBreak, settings.eyeGate.isEnabled, state.eyeGatesSinceBodyBreak >= settings.bodyBreakAfterEyeGates {
            return settings.eyeGate.interval
        }
        return settings.rule(for: kind).interval
    }

    private func deferralReason(for kind: RestKind, context: RestContext) -> ContextDeferralReason? {
        if settings.workingHours.isEnabled, !context.inWorkingHours {
            return .outsideWorkingHours
        }

        if settings.focusMode.monitorFocusMode,
           context.focusModeActive,
           settings.focusMode.defers(kind) {
            return .focusMode
        }

        for evaluation in context.appExclusions where evaluation.rule.isEnabled && evaluation.rule.appliesTo.contains(kind) {
            switch evaluation.rule.mode {
            case .pauseWhenMatched where evaluation.isMatched:
                return .appExclusion(evaluation.rule.name)
            case .resumeOnlyWhenMatched where !evaluation.isMatched:
                return .appExclusion(evaluation.rule.name)
            default:
                continue
            }
        }

        return nil
    }

    private mutating func creditNaturalRestIfPossible(context: RestContext, now: Date) -> RestEngineResult? {
        guard context.idleDuration > 0 else {
            return nil
        }

        if let scheduled = state.scheduled {
            let rule = settings.rule(for: scheduled.kind)
            guard context.idleDuration >= rule.duration else {
                return nil
            }
            recordCompletion(kind: scheduled.kind, reason: .natural)
            state.postponesInCurrentCycle = 0
            scheduleNextRest(from: now)
            return .naturalRestCredited(scheduled.kind)
        }

        if context.idleDuration >= settings.naturalBreaks.inactivityResetTime {
            scheduleNextRest(from: now)
            return .scheduled(state.scheduled!)
        }

        return nil
    }

    private mutating func recordCompletion(kind: RestKind, reason: RestCompletionReason) {
        switch reason {
        case .completed, .manual:
            incrementCompleted(kind)
            decreaseDanger(for: kind)
            advanceCycle(for: kind, satisfied: true)
        case .natural:
            incrementCompleted(kind)
            incrementNatural(kind)
            decreaseDanger(for: kind)
            advanceCycle(for: kind, satisfied: true)
        case .skipped, .appExclusion:
            incrementSkipped(kind)
            increaseDanger(for: kind)
            advanceCycle(for: kind, satisfied: kind == .bodyBreak)
        case .emergencyOverride:
            state.statistics.emergencyOverrides += 1
            incrementSkipped(kind)
            increaseDanger(for: kind)
            advanceCycle(for: kind, satisfied: false)
        }
    }

    private mutating func advanceCycle(for kind: RestKind, satisfied: Bool) {
        switch kind {
        case .eyeGate:
            if satisfied {
                state.eyeGatesSinceBodyBreak += 1
            }
        case .bodyBreak:
            state.eyeGatesSinceBodyBreak = 0
        }
    }

    private mutating func incrementCompleted(_ kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.statistics.completedEyeGates += 1
        case .bodyBreak:
            state.statistics.completedBodyBreaks += 1
        }
    }

    private mutating func incrementNatural(_ kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.statistics.naturalEyeGates += 1
        case .bodyBreak:
            state.statistics.naturalBodyBreaks += 1
        }
    }

    private mutating func incrementSkipped(_ kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.statistics.skippedEyeGates += 1
        case .bodyBreak:
            state.statistics.skippedBodyBreaks += 1
        }
    }

    private mutating func increaseDanger(for kind: RestKind) {
        guard settings.presentation.breakHealthMode else { return }
        state.dangerScore = min(10, state.dangerScore + kind.defaultHealthWeight)
    }

    private mutating func decreaseDanger(for kind: RestKind) {
        guard settings.presentation.breakHealthMode else { return }
        state.dangerScore = max(0, state.dangerScore - kind.defaultHealthWeight)
    }
}
