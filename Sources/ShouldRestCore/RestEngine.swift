import Foundation

public struct RestEngineState: Codable, Equatable, Sendable {
    public var scheduled: ScheduledRest?
    public var activeSession: RestSession?
    public var pause: PauseState?
    public var activeDeferral: RestDeferral?
    /// Screen exposure attributed to work since each rest was last satisfied. It may exceed the
    /// interval while a due rest waits, which keeps the original due time stable.
    public var eyeDebt: TimeInterval
    public var bodyDebt: TimeInterval
    /// Exposure accrued since the last sign of engagement. It becomes debt when the user is seen again
    /// before the away threshold and is dropped when the unattended stretch turns out to be an absence.
    public var pendingEyeDebt: TimeInterval
    public var pendingBodyDebt: TimeInterval
    public var lastEvaluatedAt: Date?
    /// Last time another app held the display awake for playback, a call, or a presentation.
    public var lastWatchedAt: Date?
    public var lastRestKind: RestKind?
    /// Input stops during a rest, so a pause only counts as a moment to start the next rest once it
    /// lasts beyond the end of the previous one.
    public var lastRestEndedAt: Date?
    public var bodySuppressedUntil: Date?
    public var postponesInCurrentCycle: Int
    public var dangerScore: Int
    public var statistics: RestStatistics

    public init(
        scheduled: ScheduledRest? = nil,
        activeSession: RestSession? = nil,
        pause: PauseState? = nil,
        activeDeferral: RestDeferral? = nil,
        eyeDebt: TimeInterval = 0,
        bodyDebt: TimeInterval = 0,
        pendingEyeDebt: TimeInterval = 0,
        pendingBodyDebt: TimeInterval = 0,
        lastEvaluatedAt: Date? = nil,
        lastWatchedAt: Date? = nil,
        lastRestKind: RestKind? = nil,
        lastRestEndedAt: Date? = nil,
        bodySuppressedUntil: Date? = nil,
        postponesInCurrentCycle: Int = 0,
        dangerScore: Int = 0,
        statistics: RestStatistics = RestStatistics()
    ) {
        self.scheduled = scheduled
        self.activeSession = activeSession
        self.pause = pause
        self.activeDeferral = activeDeferral
        self.eyeDebt = max(0, eyeDebt)
        self.bodyDebt = max(0, bodyDebt)
        self.pendingEyeDebt = max(0, pendingEyeDebt)
        self.pendingBodyDebt = max(0, pendingBodyDebt)
        self.lastEvaluatedAt = lastEvaluatedAt
        self.lastWatchedAt = lastWatchedAt
        self.lastRestKind = lastRestKind
        self.lastRestEndedAt = lastRestEndedAt
        self.bodySuppressedUntil = bodySuppressedUntil
        self.postponesInCurrentCycle = postponesInCurrentCycle
        self.dangerScore = dangerScore
        self.statistics = statistics
    }

    /// Debt including exposure from the current unattended stretch.
    public func debt(for kind: RestKind) -> TimeInterval {
        switch kind {
        case .eyeGate:
            eyeDebt + pendingEyeDebt
        case .bodyBreak:
            bodyDebt + pendingBodyDebt
        }
    }

    private enum CodingKeys: String, CodingKey {
        case scheduled
        case activeSession
        case pause
        case activeDeferral
        case eyeDebt
        case bodyDebt
        case pendingEyeDebt
        case pendingBodyDebt
        case lastEvaluatedAt
        case lastWatchedAt
        case lastRestKind
        case lastRestEndedAt
        case bodySuppressedUntil
        case postponesInCurrentCycle
        case dangerScore
        case statistics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            scheduled: container.decodeLossyOptional(ScheduledRest.self, forKey: .scheduled),
            activeSession: container.decodeLossyOptional(RestSession.self, forKey: .activeSession),
            pause: container.decodeLossyOptional(PauseState.self, forKey: .pause),
            activeDeferral: container.decodeLossyOptional(RestDeferral.self, forKey: .activeDeferral),
            eyeDebt: container.decodeLossy(TimeInterval.self, forKey: .eyeDebt, default: 0),
            bodyDebt: container.decodeLossy(TimeInterval.self, forKey: .bodyDebt, default: 0),
            pendingEyeDebt: container.decodeLossy(TimeInterval.self, forKey: .pendingEyeDebt, default: 0),
            pendingBodyDebt: container.decodeLossy(TimeInterval.self, forKey: .pendingBodyDebt, default: 0),
            lastEvaluatedAt: container.decodeLossyOptional(Date.self, forKey: .lastEvaluatedAt),
            lastWatchedAt: container.decodeLossyOptional(Date.self, forKey: .lastWatchedAt),
            lastRestKind: container.decodeLossyOptional(RestKind.self, forKey: .lastRestKind),
            lastRestEndedAt: container.decodeLossyOptional(Date.self, forKey: .lastRestEndedAt),
            bodySuppressedUntil: container.decodeLossyOptional(Date.self, forKey: .bodySuppressedUntil),
            postponesInCurrentCycle: container.decodeLossy(Int.self, forKey: .postponesInCurrentCycle, default: 0),
            dangerScore: container.decodeLossy(Int.self, forKey: .dangerScore, default: 0),
            statistics: container.decodeLossy(RestStatistics.self, forKey: .statistics, default: RestStatistics())
        )
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

/// When a due rest may begin. It starts early only during a clear pause, at the first natural pause
/// once due, and regardless of activity at the deadline, after the configured cue lead time.
public struct RestStartWindow: Equatable, Sendable {
    public var opensAt: Date
    public var dueAt: Date
    public var deadline: Date

