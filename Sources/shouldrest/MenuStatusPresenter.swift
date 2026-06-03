import Foundation
import ShouldRestCore

enum MenuStatusPresenter {
    static func lines(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> [String] {
        var lines = [primaryStatusText(state: state, now: now)]
        if let bodyBreakStatus = nextBodyBreakStatusText(state: state, settings: settings) {
            lines.append(bodyBreakStatus)
        }
        return lines
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

    private static func primaryStatusText(state: RestEngineState, now: Date) -> String {
        if let active = state.activeSession {
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
