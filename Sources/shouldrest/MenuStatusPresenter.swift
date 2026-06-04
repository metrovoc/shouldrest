import Foundation
import ShouldRestCore

enum MenuStatusPresenter {
    enum MenuBarIcon: Equatable {
        case restGate
        case systemSymbol(String)

        var fallbackSystemSymbolName: String {
            switch self {
            case .restGate:
                return "viewfinder"
            case .systemSymbol(let symbolName):
                return symbolName
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
        if let pause = state.pause {
            lines.append(pauseSecondaryStatusText(pause, now: now))
            return lines
        }
        if let bodyBreakStatus = nextBodyBreakStatusText(state: state, settings: settings) {
            lines.append(bodyBreakStatus)
        }
        return lines
    }

    static func tooltip(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> String {
        L10n.tr("status.tooltipHeader") + "\n\n" + lines(state: state, settings: settings, now: now).joined(separator: "\n")
    }

    static func headerContent(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> HeaderContent {
        let statusLines = lines(state: state, settings: settings, now: now)
        return HeaderContent(
            title: L10n.tr("app.name"),
            primary: statusLines.first ?? L10n.tr("status.noRests"),
            secondary: statusLines.dropFirst().first,
            healthBadge: settings.presentation.breakHealthMode ? L10n.format("status.healthBadge", state.dangerScore) : nil,
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

    private static func primaryStatusText(state: RestEngineState, now: Date) -> String {
        if let active = state.activeSession {
            if isManualFinishReady(active, now: now) {
                return L10n.format("status.readyToFinish", restKindName(active.kind))
            }
            let remaining = max(0, Int(active.duration - now.timeIntervalSince(active.startedAt)))
            return L10n.format("status.active", restKindName(active.kind), remaining)
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
            return L10n.format(
                "status.next",
                restKindName(scheduled.kind),
                scheduled.dueAt.formatted(date: .omitted, time: .shortened)
            )
        }
        return L10n.tr("status.noRests")
    }

    private static func isManualFinishReady(_ session: RestSession, now: Date) -> Bool {
        session.manualFinishEnabled && now.timeIntervalSince(session.startedAt) >= session.duration
    }

    private static func pauseSecondaryStatusText(_ pause: PauseState, now: Date) -> String {
        guard let until = pause.until else {
            return L10n.tr("status.pauseResumeManual")
        }
        let seconds = max(0, Int(ceil(until.timeIntervalSince(now))))
        return L10n.format("status.pauseResumesIn", compactDurationText(seconds: seconds))
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
        return L10n.format("status.nextBodyAfterEyeGates", remainingEyeGates)
    }
}