    public init(opensAt: Date, dueAt: Date, deadline: Date) {
        self.opensAt = opensAt
        self.dueAt = dueAt
        self.deadline = deadline
    }
}

public enum RestTiming {
    /// An input gap of this length marks a natural pause once a rest is due. Writing research treats
    /// gaps of two seconds or more as planning pauses between units of work.
    public static let naturalPause: TimeInterval = 2
    /// An input gap long enough to start a rest slightly early: the user is reading, watching, or away.
    public static let clearPause: TimeInterval = 15

    /// How far a rest may move around its due time to land on a pause.
    public static func slack(forInterval interval: TimeInterval) -> TimeInterval {
        min(5 * 60, max(10, interval * 0.05))
    }

    /// Rests due this close together share one interruption instead of arriving minutes apart.
    public static func mergeHorizon(forInterval interval: TimeInterval) -> TimeInterval {
        min(5 * 60, interval / 4)
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
    public var appliesTo: Set<RestKind>

    public init(
        reason: PauseReason,
        startedAt: Date,
        until: Date?,
        appliesTo: Set<RestKind> = Set(RestKind.allCases)
    ) {
        self.reason = reason
        self.startedAt = startedAt
        self.until = until
        self.appliesTo = Self.normalizedAppliesTo(appliesTo)
    }

    public func isActive(at date: Date) -> Bool {
        guard let until else { return true }
        return date < until
    }

    public func applies(to kind: RestKind) -> Bool {
        appliesTo.contains(kind)
    }

    public var appliesToAllRests: Bool {
        RestKind.allCases.allSatisfy { appliesTo.contains($0) }
    }

    private static func normalizedAppliesTo(_ appliesTo: Set<RestKind>) -> Set<RestKind> {
        appliesTo.isEmpty ? Set(RestKind.allCases) : appliesTo
    }

    private enum CodingKeys: String, CodingKey {
        case reason
        case startedAt
        case until
        case appliesTo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reason = try container.decode(PauseReason.self, forKey: .reason)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.until = try container.decodeIfPresent(Date.self, forKey: .until)
        self.appliesTo = Self.normalizedAppliesTo(
            try container.decodeIfPresent(Set<RestKind>.self, forKey: .appliesTo) ?? Set(RestKind.allCases)
        )
    }
}

public enum RestDeferralSource: String, Codable, Equatable, Sendable {
    case scheduledDebt
    case activeInterruption
}

public struct RestDeferral: Codable, Equatable, Sendable {
    public var kind: RestKind
    public var reason: ContextDeferralReason
    public var source: RestDeferralSource
    public var startedAt: Date
    public var lastSeenAt: Date

