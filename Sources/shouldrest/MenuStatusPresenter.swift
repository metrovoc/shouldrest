import Foundation
import ShouldRestCore

enum MenuStatusPresenter {
    enum MenuBarIcon: Equatable {
        case restGate
        case restGateWithHealthIndicator
        case systemSymbol(String)
        case systemSymbolWithHealthIndicator(String)

        var fallbackSystemSymbolName: String {
            switch self {
            case .restGate, .restGateWithHealthIndicator:
                return "pause.rectangle"
            case .systemSymbol(let symbolName), .systemSymbolWithHealthIndicator(let symbolName):
                return symbolName
            }
        }

        var withHealthIndicator: MenuBarIcon {
            switch self {
            case .restGate, .restGateWithHealthIndicator:
                return .restGateWithHealthIndicator
            case .systemSymbol(let symbolName), .systemSymbolWithHealthIndicator(let symbolName):
                return .systemSymbolWithHealthIndicator(symbolName)
            }
        }
    }

    struct HeaderContent: Equatable {
        var title: String
        var primary: String
        var secondary: String?
        var healthBadge: String?
        var icon: MenuBarIcon
    }

    static func lines(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> [String] {
        var lines = [primaryStatusText(state: state, now: now)]
        if let active = state.activeSession {
            lines.append(activeSecondaryStatusText(active, settings: settings, now: now))
            return lines
        }
        if let pause = state.pause {
            lines.append(pauseSecondaryStatusText(pause, now: now))
            return lines
        }
        if state.activeDeferral != nil {
            lines.append(deferralSecondaryStatusText())
            return lines
        }
        if let bodyBreakStatus = nextBodyBreakStatusText(state: state, settings: settings) {
            lines.append(bodyBreakStatus)
        }
        return lines
    }

    static func tooltip(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> String {
        var tooltipLines = lines(state: state, settings: settings, now: now)
        if settings.presentation.breakHealthMode {
            tooltipLines.append(L10n.format("status.health", state.dangerScore))
        }
        return L10n.tr("status.tooltipHeader") + "\n\n" + tooltipLines.joined(separator: "\n")
    }

    static func menuBarAccessibilityDescription(
        state: RestEngineState,
        settings: RestSettings,
        now: Date = Date()
    ) -> String {
        var parts = lines(state: state, settings: settings, now: now)
        if let healthBadge = healthBadgeText(state: state, settings: settings) {
            parts.append(healthBadge)
        }
        return "\(L10n.tr("app.name")): \(parts.joined(separator: ". "))"
    }

    static func headerContent(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> HeaderContent {
        let statusLines = lines(state: state, settings: settings, now: now)
        return HeaderContent(
            title: L10n.tr("app.name"),
            primary: statusLines.first ?? L10n.tr("status.noRests"),
            secondary: statusLines.dropFirst().first,
            healthBadge: healthBadgeText(state: state, settings: settings),
            icon: menuBarIcon(state: state)
        )
    }

    static func menuBarTitle(state _: RestEngineState, settings _: RestSettings, now _: Date = Date()) -> String {
        ""
    }

    static func menuBarSymbolName(state: RestEngineState) -> String {
        menuBarIcon(state: state).fallbackSystemSymbolName
    }

    static func menuBarIcon(state: RestEngineState) -> MenuBarIcon {
        if let active = state.activeSession {
            return icon(for: active.kind)
        }
        if state.pause != nil {
            return .systemSymbol("pause.circle")
        }
        if state.activeDeferral != nil {
            return .systemSymbol("clock")
        }
        if let scheduled = state.scheduled {
            return icon(for: scheduled.kind)
        }
        return icon(for: .eyeGate)
    }

    static func menuBarIcon(state: RestEngineState, settings: RestSettings) -> MenuBarIcon {
        let icon = menuBarIcon(state: state)
        guard settings.presentation.breakHealthMode, state.dangerScore > 0 else {
            return icon
        }
        return icon.withHealthIndicator
    }

    static func deferralReasonText(_ reason: ContextDeferralReason) -> String {
        switch reason {
        case .outsideWorkingHours:
            return L10n.tr("deferral.outsideWorkingHours")
        case .focusMode:
            return L10n.tr("deferral.focusMode")
        case .appExclusion(let name):
            return L10n.format("deferral.appExclusion", name)
        }
    }

    static func restKindName(_ kind: RestKind) -> String {
        switch kind {
        case .eyeGate:
            return L10n.tr("kind.eyeGate")
        case .bodyBreak:
            return L10n.tr("kind.bodyBreak")
        }
    }

    private static func icon(for kind: RestKind) -> MenuBarIcon {
        switch kind {
        case .eyeGate:
            return .restGate
        case .bodyBreak:
            return .systemSymbol("figure.walk")
        }
    }

    private static func healthBadgeText(state: RestEngineState, settings: RestSettings) -> String? {
        guard settings.presentation.breakHealthMode, state.dangerScore > 0 else {
            return nil
        }
        return L10n.format("status.healthBadge", state.dangerScore)
    }

    private static func primaryStatusText(state: RestEngineState, now: Date) -> String {
        if let active = state.activeSession {
            if isManualFinishReady(active, now: now) {
                return L10n.format("status.readyToFinish", restKindName(active.kind))
            }
            let remaining = max(0, Int(active.duration - now.timeIntervalSince(active.startedAt)))
            return L10n.format("status.active", restKindName(active.kind), activeRemainingText(seconds: remaining))
        }
        if let pause = state.pause {
            if let until = pause.until {
                return L10n.format("status.pausedUntil", until.formatted(date: .omitted, time: .shortened))
            }
            return L10n.tr("status.pausedIndefinitely")
        }
        if let deferral = state.activeDeferral {
            return L10n.format(
                "status.deferred",
                restKindName(deferral.kind),
                deferralReasonText(deferral.reason)
            )
        }
        if let scheduled = state.scheduled {
            let seconds = max(0, Int(ceil(scheduled.dueAt.timeIntervalSince(now))))
            return L10n.format(
                "status.nextWithCountdown",
                restKindName(scheduled.kind),
                compactDurationText(seconds: seconds),
                scheduled.dueAt.formatted(date: .omitted, time: .shortened)
            )
        }
        return L10n.tr("status.noRests")
    }

    private static func isManualFinishReady(_ session: RestSession, now: Date) -> Bool {
        session.manualFinishEnabled && now.timeIntervalSince(session.startedAt) >= session.duration
    }

    private static func activeSecondaryStatusText(_ session: RestSession, settings: RestSettings, now: Date) -> String {
        switch session.kind {
        case .eyeGate:
            if isManualFinishReady(session, now: now) {
                return L10n.tr("status.eyeGateReadyGuidance")
            }
            guard settings.eyeGate.emergencyOverride.isEnabled else {
                return L10n.tr("status.eyeGateActiveNoEmergencyGuidance")
            }
            return L10n.tr("status.eyeGateActiveGuidance")
        case .bodyBreak:
            if isManualFinishReady(session, now: now) {
                return L10n.tr("status.bodyBreakReadyGuidance")
            }
            return L10n.tr("status.bodyBreakActiveGuidance")
        }
    }

    private static func pauseSecondaryStatusText(_ pause: PauseState, now: Date) -> String {
        let reason = pauseReasonText(pause.reason)
        guard let until = pause.until else {
            return L10n.format("status.pauseResumeManualWithReason", reason)
        }
        let seconds = max(0, Int(ceil(until.timeIntervalSince(now))))
        return L10n.format("status.pauseResumesInWithReason", reason, compactDurationText(seconds: seconds))
    }

    private static func pauseReasonText(_ reason: PauseReason) -> String {
        switch reason {
        case .user:
            return L10n.tr("status.pauseReason.user")
        case .untilMorning:
            return L10n.tr("status.pauseReason.untilMorning")
        case .suspendOrLock:
            return L10n.tr("status.pauseReason.suspendOrLock")
        case .appExclusion:
            return L10n.tr("status.pauseReason.appExclusion")
        case .focusMode:
            return L10n.tr("status.pauseReason.focusMode")
        }
    }

    private static func deferralSecondaryStatusText() -> String {
        L10n.tr("status.deferralGuidance")
    }

    private static func activeRemainingText(seconds: Int) -> String {
        guard seconds >= 60 else {
            return L10n.format("status.durationSeconds", max(0, seconds))
        }
        return compactDurationText(seconds: seconds)
    }

    private static func compactDurationText(seconds: Int) -> String {
        guard seconds >= 60 else {
            return L10n.tr("status.durationUnderMinute")
        }

        let minutes = Int(ceil(Double(seconds) / 60))
        guard minutes >= 60 else {
            return L10n.format("status.durationMinutes", minutes)
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return L10n.format("status.durationHours", hours)
        }
        return L10n.format("status.durationHoursMinutes", hours, remainingMinutes)
    }

    private static func nextBodyBreakStatusText(state: RestEngineState, settings: RestSettings) -> String? {
        guard settings.eyeGate.isEnabled,
              settings.bodyBreak.isEnabled,
              state.activeSession == nil,
              state.pause == nil,
              state.activeDeferral == nil,
              state.scheduled?.kind == .eyeGate else {
            return nil
        }
        let remainingEyeGates = max(1, settings.bodyBreakAfterEyeGates - state.eyeGatesSinceBodyBreak)
        if remainingEyeGates == 1 {
            return L10n.tr("status.nextBodyAfterOneEyeGate")
        }
        return L10n.format("status.nextBodyAfterEyeGates", remainingEyeGates)
    }
}
