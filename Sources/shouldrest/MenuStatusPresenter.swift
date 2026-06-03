import Foundation
import ShouldRestCore

enum MenuStatusPresenter {
    enum MenuBarIcon: Equatable {
        case restGate
        case systemSymbol(String)

        var fallbackSystemSymbolName: String {
            switch self {
            case .restGate:
                return "pause.circle"
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

    static func menuBarTitle(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> String {
        switch settings.presentation.trayIconStyle {
        case .default:
            return ""
        case .appName:
            return "SR"
        case .timeToBreak:
            return compactMenuBarDuration(state: state, now: now) ?? ""
        case .progress:
            guard let duration = compactMenuBarDuration(state: state, now: now),
                  let kind = state.activeSession?.kind ?? state.scheduled?.kind else {
                return ""
            }
            return "\(compactRestKindName(kind)) \(duration)"
        }
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

    private static func compactRestKindName(_ kind: RestKind) -> String {
        switch kind {
        case .eyeGate:
            return L10n.tr("kind.eyeGateShort")
        case .bodyBreak:
            return L10n.tr("kind.bodyBreakShort")
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

    private static func compactMenuBarDuration(state: RestEngineState, now: Date) -> String? {
        if let active = state.activeSession {
            let seconds = max(0, Int(ceil(active.duration - now.timeIntervalSince(active.startedAt))))
            return compactDuration(seconds: seconds)
        }
        guard state.pause == nil, state.activeDeferral == nil else {
            return nil
        }
        guard let scheduled = state.scheduled else { return nil }
        let seconds = max(0, Int(ceil(scheduled.dueAt.timeIntervalSince(now))))
        return compactDuration(seconds: seconds)
    }

    private static func compactDuration(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        if seconds < 60 * 60 {
            return "\(Int(ceil(Double(seconds) / 60.0)))m"
        }
        return "\(Int(ceil(Double(seconds) / 3600.0)))h"
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