    public init(
        kind: RestKind,
        reason: ContextDeferralReason,
        source: RestDeferralSource = .scheduledDebt,
        startedAt: Date,
        lastSeenAt: Date
    ) {
        self.kind = kind
        self.reason = reason
        self.source = source
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
    /// Seconds since the last keyboard or pointer input.
    public var idleDuration: TimeInterval
    /// Another app holds the display awake (video playback, a call, a presentation), so the user is
    /// probably watching the screen even without input.
    public var screenWatched: Bool
    /// A microphone is in use, which usually means a call or meeting.
    public var inCall: Bool
    /// How long the screen was verifiably asleep or locked immediately before this evaluation.
    public var screenOffDuration: TimeInterval
    public var focusModeActive: Bool
    public var inWorkingHours: Bool
    public var appExclusions: [AppExclusionEvaluation]

    public init(
        idleDuration: TimeInterval = 0,
        screenWatched: Bool = false,
        inCall: Bool = false,
        screenOffDuration: TimeInterval = 0,
        focusModeActive: Bool = false,
        inWorkingHours: Bool = true,
        appExclusions: [AppExclusionEvaluation] = []
    ) {
        self.idleDuration = max(0, idleDuration)
        self.screenWatched = screenWatched
        self.inCall = inCall
        self.screenOffDuration = max(0, screenOffDuration)
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
    case naturalRestsCredited(Set<RestKind>)
    case postponed(RestKind, until: Date)
    case deferred(RestKind, ContextDeferralReason)
    case paused(PauseState)
    case resumed
    case reset
    case denied(ActionDenial)
}

/// Schedules rests from screen exposure instead of wall-clock time.
///
/// Exposure accrues while the user is engaged: typing, pointing, or watching something that keeps
/// the display awake. Idle time is ambiguous (reading looks like absence), so it accrues as pending
/// debt that resolves once the evidence is in: it becomes debt when the user returns before the away
/// threshold, and it is dropped and the rests are credited when the stretch reaches the threshold.
/// A verified screen-off period (sleep, lock, display sleep) is unambiguous and credits each rest
/// once it lasts as long as that rest.
///
/// A due rest starts at the first natural pause in input within its start window instead of cutting
/// into a burst of work, and it may start slightly early during a clear pause. Rests due within a few
/// minutes of each other share one interruption: an Eye Gate becomes a Body Break that is nearly due,
/// and a nearly due Eye Gate continues a Body Break the user ends early.
public struct RestEngine: Equatable, Sendable {
    public private(set) var settings: RestSettings
    public private(set) var state: RestEngineState

    // A cue belongs to this running process; persisted notification flags cannot prove it is visible.
    private struct Cue: Equatable, Sendable {
        var kind: RestKind
        var startedAt: Date
    }
    private var cue: Cue?

    public var pendingCueKind: RestKind? { cue?.kind }

    public init(settings: RestSettings = .defaults, now: Date = Date()) {
        self.settings = settings.normalizedForCurrentDesign()
        self.state = RestEngineState(lastEvaluatedAt: now)
        refreshProjectedSchedule(now: now)
    }

    public init(settings: RestSettings = .defaults, restoring state: RestEngineState, now: Date = Date()) {
        self.settings = settings.normalizedForCurrentDesign()
        self.state = state
        if !self.settings.presentation.breakHealthMode {
            self.state.dangerScore = 0
        }
        if let pause = self.state.pause,
           pause.reason == .suspendOrLock || !pause.isActive(at: now) {
            // A suspend pause belongs to the process that saw the suspension begin; a new process
            // never sees it end.
            self.state.pause = nil
        }
        normalizeDebtState()
        let reconciledGap = reconcileUnobservedGap(now: now)
        if self.state.activeSession == nil,
           reconciledGap || self.state.scheduled == nil {
            refreshProjectedSchedule(now: now)
        }
    }

    public mutating func updateSettings(_ settings: RestSettings, now: Date = Date()) {
        let enforcedSettings = settings.normalizedForCurrentDesign()
        self.settings = enforcedSettings
        cue = nil
        if !enforcedSettings.presentation.breakHealthMode {
            state.dangerScore = 0
        }
        normalizeDebtState()
        if state.activeSession == nil && !activePauseBlocksAllEnabledRests(at: now) {
            let previous = state.scheduled
            clearDeferralMovedIntoFuture(now: now)
            refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previous)
        }
    }

    /// The window in which a rest of this kind may start, given the current debt.
    public func startWindow(for kind: RestKind, now: Date = Date()) -> RestStartWindow {
        let rule = settings.rule(for: kind)
        let slack = RestTiming.slack(forInterval: rule.interval)
        // Debt is accounted up to the last evaluation, so the due time does not drift between ticks.
        let accountedAt = state.lastEvaluatedAt ?? now
        var dueAt = accountedAt.addingTimeInterval(rule.interval - state.debt(for: kind))
        var opensAt = dueAt.addingTimeInterval(-slack)
        if kind == .bodyBreak, let suppressedUntil = state.bodySuppressedUntil {
            // A postponed Body Break never returns before the time the user chose.
            dueAt = max(dueAt, suppressedUntil)
            opensAt = max(dueAt.addingTimeInterval(-slack), suppressedUntil)
        }
        if kind == .bodyBreak, state.lastRestKind == .eyeGate, let lastRestEndedAt = state.lastRestEndedAt {
            let spacedStart = lastRestEndedAt.addingTimeInterval(RestTiming.mergeHorizon(forInterval: rule.interval))
            dueAt = max(dueAt, spacedStart)
            opensAt = max(opensAt, spacedStart)
        }
        return RestStartWindow(opensAt: opensAt, dueAt: dueAt, deadline: dueAt.addingTimeInterval(slack))
    }

    @discardableResult
    public mutating func evaluate(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        if let pause = state.pause {
            if let cue, pause.applies(to: cue.kind) { self.cue = nil }
            if pause.isActive(at: now) {
                if pauseBlocksAllEnabledRests(pause) {
                    let observation = observe(now: now, context: context)
                    clearDeferrals(satisfiedBy: observation.credited)
                    return .paused(pause)
                }
            } else {
                state.pause = nil
            }
        }

        if let active = state.activeSession {
            if canNaturallyCompleteActive(active, idleDuration: context.idleDuration) {
                return completeActive(now: now, reason: .natural, context: context)
            }
            let observation = observe(now: now, context: context, excluding: [active.kind])
            clearDeferrals(satisfiedBy: observation.credited)
            return .started(active)
        }

        let previousSchedule = state.scheduled
        let observation = observe(now: now, context: context)
        clearDeferrals(satisfiedBy: observation.credited)
        clearDeferralMovedIntoFuture(now: now)
        refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)

        if !observation.credited.isEmpty {
            cue = nil
            return .naturalRestsCredited(observation.credited)
        }
        if observation.isAway {
            cue = nil
            return .noChange
        }
        return decideStart(now: now, context: context)
    }

    @discardableResult
    public mutating func deferActiveForAppExclusion(
        now: Date = Date(),
        context: RestContext
    ) -> RestEngineResult {
        guard let active = state.activeSession else {
            return .denied(.noActiveSession)
        }

        guard !canNaturallyCompleteActive(active, idleDuration: context.idleDuration),
              !canAutomaticallyCompleteElapsedActive(active, now: now) else {
            return .noChange
        }

        let observation = observe(now: now, context: context, excluding: [active.kind])
        clearDeferrals(satisfiedBy: observation.credited)

        guard let reason = activeAppExclusionInterruptionReason(for: active.kind, context: context) else {
            return .noChange
        }

        state.activeSession = nil
        state.lastEvaluatedAt = now
        state.lastRestEndedAt = now
        state.lastRestKind = active.kind
        // The interrupted rest is still owed once the context clears.
        owe(active.kind)
        _ = eyeRestRemaining(afterEnded: active, now: now)
        refreshProjectedSchedule(now: now)
        return deferScheduledRest(kind: active.kind, reason: reason, now: now, source: .activeInterruption)
    }

