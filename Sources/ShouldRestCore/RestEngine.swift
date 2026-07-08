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
    public var awayCandidate: AwayCandidateSnapshot?
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
        awayCandidate: AwayCandidateSnapshot? = nil,
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
        self.awayCandidate = awayCandidate
        self.bodySuppressedUntil = bodySuppressedUntil
        self.postponesInCurrentCycle = postponesInCurrentCycle
        self.dangerScore = dangerScore
        self.statistics = statistics
    }
}

public struct AwayCandidateSnapshot: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var eyeDebt: TimeInterval
    public var bodyDebt: TimeInterval

    public init(startedAt: Date, eyeDebt: TimeInterval, bodyDebt: TimeInterval) {
        self.startedAt = startedAt
        self.eyeDebt = max(0, eyeDebt)
        self.bodyDebt = max(0, bodyDebt)
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

    public init(settings: RestSettings = .defaults, restoring state: RestEngineState, now: Date = Date()) {
        self.settings = settings.normalizedForCurrentDesign()
        self.state = state
        if !self.settings.presentation.breakHealthMode {
            self.state.dangerScore = 0
        }
        normalizeDebtState()
        if let pause = self.state.pause, !pause.isActive(at: now) {
            self.state.pause = nil
        }
        if self.state.activeSession == nil,
           self.state.scheduled == nil {
            refreshProjectedSchedule(now: now)
        }
    }

    public mutating func updateSettings(_ settings: RestSettings, now: Date = Date()) {
        let enforcedSettings = settings.normalizedForCurrentDesign()
        self.settings = enforcedSettings
        if !enforcedSettings.presentation.breakHealthMode {
            state.dangerScore = 0
        }
        normalizeDebtState()
        if state.activeSession == nil && !activePauseBlocksAllEnabledRests(at: now) {
            refreshScheduleAfterSettingsUpdate(now: now)
        }
    }

    @discardableResult
    public mutating func evaluate(now: Date = Date(), context: RestContext = RestContext()) -> RestEngineResult {
        if let pause = state.pause {
            if pause.isActive(at: now) {
                if pauseBlocksAllEnabledRests(pause) {
                    _ = settleAwayWithoutAccrualIfNeeded(now: now, idleDuration: context.idleDuration)
                    return .paused(pause)
                }
            } else {
                state.pause = nil
                markNonWorkingEvaluation(
                    now: now,
                    idleDuration: context.idleDuration,
                    preserveAwayCandidate: isCurrentAwayCandidate(now: now, idleDuration: context.idleDuration)
                )
                refreshProjectedSchedule(now: now)
            }
        }

        if let active = state.activeSession {
            if canNaturallyCompleteActive(active, idleDuration: context.idleDuration) {
                return completeActiveAfterNaturalAway(now: now, idleDuration: context.idleDuration)
            }
            let credited = settleAwayWithoutAccrualIfNeeded(
                now: now,
                idleDuration: context.idleDuration,
                excluding: [active.kind]
            )
            if !credited.isEmpty {
                clearDeferrals(satisfiedBy: credited)
            }
            return .started(active)
        }

        let previousSchedule = state.scheduled
        let creditedNaturally = updateDebt(now: now, context: context)

        if !creditedNaturally.isEmpty {
            clearDeferrals(satisfiedBy: creditedNaturally)
            if isAway(context: context) {
                clearDeferralMovedIntoFuture(now: now)
            }
            refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)
            return .naturalRestsCredited(creditedNaturally)
        }

        if isAway(context: context) {
            clearDeferralMovedIntoFuture(now: now)
            refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)
            return .noChange
        }

        refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previousSchedule)

        guard var scheduled = state.scheduled else {
            refreshProjectedSchedule(now: now)
            if let scheduled = state.scheduled {
                return .scheduled(scheduled)
            }
            return .noChange
        }

        let dueCandidates = dueRestCandidates(now: now)
        var firstDeferredCandidate: (scheduled: ScheduledRest, reason: ContextDeferralReason)?
        for candidate in dueCandidates {
            let candidateSchedule = dueSchedule(for: candidate, current: scheduled, now: now)
            if let reason = deferralReason(for: candidate, context: context) {
                if firstDeferredCandidate == nil {
                    firstDeferredCandidate = (candidateSchedule, reason)
                }
                continue
            }
            if let firstDeferredCandidate {
                _ = deferScheduledRest(
                    firstDeferredCandidate.scheduled,
                    reason: firstDeferredCandidate.reason,
                    now: now
                )
            }
            return startScheduledRest(
                candidateSchedule,
                now: now,
                idleDuration: context.idleDuration,
                preserveAwayCandidate: context.idleDuration > 0
            )
        }

        if let pendingDeferralResult = evaluatePendingDeferral(now: now, context: context) {
            return pendingDeferralResult
        }

        if let firstDeferredCandidate {
            return deferScheduledRest(
                firstDeferredCandidate.scheduled,
                reason: firstDeferredCandidate.reason,
                now: now
            )
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

        guard !canNaturallyCompleteActive(active, idleDuration: context.idleDuration),
              !canAutomaticallyCompleteElapsedActive(active, now: now) else {
            return .noChange
        }

        let credited = settleAwayWithoutAccrualIfNeeded(
            now: now,
            idleDuration: context.idleDuration,
            excluding: [active.kind]
        )
        if !credited.isEmpty {
            clearDeferrals(satisfiedBy: credited)
        }

        guard let reason = activeAppExclusionInterruptionReason(for: active.kind, context: context) else {
            return .noChange
        }

        state.activeSession = nil
        let scheduled = scheduledRest(kind: active.kind, dueAt: now)
        state.scheduled = scheduled
        markNonWorkingEvaluation(
            now: now,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: isCurrentAwayCandidate(now: now, idleDuration: context.idleDuration)
        )
        return deferScheduledRest(scheduled, reason: reason, now: now, source: .activeInterruption)
    }

    @discardableResult
    public mutating func takeNow(
        _ kind: RestKind,
        now: Date = Date(),
        idleDuration: TimeInterval = 0,
        preserveAwayCandidate: Bool = false
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
        let effectiveIdleDuration = max(0, idleDuration)
        let creditedNaturally = updateDebt(now: now, context: RestContext(idleDuration: effectiveIdleDuration))
        if isNaturallyAway(idleDuration: effectiveIdleDuration) {
            if !creditedNaturally.isEmpty {
                clearDeferrals(satisfiedBy: creditedNaturally)
            }
            refreshProjectedSchedule(now: now)
            if !creditedNaturally.isEmpty {
                return .naturalRestsCredited(creditedNaturally)
            }
            return .noChange
        }

        let scheduled = ScheduledRest(
            kind: kind,
            dueAt: now,
            notificationAt: nil,
            notificationSent: true
        )
        return startScheduledRest(
            scheduled,
            now: now,
            idleDuration: effectiveIdleDuration,
            preserveAwayCandidate: preserveAwayCandidate
        )
    }

    @discardableResult
    public mutating func completeActive(
        now: Date = Date(),
        reason: RestCompletionReason = .completed,
        idleDuration: TimeInterval = 0,
        preserveAwayCandidate: Bool = false
    ) -> RestEngineResult {
        guard let session = state.activeSession else {
            return .denied(.noActiveSession)
        }

        let effectiveIdleDuration = max(0, idleDuration)
        let credited: Set<RestKind>
        if effectiveIdleDuration > 0 {
            credited = settleAwayWithoutAccrualIfNeeded(
                now: now,
                idleDuration: effectiveIdleDuration,
                excluding: [session.kind]
            )
        } else {
            credited = []
        }
        if !credited.isEmpty {
            clearDeferrals(satisfiedBy: credited)
        }

        state.activeSession = nil
        recordCompletion(kind: session.kind, reason: reason)
        clearDeferrals(satisfiedBy: satisfiedKinds(kind: session.kind, reason: reason))
        state.postponesInCurrentCycle = 0
        let shouldPreserveAwayCandidate = preserveAwayCandidate &&
            isCurrentAwayCandidate(now: now, idleDuration: effectiveIdleDuration)
        if shouldPreserveAwayCandidate {
            updateAwayCandidateAfterCompletion(kind: session.kind)
        }
        markNonWorkingEvaluation(
            now: now,
            idleDuration: effectiveIdleDuration,
            preserveAwayCandidate: shouldPreserveAwayCandidate
        )
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
    public mutating func pause(
        for duration: TimeInterval?,
        now: Date = Date(),
        reason: PauseReason = .user,
        appliesTo: Set<RestKind> = Set(RestKind.allCases),
        idleDuration: TimeInterval = 0,
        preserveAwayCandidate: Bool = false
    ) -> RestEngineResult {
        let normalizedAppliesTo = appliesTo.isEmpty ? Set(RestKind.allCases) : appliesTo
        let wasPaused = state.pause != nil
        let startedFromActiveRest = state.activeSession != nil
        if let active = state.activeSession {
            guard normalizedAppliesTo.contains(active.kind) else {
                return .denied(.alreadyActive)
            }
            if canNaturallyCompleteActive(active, idleDuration: idleDuration) {
                _ = completeActiveAfterNaturalAway(now: now, idleDuration: idleDuration)
            } else if canAutomaticallyCompleteElapsedActive(active, now: now) {
                _ = completeActive(
                    now: now,
                    reason: .completed,
                    idleDuration: idleDuration,
                    preserveAwayCandidate: preserveAwayCandidate
                )
            } else {
                if active.kind == .eyeGate {
                    return .denied(.eyeGateCannotBeSkipped)
                }
                guard settings.rule(for: active.kind).ordinarySkipEnabled else {
                    return .denied(.actionDisabled)
                }
                let activeIdleSnapshot = preserveAwayCandidate &&
                    isCurrentAwayCandidate(now: now, idleDuration: idleDuration) ? state.awayCandidate : nil
                let naturalEyeGatesBeforeCompletion = state.statistics.naturalEyeGates
                let naturalBodyBreaksBeforeCompletion = state.statistics.naturalBodyBreaks
                _ = completeActive(
                    now: now,
                    reason: .skipped,
                    idleDuration: idleDuration,
                    preserveAwayCandidate: false
                )
                if let activeIdleSnapshot {
                    var restoredSnapshot = activeIdleSnapshot
                    if state.statistics.naturalEyeGates > naturalEyeGatesBeforeCompletion {
                        restoredSnapshot.eyeDebt = state.eyeDebt
                    }
                    if state.statistics.naturalBodyBreaks > naturalBodyBreaksBeforeCompletion {
                        restoredSnapshot.bodyDebt = state.bodyDebt
                    }
                    switch active.kind {
                    case .eyeGate:
                        restoredSnapshot.eyeDebt = state.eyeDebt
                    case .bodyBreak:
                        restoredSnapshot.bodyDebt = state.bodyDebt
                    }
                    state.awayCandidate = AwayCandidateSnapshot(
                        startedAt: restoredSnapshot.startedAt,
                        eyeDebt: restoredSnapshot.eyeDebt,
                        bodyDebt: restoredSnapshot.bodyDebt
                    )
                }
            }
        }

        let until = duration.map { now.addingTimeInterval(max(1, $0)) }
        let pause = PauseState(reason: reason, startedAt: now, until: until, appliesTo: normalizedAppliesTo)
        state.pause = pause
        state.scheduled = nil
        state.activeDeferral = nil
        if preserveAwayCandidate {
            updateAwayCandidateSnapshot(
                now: now,
                idleDuration: idleDuration,
                includingPreIdleComputerUse: !wasPaused && !startedFromActiveRest
            )
        }
        let shouldPreserveAwayCandidate = preserveAwayCandidate &&
            isCurrentAwayCandidate(now: now, idleDuration: idleDuration)
        markNonWorkingEvaluation(
            now: now,
            idleDuration: idleDuration,
            preserveAwayCandidate: shouldPreserveAwayCandidate
        )
        refreshProjectedSchedule(now: now)
        return .paused(pause)
    }

    @discardableResult
    public mutating func resume(
        now: Date = Date(),
        idleDuration: TimeInterval = 0,
        preserveAwayCandidate: Bool = false
    ) -> RestEngineResult {
        state.pause = nil
        let shouldPreserveAwayCandidate = preserveAwayCandidate &&
            isCurrentAwayCandidate(now: now, idleDuration: idleDuration)
        markNonWorkingEvaluation(
            now: now,
            idleDuration: idleDuration,
            preserveAwayCandidate: shouldPreserveAwayCandidate
        )
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
        let previous = state.scheduled
        clearDeferralMovedIntoFuture(now: now)
        refreshProjectedSchedule(now: now, preserveNotificationStateFrom: previous)
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

    private func dueSchedule(for kind: RestKind, current scheduled: ScheduledRest?, now: Date) -> ScheduledRest {
        if let scheduled, scheduled.kind == kind, scheduled.dueAt <= now {
            return scheduled
        }
        return projectedRest(kind: kind, now: now, remaining: 0)
    }

    private mutating func evaluatePendingDeferral(now: Date, context: RestContext) -> RestEngineResult? {
        guard state.activeDeferral != nil else {
            return nil
        }

        clearDeferralMovedIntoFuture(now: now)
        guard let activeDeferral = state.activeDeferral else {
            refreshProjectedSchedule(now: now)
            return state.scheduled.map(RestEngineResult.scheduled) ?? .noChange
        }

        let scheduled = scheduledRest(kind: activeDeferral.kind, dueAt: activeDeferral.startedAt)
        if let reason = deferralReason(for: activeDeferral.kind, context: context) {
            return deferScheduledRest(scheduled, reason: reason, now: now, source: activeDeferral.source)
        }
        return startScheduledRest(
            scheduled,
            now: now,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        )
    }

    private mutating func startScheduledRest(
        _ scheduled: ScheduledRest,
        now: Date,
        idleDuration: TimeInterval = 0,
        preserveAwayCandidate: Bool = false
    ) -> RestEngineResult {
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
        let shouldPreserveAwayCandidate = preserveAwayCandidate &&
            isCurrentAwayCandidate(now: now, idleDuration: idleDuration)
        markNonWorkingEvaluation(
            now: now,
            idleDuration: idleDuration,
            preserveAwayCandidate: shouldPreserveAwayCandidate
        )
        return .started(session)
    }

    private mutating func deferScheduledRest(
        _ scheduled: ScheduledRest,
        reason: ContextDeferralReason,
        now: Date,
        source: RestDeferralSource = .scheduledDebt
    ) -> RestEngineResult {
        if let activeDeferral = state.activeDeferral,
           activeDeferral.kind == scheduled.kind,
           activeDeferral.reason == reason {
            state.activeDeferral?.lastSeenAt = now
            if source == .activeInterruption {
                state.activeDeferral?.source = source
            }
        } else {
            state.activeDeferral = RestDeferral(
                kind: scheduled.kind,
                reason: reason,
                source: source,
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
        let remaining = projectedCandidates(now: now)
            .first { $0.kind == activeDeferral.kind }?
            .remaining ?? .infinity
        if remaining > 0 {
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
        let idleDuration = max(0, context.idleDuration)
        updateAwayCandidateSnapshot(now: now, idleDuration: idleDuration)

        if isNaturallyAway(idleDuration: idleDuration) {
            restoreAwayCandidateDebts()
        } else {
            accrueComputerUseDebt(by: computerUseDelta(now: now), now: now)
        }
        normalizeDebtState()

        state.lastEvaluatedAt = now
        state.lastIdleDuration = idleDuration

        guard settings.naturalBreaks.isEnabled else {
            return []
        }
        let credited = settleNaturalAwayIfNeeded(idleDuration: idleDuration)
        if !credited.isEmpty {
            updateAwayCandidateDebtsToCurrentState()
        }
        return credited
    }

    private mutating func settleAwayWithoutAccrualIfNeeded(
        now: Date,
        idleDuration rawIdleDuration: TimeInterval,
        excluding excludedKinds: Set<RestKind> = []
    ) -> Set<RestKind> {
        let idleDuration = max(0, rawIdleDuration)
        updateAwayCandidateSnapshot(
            now: now,
            idleDuration: idleDuration,
            includingPreIdleComputerUse: false
        )
        if isNaturallyAway(idleDuration: idleDuration) {
            restoreAwayCandidateDebts()
        }
        normalizeDebtState()

        state.lastEvaluatedAt = now
        state.lastIdleDuration = idleDuration

        guard settings.naturalBreaks.isEnabled else {
            return []
        }
        let credited = settleNaturalAwayIfNeeded(idleDuration: idleDuration, excluding: excludedKinds)
        if !credited.isEmpty {
            updateAwayCandidateDebtsToCurrentState()
        }
        return credited
    }

    private func computerUseDelta(now: Date) -> TimeInterval {
        guard state.activeSession == nil,
              let lastEvaluatedAt = state.lastEvaluatedAt else {
            return 0
        }

        return max(0, now.timeIntervalSince(lastEvaluatedAt))
    }

    private mutating func updateAwayCandidateSnapshot(
        now: Date,
        idleDuration: TimeInterval,
        includingPreIdleComputerUse: Bool = true
    ) {
        guard idleDuration > 0 else {
            state.awayCandidate = nil
            return
        }

        let awayStartedAt = now.addingTimeInterval(-idleDuration)
        if let existing = state.awayCandidate,
           abs(existing.startedAt.timeIntervalSince(awayStartedAt)) < 2 {
            return
        }

        let activeDeltaBeforeIdle: TimeInterval
        if includingPreIdleComputerUse {
            activeDeltaBeforeIdle = state.lastEvaluatedAt.map { lastEvaluatedAt in
                max(0, awayStartedAt.timeIntervalSince(lastEvaluatedAt))
            } ?? 0
        } else {
            activeDeltaBeforeIdle = 0
        }
        let eyeDelta = isPaused(.eyeGate, at: now) ? 0 : activeDeltaBeforeIdle
        let bodyDelta = isPaused(.bodyBreak, at: now) ? 0 : activeDeltaBeforeIdle
        state.awayCandidate = AwayCandidateSnapshot(
            startedAt: awayStartedAt,
            eyeDebt: projectedDebt(state.eyeDebt, adding: eyeDelta, interval: settings.eyeGate.interval),
            bodyDebt: projectedDebt(state.bodyDebt, adding: bodyDelta, interval: settings.bodyBreak.interval)
        )
    }

    private func isCurrentAwayCandidate(now: Date, idleDuration: TimeInterval) -> Bool {
        guard idleDuration > 0,
              let awayCandidate = state.awayCandidate else {
            return false
        }

        let awayStartedAt = now.addingTimeInterval(-idleDuration)
        return abs(awayCandidate.startedAt.timeIntervalSince(awayStartedAt)) < 2
    }

    private func projectedDebt(_ debt: TimeInterval, adding delta: TimeInterval, interval: TimeInterval) -> TimeInterval {
        min(interval, max(0, debt) + max(0, delta))
    }

    private mutating func restoreAwayCandidateDebts() {
        guard let awayCandidate = state.awayCandidate else { return }
        state.eyeDebt = awayCandidate.eyeDebt
        state.bodyDebt = awayCandidate.bodyDebt
    }

    private mutating func updateAwayCandidateDebtsToCurrentState() {
        guard let awayCandidate = state.awayCandidate else { return }
        state.awayCandidate = AwayCandidateSnapshot(
            startedAt: awayCandidate.startedAt,
            eyeDebt: state.eyeDebt,
            bodyDebt: state.bodyDebt
        )
    }

    private mutating func updateAwayCandidateAfterCompletion(kind: RestKind) {
        guard let awayCandidate = state.awayCandidate else { return }
        switch kind {
        case .eyeGate:
            state.awayCandidate = AwayCandidateSnapshot(
                startedAt: awayCandidate.startedAt,
                eyeDebt: state.eyeDebt,
                bodyDebt: awayCandidate.bodyDebt
            )
        case .bodyBreak:
            state.awayCandidate = AwayCandidateSnapshot(
                startedAt: awayCandidate.startedAt,
                eyeDebt: state.eyeDebt,
                bodyDebt: state.bodyDebt
            )
        }
    }

    private mutating func accrueComputerUseDebt(by usageDelta: TimeInterval, now: Date) {
        if settings.eyeGate.isEnabled, !isPaused(.eyeGate, at: now) {
            state.eyeDebt = projectedDebt(state.eyeDebt, adding: usageDelta, interval: settings.eyeGate.interval)
        }
        if settings.bodyBreak.isEnabled, !isPaused(.bodyBreak, at: now) {
            state.bodyDebt = projectedDebt(state.bodyDebt, adding: usageDelta, interval: settings.bodyBreak.interval)
        }
    }

    private mutating func normalizeDebtState() {
        if !settings.eyeGate.isEnabled {
            state.eyeDebt = 0
        } else {
            state.eyeDebt = min(settings.eyeGate.interval, max(0, state.eyeDebt))
        }
        if !settings.bodyBreak.isEnabled {
            state.bodyDebt = 0
            state.bodySuppressedUntil = nil
        } else {
            state.bodyDebt = min(settings.bodyBreak.interval, max(0, state.bodyDebt))
        }
        if let awayCandidate = state.awayCandidate {
            state.awayCandidate = AwayCandidateSnapshot(
                startedAt: awayCandidate.startedAt,
                eyeDebt: settings.eyeGate.isEnabled ? min(settings.eyeGate.interval, awayCandidate.eyeDebt) : 0,
                bodyDebt: settings.bodyBreak.isEnabled ? min(settings.bodyBreak.interval, awayCandidate.bodyDebt) : 0
            )
        }
    }

    private mutating func markNonWorkingEvaluation(
        now: Date,
        idleDuration: TimeInterval,
        preserveAwayCandidate: Bool = false
    ) {
        state.lastEvaluatedAt = now
        state.lastIdleDuration = max(0, idleDuration)
        if !preserveAwayCandidate {
            state.awayCandidate = nil
        }
    }

    private func isAway(context: RestContext) -> Bool {
        return isNaturallyAway(idleDuration: context.idleDuration)
    }

    private func isNaturallyAway(idleDuration: TimeInterval) -> Bool {
        isLongIdle(idleDuration: idleDuration)
    }

    private func isLongIdle(idleDuration: TimeInterval) -> Bool {
        idleDuration >= naturalRecoveryThreshold
    }

    private var naturalRecoveryThreshold: TimeInterval {
        settings.naturalBreaks.inactivityResetTime
    }

    private func naturalSatisfactionThreshold(for kind: RestKind) -> TimeInterval {
        max(settings.rule(for: kind).duration, naturalRecoveryThreshold)
    }

    private func canNaturallyCompleteActive(_ session: RestSession, idleDuration: TimeInterval) -> Bool {
        settings.naturalBreaks.isEnabled && idleDuration >= max(session.duration, naturalRecoveryThreshold)
    }

    private func canAutomaticallyCompleteElapsedActive(_ session: RestSession, now: Date) -> Bool {
        !session.manualFinishEnabled && now.timeIntervalSince(session.startedAt) >= session.duration
    }

    private var bodyNaturalRecoveryThreshold: TimeInterval {
        naturalSatisfactionThreshold(for: .bodyBreak)
    }

    private mutating func settleNaturalAwayIfNeeded(
        idleDuration: TimeInterval,
        excluding excludedKinds: Set<RestKind> = []
    ) -> Set<RestKind> {
        var credited = Set<RestKind>()
        if !excludedKinds.contains(.eyeGate),
           settings.eyeGate.isEnabled,
           idleDuration >= naturalSatisfactionThreshold(for: .eyeGate),
           state.eyeDebt > 0 {
            state.eyeDebt = 0
            incrementCompleted(.eyeGate)
            incrementNatural(.eyeGate)
            decreaseDanger(for: .eyeGate)
            credited.insert(.eyeGate)
        }
        if !excludedKinds.contains(.bodyBreak),
           settings.bodyBreak.isEnabled,
           idleDuration >= bodyNaturalRecoveryThreshold,
           state.bodyDebt > 0 {
            state.bodyDebt = 0
            state.bodySuppressedUntil = nil
            state.postponesInCurrentCycle = 0
            incrementCompleted(.bodyBreak)
            incrementNatural(.bodyBreak)
            decreaseDanger(for: .bodyBreak)
            credited.insert(.bodyBreak)
            if !excludedKinds.contains(.eyeGate),
               settings.eyeGate.isEnabled,
               state.eyeDebt > 0 || state.activeDeferral?.kind == .eyeGate {
                state.eyeDebt = 0
                credited.insert(.eyeGate)
            }
        }
        return credited
    }

    private mutating func completeActiveAfterNaturalAway(now: Date, idleDuration: TimeInterval) -> RestEngineResult {
        guard let active = state.activeSession else {
            return .denied(.noActiveSession)
        }
        if isCurrentAwayCandidate(now: now, idleDuration: idleDuration) {
            restoreAwayCandidateDebts()
        } else {
            state.awayCandidate = nil
        }
        normalizeDebtState()
        let credited = settleNaturalAwayIfNeeded(idleDuration: idleDuration, excluding: [active.kind])
        if !credited.isEmpty {
            clearDeferrals(satisfiedBy: credited)
        }
        let result = completeActive(now: now, reason: .natural)
        if !credited.isEmpty {
            refreshProjectedSchedule(now: now)
        }
        return result
    }

    private mutating func refreshProjectedSchedule(
        now: Date,
        preserveNotificationStateFrom previous: ScheduledRest? = nil
    ) {
        guard state.activeSession == nil else {
            state.scheduled = nil
            state.activeDeferral = nil
            return
        }

        guard !activePauseBlocksAllEnabledRests(at: now) else {
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
           let activeDeferral = state.activeDeferral,
           activeDeferral.kind == next.kind,
           previous.kind == next.kind,
           previous.dueAt <= now,
           next.dueAt <= now {
            next = previous
        } else if let previous,
           shouldPreserveNotificationSent(from: previous, to: next, now: now) {
            next.notificationSent = true
        }
        state.scheduled = next
        if let activeDeferral = state.activeDeferral,
           (!settings.rule(for: activeDeferral.kind).isEnabled || isPaused(activeDeferral.kind, at: now)) {
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
        if settings.eyeGate.isEnabled, !isPaused(.eyeGate, at: now) {
            candidates.append((
                .eyeGate,
                max(0, settings.eyeGate.interval - state.eyeDebt),
                1
            ))
        }
        if settings.bodyBreak.isEnabled, !isPaused(.bodyBreak, at: now) {
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
