import Foundation

public struct RestEngineState: Codable, Equatable, Sendable {
    public var scheduled: ScheduledRest?
    public var activeSession: RestSession?
    public var pause: PauseState?
    public var activeDeferral: RestDeferral?
    public var eyeDebt: TimeInterval
    public var bodyDebt: TimeInterval
    public var lastEvaluatedAt: Date?
    public var lastIdleDuration: TimeInterval
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
        lastEvaluatedAt: Date? = nil,
        lastIdleDuration: TimeInterval = 0,
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
        self.lastEvaluatedAt = lastEvaluatedAt
        self.lastIdleDuration = max(0, lastIdleDuration)
        self.bodySuppressedUntil = bodySuppressedUntil
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
    public var allowsNaturalRecovery: Bool

    public init(
        idleDuration: TimeInterval = 0,
        focusModeActive: Bool = false,
        inWorkingHours: Bool = true,
        appExclusions: [AppExclusionEvaluation] = [],
        allowsNaturalRecovery: Bool = false
    ) {
        self.idleDuration = max(0, idleDuration)
        self.focusModeActive = focusModeActive
        self.inWorkingHours = inWorkingHours
        self.appExclusions = appExclusions
        self.allowsNaturalRecovery = allowsNaturalRecovery
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

public struct RestEngine: Equatable, Sendable {
    public private(set) var settings: RestSettings
    public private(set) var state: RestEngineState

    public init(settings: RestSettings = .defaults, now: Date = Date()) {
        self.settings = settings.normalizedForCurrentDesign()
        self.state = RestEngineState(lastEvaluatedAt: now)
        refreshProjectedSchedule(now: now, preserveNotificationStateFrom: nil)
    }

    public mutating func updateSettings(_ settings: RestSettings, now: Date = Date()) {
        let enforcedSettings = settings.normalizedForCurrentDesign()
        self.settings = enforcedSettings
        if !enforcedSettings.presentation.breakHealthMode {
            state.dangerScore = 0
        }
        if state.activeSession == nil && state.pause == nil {
            refreshScheduleAfterSettingsUpdate(now: now)
        }
    }

    @discardableResult
    public mutating func evaluate(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        if let pause = state.pause {
            if pause.isActive(at: now) {
                markNonWorkingEvaluation(now: now, idleDuration: context.idleDuration)
                return .paused(pause)
            }
            state.pause = nil
            markNonWorkingEvaluation(now: now, idleDuration: context.idleDuration)
            refreshProjectedSchedule(now: now)
        }

        if let active = state.activeSession {
            if context.idleDuration >= active.duration,
               settings.naturalBreaks.isEnabled {
                return completeActive(now: now, reason: .natural)
            }
            markNonWorkingEvaluation(now: now, idleDuration: context.idleDuration)
            return .started(active)
        }

        let previousSchedule = state.scheduled
        let creditedNaturally = updateDebt(now: now, context: context)

        if !creditedNaturally.isEmpty {
            clearDeferrals(satisfiedBy: creditedNaturally)
            refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)
            return .naturalRestsCredited(creditedNaturally)
        }

        if let deferredResult = evaluateActiveDeferral(now: now, context: context) {
            return deferredResult
        }

        refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)

        if isAway(context: context) {
            return .noChange
        }

        guard var scheduled = state.scheduled else {
            refreshProjectedSchedule(now: now)
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

        let dueCandidates = dueRestCandidates(now: now)
        for candidate in dueCandidates {
            let candidateSchedule = projectedRest(kind: candidate, now: now, remaining: 0)
            if let reason = deferralReason(for: candidate, context: context) {
                _ = deferScheduledRest(candidateSchedule, reason: reason, now: now)
                continue
            }
            return startScheduledRest(candidateSchedule, now: now)
        }

        if let candidate = dueCandidates.first,
           let reason = deferralReason(for: candidate, context: context) {
            return deferScheduledRest(projectedRest(kind: candidate, now: now, remaining: 0), reason: reason, now: now)
        }

        return .noChange
    }

    @discardableResult
    public mutating func deferActiveForAppExclusion(
        now: Date = Date(),
        context: RestContext
    ) -> RestEngineResult {
        guard let active = state.activeSession else {
            return .denied(.noActiveSession)
        }

        guard let reason = activeAppExclusionInterruptionReason(for: active.kind, context: context) else {
            return .noChange
        }

        state.activeSession = nil
        let scheduled = scheduledRest(kind: active.kind, dueAt: now)
        state.scheduled = scheduled
        return deferScheduledRest(scheduled, reason: reason, now: now)
    }

    @discardableResult
    public mutating func takeNow(_ kind: RestKind, now: Date = Date()) -> RestEngineResult {
        guard state.activeSession == nil else {
            return .denied(.alreadyActive)
        }
        guard state.pause == nil else {
            return .denied(.alreadyPaused)
        }
        guard settings.rule(for: kind).isEnabled else {
            return .denied(.actionDisabled)
        }
        markNonWorkingEvaluation(now: now, idleDuration: 0)

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
        markNonWorkingEvaluation(now: now, idleDuration: 0)
        refreshProjectedSchedule(now: now)
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
        if session.kind == .bodyBreak {
            state.bodyDebt = settings.bodyBreak.interval
            state.bodySuppressedUntil = dueAt
        }
        markNonWorkingEvaluation(now: now, idleDuration: 0)
        refreshProjectedSchedule(now: now)
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
        let policy = settings.eyeGate.emergencyOverride
        guard policy.isEnabled else {
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
            guard settings.rule(for: active.kind).ordinarySkipEnabled else {
                return .denied(.actionDisabled)
            }
            _ = completeActive(now: now, reason: .skipped)
        }

        let until = duration.map { now.addingTimeInterval(max(1, $0)) }
        let pause = PauseState(reason: reason, startedAt: now, until: until)
        state.pause = pause
        state.scheduled = nil
        state.activeDeferral = nil
        markNonWorkingEvaluation(now: now, idleDuration: 0)
        return .paused(pause)
    }

    @discardableResult
    public mutating func resume(now: Date = Date()) -> RestEngineResult {
        state.pause = nil
        markNonWorkingEvaluation(now: now, idleDuration: 0)
        refreshProjectedSchedule(now: now)
        return .resumed
    }

    @discardableResult
    public mutating func reset(now: Date = Date()) -> RestEngineResult {
        state = RestEngineState(lastEvaluatedAt: now)
        refreshProjectedSchedule(now: now)
        return .reset
    }

    private mutating func refreshScheduleAfterSettingsUpdate(now: Date) {
        guard let activeDeferral = state.activeDeferral,
              let scheduled = state.scheduled,
              activeDeferral.kind == scheduled.kind,
              settings.rule(for: scheduled.kind).isEnabled else {
            refreshProjectedSchedule(now: now)
            return
        }
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

    private func projectedRest(kind: RestKind, now: Date, remaining: TimeInterval) -> ScheduledRest {
        scheduledRest(kind: kind, dueAt: now.addingTimeInterval(max(0, remaining)))
    }

    private mutating func evaluateActiveDeferral(now: Date, context: RestContext) -> RestEngineResult? {
        guard let activeDeferral = state.activeDeferral,
              let scheduled = state.scheduled,
              activeDeferral.kind == scheduled.kind else {
            return nil
        }

        guard settings.rule(for: scheduled.kind).isEnabled else {
            state.activeDeferral = nil
            refreshProjectedSchedule(now: now)
            return state.scheduled.map(RestEngineResult.scheduled) ?? .noChange
        }

        if isAway(context: context) {
            return .noChange
        }

        if let reason = deferralReason(for: scheduled.kind, context: context) {
            return deferScheduledRest(scheduled, reason: reason, now: now)
        }

        guard now >= scheduled.dueAt else {
            return .noChange
        }
        return startScheduledRest(scheduled, now: now)
    }

    private mutating func startScheduledRest(_ scheduled: ScheduledRest, now: Date) -> RestEngineResult {
        let rule = settings.rule(for: scheduled.kind)
        guard rule.isEnabled else {
            refreshProjectedSchedule(now: now)
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
        if state.activeDeferral?.kind == scheduled.kind {
            state.activeDeferral = nil
        }
        state.activeSession = session
        markNonWorkingEvaluation(now: now, idleDuration: 0)
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

    private func deferralReason(for kind: RestKind, context: RestContext) -> ContextDeferralReason? {
        if settings.workingHours.isEnabled, !context.inWorkingHours {
            return .outsideWorkingHours
        }

        if settings.focusMode.monitorFocusMode,
           context.focusModeActive,
           settings.focusMode.defers(kind) {
            return .focusMode
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

    private mutating func clearDeferrals(satisfiedBy creditedKinds: Set<RestKind>) {
        if let activeDeferral = state.activeDeferral,
           creditedKinds.contains(activeDeferral.kind) {
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
            suppressOrDischargeMissedDebt(for: kind)
        case .emergencyOverride:
            state.statistics.emergencyOverrides += 1
            incrementSkipped(kind)
            increaseDanger(for: kind)
            suppressOrDischargeMissedDebt(for: kind)
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

    private mutating func updateDebt(now: Date, context: RestContext) -> Set<RestKind> {
        let screenDelta = screenExposureDelta(now: now, context: context)
        let inputDelta = inputActiveDelta(now: now, idleDuration: context.idleDuration)
        if settings.eyeGate.isEnabled {
            state.eyeDebt = min(settings.eyeGate.interval, state.eyeDebt + screenDelta)
        } else {
            state.eyeDebt = 0
        }
        if settings.bodyBreak.isEnabled {
            state.bodyDebt = min(settings.bodyBreak.interval, state.bodyDebt + inputDelta)
        } else {
            state.bodyDebt = 0
            state.bodySuppressedUntil = nil
        }

        state.lastEvaluatedAt = now
        state.lastIdleDuration = context.idleDuration

        guard settings.naturalBreaks.isEnabled,
              context.allowsNaturalRecovery else {
            return []
        }
        return settleNaturalAwayIfNeeded(idleDuration: context.idleDuration)
    }

    private func screenExposureDelta(now: Date, context: RestContext) -> TimeInterval {
        guard state.pause == nil,
              state.activeSession == nil,
              let lastEvaluatedAt = state.lastEvaluatedAt else {
            return 0
        }

        if context.allowsNaturalRecovery,
           isLongIdle(idleDuration: context.idleDuration) {
            return 0
        }

        return max(0, now.timeIntervalSince(lastEvaluatedAt))
    }

    private func inputActiveDelta(now: Date, idleDuration: TimeInterval) -> TimeInterval {
        guard state.pause == nil,
              state.activeSession == nil,
              let lastEvaluatedAt = state.lastEvaluatedAt else {
            return 0
        }

        let elapsed = max(0, now.timeIntervalSince(lastEvaluatedAt))
        let previousIdle = max(0, state.lastIdleDuration)
        let currentIdle = max(0, idleDuration)
        if isLongIdle(idleDuration: currentIdle),
           isLongIdle(idleDuration: previousIdle) {
            return 0
        }
        guard currentIdle <= previousIdle else {
            return max(0, elapsed - (currentIdle - previousIdle))
        }
        guard currentIdle == 0 else {
            return 0
        }
        return elapsed
    }

    private mutating func markNonWorkingEvaluation(now: Date, idleDuration: TimeInterval) {
        state.lastEvaluatedAt = now
        state.lastIdleDuration = max(0, idleDuration)
    }

    private func isAway(context: RestContext) -> Bool {
        guard context.allowsNaturalRecovery,
              settings.naturalBreaks.isEnabled else { return false }
        return isNaturallyAway(idleDuration: context.idleDuration)
    }

    private func isNaturallyAway(idleDuration: TimeInterval) -> Bool {
        settings.naturalBreaks.isEnabled && isLongIdle(idleDuration: idleDuration)
    }

    private func isLongIdle(idleDuration: TimeInterval) -> Bool {
        idleDuration >= naturalRecoveryThreshold
    }

    private var naturalRecoveryThreshold: TimeInterval {
        settings.naturalBreaks.inactivityResetTime
    }

    private var bodyNaturalRecoveryThreshold: TimeInterval {
        max(settings.bodyBreak.duration, naturalRecoveryThreshold)
    }

    private mutating func settleNaturalAwayIfNeeded(idleDuration: TimeInterval) -> Set<RestKind> {
        var credited = Set<RestKind>()
        if settings.eyeGate.isEnabled,
           idleDuration >= naturalRecoveryThreshold,
           state.eyeDebt > 0 {
            state.eyeDebt = 0
            incrementCompleted(.eyeGate)
            incrementNatural(.eyeGate)
            decreaseDanger(for: .eyeGate)
            credited.insert(.eyeGate)
        }
        if settings.bodyBreak.isEnabled,
           idleDuration >= bodyNaturalRecoveryThreshold,
           state.bodyDebt > 0 {
            state.bodyDebt = 0
            state.bodySuppressedUntil = nil
            state.postponesInCurrentCycle = 0
            incrementCompleted(.bodyBreak)
            incrementNatural(.bodyBreak)
            decreaseDanger(for: .bodyBreak)
            credited.insert(.bodyBreak)
        }
        return credited
    }

    private mutating func refreshProjectedSchedule(
        now: Date,
        preserveNotificationStateFrom previous: ScheduledRest? = nil
    ) {
        guard state.pause == nil, state.activeSession == nil else {
            state.scheduled = nil
            state.activeDeferral = nil
            return
        }

        let candidates = projectedCandidates(now: now)
        guard let candidate = candidates.first else {
            state.scheduled = nil
            state.activeDeferral = nil
            return
        }

        var next = projectedRest(kind: candidate.kind, now: now, remaining: candidate.remaining)
        if let previous,
           shouldPreserveNotificationSent(from: previous, to: next, now: now) {
            next.notificationSent = true
        }
        state.scheduled = next
        if state.activeDeferral?.kind != next.kind || next.dueAt > now {
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

    private func projectedCandidates(now: Date) -> [(kind: RestKind, remaining: TimeInterval, priority: Int)] {
        var candidates: [(kind: RestKind, remaining: TimeInterval, priority: Int)] = []
        if settings.eyeGate.isEnabled {
            candidates.append((
                .eyeGate,
                max(0, settings.eyeGate.interval - state.eyeDebt),
                1
            ))
        }
        if settings.bodyBreak.isEnabled {
            let debtRemaining = max(0, settings.bodyBreak.interval - state.bodyDebt)
            let suppressionRemaining = state.bodySuppressedUntil.map { max(0, $0.timeIntervalSince(now)) } ?? 0
            candidates.append((
                .bodyBreak,
                max(debtRemaining, suppressionRemaining),
                0
            ))
        }
        return candidates.sorted { left, right in
            if left.remaining == right.remaining {
                return left.priority < right.priority
            }
            return left.remaining < right.remaining
        }
    }

    private func dueRestCandidates(now: Date) -> [RestKind] {
        projectedCandidates(now: now)
            .filter { $0.remaining <= 0 }
            .map(\.kind)
    }

    private mutating func satisfyDebt(for kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.eyeDebt = 0
        case .bodyBreak:
            state.bodyDebt = 0
            state.eyeDebt = 0
            state.bodySuppressedUntil = nil
        }
    }

    private mutating func suppressOrDischargeMissedDebt(for kind: RestKind) {
        switch kind {
        case .eyeGate:
            state.eyeDebt = 0
        case .bodyBreak:
            state.bodyDebt = 0
            state.bodySuppressedUntil = nil
        }
    }
}