    @discardableResult
    public mutating func takeNow(
        _ kind: RestKind,
        now: Date = Date(),
        context: RestContext = RestContext()
    ) -> RestEngineResult {
        guard state.activeSession == nil else {
            return .denied(.alreadyActive)
        }
        guard !isPaused(kind, at: now) else {
            return .denied(.alreadyPaused)
        }
        guard settings.rule(for: kind).isEnabled else {
            return .denied(.actionDisabled)
        }
        let observation = observe(now: now, context: context)
        clearDeferrals(satisfiedBy: observation.credited)
        if observation.isAway {
            refreshProjectedSchedule(now: now)
            return observation.credited.isEmpty ? .noChange : .naturalRestsCredited(observation.credited)
        }
        return startRest(kind: kind, scheduledAt: now, now: now)
    }

    @discardableResult
    public mutating func completeActive(
        now: Date = Date(),
        reason: RestCompletionReason = .completed,
        context: RestContext = RestContext()
    ) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }

        let observation = observe(now: now, context: context, excluding: [session.kind])
        clearDeferrals(satisfiedBy: observation.credited)
        state.activeSession = nil
        recordCompletion(kind: session.kind, reason: reason)
        clearDeferrals(satisfiedBy: satisfiedKinds(kind: session.kind, reason: reason))
        _ = eyeRestRemaining(afterEnded: session, now: now)
        state.postponesInCurrentCycle = 0
        state.lastEvaluatedAt = now
        state.lastRestEndedAt = now
        state.lastRestKind = session.kind
        refreshProjectedSchedule(now: now)
        return .completed(session, reason)
    }

    /// Postpones an active Body Break. When the Eye Gate is nearly due, its remainder continues in
    /// the same interruption and becomes the active session.
    @discardableResult
    public mutating func postponeActive(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
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

        let observation = observe(now: now, context: context, excluding: [session.kind])
        clearDeferrals(satisfiedBy: observation.credited)
        state.activeSession = nil
        state.postponesInCurrentCycle += 1
        state.statistics.postpones += 1
        increaseDanger(for: session.kind)
        let dueAt = now.addingTimeInterval(rule.postpone.duration)
        owe(.bodyBreak)
        state.bodySuppressedUntil = dueAt
        state.lastEvaluatedAt = now
        state.lastRestEndedAt = now
        state.lastRestKind = session.kind
        refreshProjectedSchedule(now: now)
        continueEyeRest(afterEnded: session, now: now, context: context)
        return .postponed(session.kind, until: dueAt)
    }

    /// Skips an active Body Break. When the Eye Gate is nearly due, its remainder continues in the
    /// same interruption and becomes the active session.
    @discardableResult
    public mutating func skipActive(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }
        if session.kind == .eyeGate {
            return .denied(.eyeGateCannotBeSkipped)
        }
        guard settings.rule(for: session.kind).ordinarySkipEnabled else {
            return .denied(.actionDisabled)
        }
        let result = completeActive(now: now, reason: .skipped, context: context)
        continueEyeRest(afterEnded: session, now: now, context: context)
        return result
    }

    @discardableResult
    public mutating func emergencyOverride(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }
        guard session.kind == .eyeGate else {
            return skipActive(now: now, context: context)
        }
        let policy = settings.eyeGate.emergencyOverride
        guard policy.isEnabled else {
            return .denied(.emergencyOverrideDisabled)
        }
        return completeActive(now: now, reason: .emergencyOverride, context: context)
    }

    @discardableResult
    public mutating func pause(
        for duration: TimeInterval?,
        now: Date = Date(),
        reason: PauseReason = .user,
        appliesTo: Set<RestKind> = Set(RestKind.allCases),
        context: RestContext = RestContext()
    ) -> RestEngineResult {
        let normalizedAppliesTo = appliesTo.isEmpty ? Set(RestKind.allCases) : appliesTo
        if let active = state.activeSession {
            guard normalizedAppliesTo.contains(active.kind) else {
                return .denied(.alreadyActive)
            }
            if canNaturallyCompleteActive(active, idleDuration: context.idleDuration) {
                _ = completeActive(now: now, reason: .natural, context: context)
            } else if canAutomaticallyCompleteElapsedActive(active, now: now) {
                _ = completeActive(now: now, reason: .completed, context: context)
            } else {
                if active.kind == .eyeGate {
                    return .denied(.eyeGateCannotBeSkipped)
                }
                guard settings.rule(for: active.kind).ordinarySkipEnabled else {
                    return .denied(.actionDisabled)
                }
                _ = completeActive(now: now, reason: .skipped, context: context)
            }
        } else {
            let observation = observe(now: now, context: context)
            clearDeferrals(satisfiedBy: observation.credited)
        }

        let until = duration.map { now.addingTimeInterval(max(1, $0)) }
        let pause = PauseState(reason: reason, startedAt: now, until: until, appliesTo: normalizedAppliesTo)
        state.pause = pause
        cue = nil
        state.scheduled = nil
        state.activeDeferral = nil
        state.lastEvaluatedAt = now
        refreshProjectedSchedule(now: now)
        return .paused(pause)
    }

    @discardableResult
    public mutating func resume(now: Date = Date()) -> RestEngineResult {
        cue = nil
        state.pause = nil
        // Paused time never becomes debt; an unattended stretch keeps running across the pause.
        state.lastEvaluatedAt = now
        refreshProjectedSchedule(now: now)
        return .resumed
    }

    @discardableResult
    public mutating func reset(now: Date = Date()) -> RestEngineResult {
        cue = nil
        state = RestEngineState(lastEvaluatedAt: now)
        refreshProjectedSchedule(now: now)
        return .reset
    }

    // MARK: - Exposure accounting

    private struct Observation {
        var isAway: Bool
        var credited: Set<RestKind>
    }

    private var awayThreshold: TimeInterval {
        settings.naturalBreaks.inactivityResetTime
    }

    /// Advances exposure accounting to `now` and credits rests that an absence satisfied.
    private mutating func observe(
        now: Date,
        context: RestContext,
        excluding excludedKinds: Set<RestKind> = []
    ) -> Observation {
        let unattended = unattendedDuration(now: now, context: context)
        let engagedAt = now.addingTimeInterval(-unattended)
        if let lastEvaluatedAt = state.lastEvaluatedAt {
            let elapsed = max(0, now.timeIntervalSince(lastEvaluatedAt))
            let engagedSinceLastEvaluation = engagedAt > lastEvaluatedAt
            let engagedPortion = min(elapsed, max(0, engagedAt.timeIntervalSince(lastEvaluatedAt)))
            if engagedSinceLastEvaluation {
                // The user came back before the away threshold: the idle stretch was screen time.
                commitPendingDebt()
            }
            for kind in RestKind.allCases where accruesDebt(kind, at: now) {
                addDebt(kind, committed: engagedPortion, pending: elapsed - engagedPortion)
            }
        }
        state.lastEvaluatedAt = now

        var credited = Set<RestKind>()
        let isAway = unattended >= awayThreshold
        if isAway {
            discardPendingDebt()
            credited = creditNaturalRests(absence: unattended, evidenceThreshold: awayThreshold, excluding: excludedKinds)
        }
        if context.screenOffDuration > 0 {
            credited.formUnion(creditNaturalRests(
                absence: context.screenOffDuration,
                evidenceThreshold: 0,
                excluding: excludedKinds
            ))
        }
        normalizeDebtState()
        return Observation(isAway: isAway, credited: credited)
    }

    /// Time since the last sign that the user was engaged with the screen.
    private mutating func unattendedDuration(now: Date, context: RestContext) -> TimeInterval {
        let idleDuration = max(0, context.idleDuration)
        // An active rest covers the screen, so playback behind it says nothing about the user.
        guard state.activeSession == nil else { return idleDuration }
        if context.screenWatched {
            state.lastWatchedAt = now
            return 0
        }
        guard let lastWatchedAt = state.lastWatchedAt else { return idleDuration }
        return min(idleDuration, max(0, now.timeIntervalSince(lastWatchedAt)))
    }

    private func accruesDebt(_ kind: RestKind, at date: Date) -> Bool {
        state.activeSession == nil && settings.rule(for: kind).isEnabled && !isPaused(kind, at: date)
    }

    private mutating func addDebt(_ kind: RestKind, committed: TimeInterval, pending: TimeInterval) {
        switch kind {
        case .eyeGate:
            state.eyeDebt += max(0, committed)
            state.pendingEyeDebt += max(0, pending)
        case .bodyBreak:
            state.bodyDebt += max(0, committed)
            state.pendingBodyDebt += max(0, pending)
        }
    }

    private mutating func commitPendingDebt() {
        state.eyeDebt += state.pendingEyeDebt
        state.bodyDebt += state.pendingBodyDebt
        discardPendingDebt()
    }

    private mutating func discardPendingDebt() {
        state.pendingEyeDebt = 0
        state.pendingBodyDebt = 0
    }

    /// Marks a rest as owed now, keeping any overdue time already accrued.
    private mutating func owe(_ kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.eyeDebt = max(state.debt(for: .eyeGate), settings.eyeGate.interval)
            state.pendingEyeDebt = 0
        case .bodyBreak:
            state.bodyDebt = max(state.debt(for: .bodyBreak), settings.bodyBreak.interval)
            state.pendingBodyDebt = 0
        }
    }

    /// Debt is bounded at two intervals: enough to keep an overdue rest's due time stable while it
    /// waits for a pause or a deferral to clear.
    private mutating func normalizeDebtState() {
        if settings.eyeGate.isEnabled {
            let ceiling = settings.eyeGate.interval * 2
            state.eyeDebt = min(ceiling, max(0, state.eyeDebt))
            state.pendingEyeDebt = min(ceiling - state.eyeDebt, max(0, state.pendingEyeDebt))
        } else {
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
        }
        if settings.bodyBreak.isEnabled {
            let ceiling = settings.bodyBreak.interval * 2
            state.bodyDebt = min(ceiling, max(0, state.bodyDebt))
            state.pendingBodyDebt = min(ceiling - state.bodyDebt, max(0, state.pendingBodyDebt))
        } else {
            state.bodyDebt = 0
            state.pendingBodyDebt = 0
            state.bodySuppressedUntil = nil
        }
    }

    /// Time while the app was not running cannot be observed. A gap at least as long as the away
    /// threshold is treated as an absence; a shorter one, such as a relaunch, counts as continuous use.
    private mutating func reconcileUnobservedGap(now: Date) -> Bool {
        guard let lastEvaluatedAt = state.lastEvaluatedAt else {
            state.lastEvaluatedAt = now
            return true
        }
        let gap = now.timeIntervalSince(lastEvaluatedAt)
        guard gap >= awayThreshold else { return false }
        state.lastEvaluatedAt = now
        discardPendingDebt()
        if state.activeSession == nil {
            let credited = creditNaturalRests(absence: gap, evidenceThreshold: awayThreshold)
            clearDeferrals(satisfiedBy: credited)
            clearDeferralMovedIntoFuture(now: now)
        }
        return true
    }

    /// Credits each rest whose duration the absence covered. Idle-inferred absences must also reach
    /// the away threshold; verified screen-off periods need no extra evidence.
    private mutating func creditNaturalRests(
        absence: TimeInterval,
        evidenceThreshold: TimeInterval,
        excluding excludedKinds: Set<RestKind> = []
    ) -> Set<RestKind> {
        guard settings.naturalBreaks.isEnabled else { return [] }
        var credited = Set<RestKind>()
        if !excludedKinds.contains(.eyeGate),
           settings.eyeGate.isEnabled,
           absence >= max(evidenceThreshold, settings.eyeGate.duration),
           state.debt(for: .eyeGate) > 0 {
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
            incrementCompleted(.eyeGate)
            incrementNatural(.eyeGate)
            decreaseDanger(for: .eyeGate)
            credited.insert(.eyeGate)
        }
        if !excludedKinds.contains(.bodyBreak),
           settings.bodyBreak.isEnabled,
           absence >= max(evidenceThreshold, settings.bodyBreak.duration),
           state.debt(for: .bodyBreak) > 0 {
            state.bodyDebt = 0
            state.pendingBodyDebt = 0
            state.bodySuppressedUntil = nil
            state.postponesInCurrentCycle = 0
            incrementCompleted(.bodyBreak)
            incrementNatural(.bodyBreak)
            decreaseDanger(for: .bodyBreak)
            credited.insert(.bodyBreak)
            if !excludedKinds.contains(.eyeGate),
               settings.eyeGate.isEnabled,
               state.debt(for: .eyeGate) > 0 || state.activeDeferral?.kind == .eyeGate {
                state.eyeDebt = 0
                state.pendingEyeDebt = 0
                credited.insert(.eyeGate)
            }
        }
        return credited
    }

    // MARK: - Starting rests

    private struct StartCandidate {
        var kind: RestKind
        var window: RestStartWindow
    }

    private func startCandidates(now: Date) -> [StartCandidate] {
        RestKind.allCases
            .filter { settings.rule(for: $0).isEnabled && !isPaused($0, at: now) }
            .map { StartCandidate(kind: $0, window: startWindow(for: $0, now: now)) }
            .sorted { left, right in
                if left.window.dueAt == right.window.dueAt {
                    return left.kind == .bodyBreak && right.kind != .bodyBreak
                }
                return left.window.dueAt < right.window.dueAt
            }
    }

    private func isWithinMergeHorizon(_ kind: RestKind, window: RestStartWindow, now: Date) -> Bool {
        let horizon = RestTiming.mergeHorizon(forInterval: settings.rule(for: kind).interval)
        if kind == .bodyBreak, state.lastRestKind == .eyeGate,
           let endedAt = state.lastRestEndedAt, now < endedAt.addingTimeInterval(horizon) {
            return false
        }
        var mergeableFrom = window.dueAt.addingTimeInterval(-horizon)
        if kind == .bodyBreak, let suppressedUntil = state.bodySuppressedUntil {
            mergeableFrom = max(mergeableFrom, suppressedUntil)
        }
        return now >= min(mergeableFrom, window.opensAt)
    }

    private func isStartMoment(_ window: RestStartWindow, now: Date, pauseDuration: TimeInterval) -> Bool {
        if now >= window.deadline {
            return true
        }
        if now >= window.dueAt {
            return pauseDuration >= RestTiming.naturalPause
        }
        if now >= window.opensAt {
            return pauseDuration >= RestTiming.clearPause
        }
        return false
    }

    private mutating func decideStart(now: Date, context: RestContext) -> RestEngineResult {
        let candidates = startCandidates(now: now)
        if let cue, deferralReason(for: cue.kind, context: context, now: now) != nil {
            self.cue = nil
        }
        let pauseDuration = min(
            context.idleDuration,
            state.lastRestEndedAt.map { max(0, now.timeIntervalSince($0)) } ?? .infinity
        )
        var deferred: (kind: RestKind, reason: ContextDeferralReason)?
        var chosen: StartCandidate?

        for candidate in candidates {
            let reason = deferralReason(for: candidate.kind, context: context, now: now)
            if let activeDeferral = state.activeDeferral, activeDeferral.kind == candidate.kind {
                if let reason {
                    deferred = deferred ?? (candidate.kind, reason)
                    continue
                }
                // Once its context clears, a deferred rest starts at the next natural pause, or after
                // one slack interval if the user keeps working.
                let slack = RestTiming.slack(forInterval: settings.rule(for: candidate.kind).interval)
                guard pauseDuration >= RestTiming.naturalPause ||
                    now.timeIntervalSince(activeDeferral.lastSeenAt) >= slack else {
                    continue
                }
                guard now >= candidate.window.opensAt else { continue }
                chosen = candidate
                break
            }
            guard isStartMoment(candidate.window, now: now, pauseDuration: pauseDuration) else {
                continue
            }
            if let reason {
                if now >= candidate.window.dueAt {
                    deferred = deferred ?? (candidate.kind, reason)
                }
                continue
            }
            chosen = candidate
            break
        }

        if var chosen {
            if chosen.kind == .eyeGate,
               let body = candidates.first(where: { $0.kind == .bodyBreak }),
               isWithinMergeHorizon(.bodyBreak, window: body.window, now: now),
               deferralReason(for: .bodyBreak, context: context, now: now) == nil {
                // The user is being interrupted anyway; the Body Break also rests the eyes.
                chosen = body
            }
            if let deferred, deferred.kind != chosen.kind {
                _ = deferScheduledRest(kind: deferred.kind, reason: deferred.reason, now: now)
            }
            if needsCue(for: chosen.kind) {
                guard let cue, cue.kind == chosen.kind else {
                    return beginCue(for: chosen.kind, now: now)
                }
                guard now.timeIntervalSince(cue.startedAt) >= settings.notifications.leadTime(for: chosen.kind) else {
                    return .noChange
                }
            }
            return startRest(kind: chosen.kind, scheduledAt: chosen.window.dueAt, now: now)
        }

        if let deferred {
            return deferScheduledRest(kind: deferred.kind, reason: deferred.reason, now: now)
        }

        // A cue can begin before a start opportunity, but never during a deferring context.
        if let scheduled = state.scheduled,
           let notificationAt = scheduled.notificationAt,
           cue == nil,
           now >= notificationAt,
           deferralReason(for: scheduled.kind, context: context, now: now) == nil {
            return beginCue(for: scheduled.kind, now: now)
        }
        return .noChange
    }

    private func needsCue(for kind: RestKind) -> Bool {
        settings.notifications.isEnabled(for: kind) && settings.notifications.leadTime(for: kind) > 0
    }

    private mutating func beginCue(for kind: RestKind, now: Date) -> RestEngineResult {
        cue = Cue(kind: kind, startedAt: now)
        state.scheduled = scheduledRest(kind: kind, dueAt: startWindow(for: kind, now: now).dueAt)
        state.scheduled?.notificationSent = true
        return .notificationDue(kind)
    }

    private mutating func startRest(kind: RestKind, scheduledAt: Date, now: Date) -> RestEngineResult {
        let rule = settings.rule(for: kind)
        guard rule.isEnabled else {
            refreshProjectedSchedule(now: now)
            return .noChange
        }

        let session = RestSession(
            kind: kind,
            startedAt: now,
            scheduledAt: scheduledAt,
            duration: rule.duration,
            manualFinishEnabled: rule.manualFinishEnabled
        )
        state.scheduled = nil
        if state.activeDeferral?.kind == kind {
            state.activeDeferral = nil
        }
        state.activeSession = session
        cue = nil
        state.lastEvaluatedAt = now
        return .started(session)
    }

    /// Time on a Body Break overlay is time away from screen work. Returns how much of the Eye Gate
    /// remains after a Body Break ended early, crediting the eyes when nothing remains.
    private mutating func eyeRestRemaining(afterEnded session: RestSession, now: Date) -> TimeInterval {
        guard session.kind == .bodyBreak, settings.eyeGate.isEnabled else { return 0 }
        let remaining = settings.eyeGate.duration - max(0, now.timeIntervalSince(session.startedAt))
        if remaining <= 0 {
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
            clearDeferrals(satisfiedBy: [.eyeGate])
        }
        return max(0, remaining)
    }

    private mutating func continueEyeRest(afterEnded session: RestSession, now: Date, context: RestContext) {
        guard state.activeSession == nil else { return }
        let remaining = eyeRestRemaining(afterEnded: session, now: now)
        guard remaining > 0,
              !isPaused(.eyeGate, at: now),
              deferralReason(for: .eyeGate, context: context, now: now) == nil else {
            return
        }
        let window = startWindow(for: .eyeGate, now: now)
        guard isWithinMergeHorizon(.eyeGate, window: window, now: now) else { return }
        state.activeSession = RestSession(
            kind: .eyeGate,
            startedAt: now,
            scheduledAt: window.dueAt,
            duration: remaining,
            manualFinishEnabled: settings.eyeGate.manualFinishEnabled
        )
        state.scheduled = nil
        if state.activeDeferral?.kind == .eyeGate {
            state.activeDeferral = nil
        }
    }

    // MARK: - Context deferral

    private mutating func deferScheduledRest(
        kind: RestKind,
        reason: ContextDeferralReason,
        now: Date,
        source: RestDeferralSource = .scheduledDebt
    ) -> RestEngineResult {
        if let activeDeferral = state.activeDeferral,
           activeDeferral.kind == kind,
           activeDeferral.reason == reason {
            state.activeDeferral?.lastSeenAt = now
            if source == .activeInterruption {
                state.activeDeferral?.source = source
            }
        } else {
            state.activeDeferral = RestDeferral(
                kind: kind,
                reason: reason,
                source: source,
                startedAt: now,
                lastSeenAt: now
            )
            increaseDanger(for: kind)
        }

        return .deferred(kind, reason)
    }

    private func deferralReason(for kind: RestKind, context: RestContext, now: Date) -> ContextDeferralReason? {
        if settings.workingHours.isEnabled, !context.inWorkingHours {
            return .outsideWorkingHours
        }

        if settings.focusMode.monitorFocusMode,
           context.focusModeActive,
           settings.focusMode.defers(kind) {
            return .focusMode
        }

        if kind == .bodyBreak, context.inCall, !callDeferralExhausted(now: now) {
            return .inCall
        }

        for evaluation in context.appExclusions where evaluation.rule.isActionable && evaluation.rule.appliesTo.contains(kind) {
            switch evaluation.rule.mode {
            case .pauseWhenMatched where evaluation.isMatched:
                return .appExclusion(evaluation.rule.displayName)
            case .resumeOnlyWhenMatched where !evaluation.isMatched:
                return .appExclusion(evaluation.rule.displayName)
            default:
                continue
            }
        }

        return nil
    }

    /// A call holds a Body Break back for at most one more Body Break interval, so a microphone that
    /// never stops cannot silence Body Breaks.
    private func callDeferralExhausted(now: Date) -> Bool {
        guard let deferral = state.activeDeferral,
              deferral.kind == .bodyBreak,
              deferral.reason == .inCall else {
            return false
        }
        return now.timeIntervalSince(deferral.startedAt) >= settings.bodyBreak.interval
    }

    private mutating func clearDeferrals(satisfiedBy creditedKinds: Set<RestKind>) {
        if let activeDeferral = state.activeDeferral,
           creditedKinds.contains(activeDeferral.kind) {
            state.activeDeferral = nil
        }
    }

    private func satisfiedKinds(kind: RestKind, reason: RestCompletionReason) -> Set<RestKind> {
        switch reason {
        case .completed, .manual, .natural:
            switch kind {
            case .eyeGate:
                return [.eyeGate]
            case .bodyBreak:
                return [.eyeGate, .bodyBreak]
            }
        case .skipped, .appExclusion, .emergencyOverride:
            return [kind]
        }
    }

    private mutating func clearDeferralMovedIntoFuture(now: Date) {
        guard let activeDeferral = state.activeDeferral else { return }
        guard settings.rule(for: activeDeferral.kind).isEnabled else {
            state.activeDeferral = nil
            return
        }
        guard activeDeferral.source == .scheduledDebt else { return }
        if state.debt(for: activeDeferral.kind) < settings.rule(for: activeDeferral.kind).interval {
            state.activeDeferral = nil
        }
    }

    private func activeAppExclusionInterruptionReason(
        for kind: RestKind,
        context: RestContext
    ) -> ContextDeferralReason? {
        guard kind != .eyeGate else { return nil }

        for evaluation in context.appExclusions where evaluation.rule.isActionable && evaluation.rule.appliesTo.contains(kind) {
            if evaluation.rule.mode == .pauseWhenMatched, evaluation.isMatched {
                return .appExclusion(evaluation.rule.displayName)
            }
        }

        return nil
    }

    // MARK: - Completion and statistics

    private mutating func recordCompletion(kind: RestKind, reason: RestCompletionReason) {
        switch reason {
        case .completed, .manual:
            incrementCompleted(kind)
            decreaseDanger(for: kind)
            satisfyDebt(for: kind)
        case .natural:
            incrementCompleted(kind)
            incrementNatural(kind)
            decreaseDanger(for: kind)
            satisfyDebt(for: kind)
        case .skipped, .appExclusion:
            incrementSkipped(kind)
            increaseDanger(for: kind)
            dischargeMissedDebt(for: kind)
        case .emergencyOverride:
            state.statistics.emergencyOverrides += 1
            incrementSkipped(kind)
            increaseDanger(for: kind)
            dischargeMissedDebt(for: kind)
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

    private mutating func satisfyDebt(for kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
        case .bodyBreak:
            state.bodyDebt = 0
            state.pendingBodyDebt = 0
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
            state.bodySuppressedUntil = nil
        }
    }

    private mutating func dischargeMissedDebt(for kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.eyeDebt = 0
            state.pendingEyeDebt = 0
        case .bodyBreak:
            state.bodyDebt = 0
            state.pendingBodyDebt = 0
            state.bodySuppressedUntil = nil
        }
    }

    // MARK: - Projection and pause

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

    private mutating func refreshProjectedSchedule(
        now: Date,
        preserveNotificationStateFrom previous: ScheduledRest? = nil
    ) {
        guard state.activeSession == nil,
              !activePauseBlocksAllEnabledRests(at: now),
              let next = startCandidates(now: now).first else {
            state.scheduled = nil
            state.activeDeferral = nil
            return
        }

        var scheduled = scheduledRest(kind: next.kind, dueAt: next.window.dueAt)
        if let previous,
           shouldPreserveNotificationSent(from: previous, to: scheduled, now: now) {
            scheduled.notificationSent = true
        }
        state.scheduled = scheduled
        if let activeDeferral = state.activeDeferral,
           !settings.rule(for: activeDeferral.kind).isEnabled || isPaused(activeDeferral.kind, at: now) {
            state.activeDeferral = nil
        }
    }

    private func shouldPreserveNotificationSent(
        from previous: ScheduledRest,
        to next: ScheduledRest,
        now: Date
    ) -> Bool {
        guard previous.kind == next.kind,
              previous.notificationSent else {
            return false
        }

        let dueDrift = abs(previous.dueAt.timeIntervalSince(next.dueAt))
        guard dueDrift >= 1 else { return true }

        guard previous.notificationAt != nil,
              next.notificationAt != nil,
              now < next.dueAt else {
            return false
        }

        let sameCycleDriftTolerance = max(60, settings.notifications.leadTime(for: next.kind) * 2)
        return dueDrift <= sameCycleDriftTolerance
    }

    private func canNaturallyCompleteActive(_ session: RestSession, idleDuration: TimeInterval) -> Bool {
        settings.naturalBreaks.isEnabled && idleDuration >= max(session.duration, awayThreshold)
    }

    private func canAutomaticallyCompleteElapsedActive(_ session: RestSession, now: Date) -> Bool {
        !session.manualFinishEnabled && now.timeIntervalSince(session.startedAt) >= session.duration
    }

    private func isPaused(_ kind: RestKind, at date: Date) -> Bool {
        guard let pause = state.pause,
              pause.isActive(at: date) else {
            return false
        }
        return pause.applies(to: kind)
    }

    private func activePauseBlocksAllEnabledRests(at date: Date) -> Bool {
        guard let pause = state.pause,
              pause.isActive(at: date) else {
            return false
        }
        return pauseBlocksAllEnabledRests(pause)
    }

    private func pauseBlocksAllEnabledRests(_ pause: PauseState) -> Bool {
        let enabledKinds = RestKind.allCases.filter { settings.rule(for: $0).isEnabled }
        guard !enabledKinds.isEmpty else { return false }
        return enabledKinds.allSatisfy { pause.applies(to: $0) }
    }
}
