import Foundation
import ShouldRestCore

enum StatusMenuStartAction: Equatable {
    case nextScheduled(RestKind)
    case eyeGate
    case bodyBreak

    var title: String {
        switch self {
        case .nextScheduled(let kind):
            StatusMenuActionCopy.nextScheduledRestTitle(kind: kind)
        case .eyeGate:
            L10n.tr("menu.takeEyeGateNow")
        case .bodyBreak:
            L10n.tr("menu.takeBodyBreakNow")
        }
    }
}

enum StatusMenuStartActionPlanner {
    static func actions(state: RestEngineState, settings: RestSettings) -> [StatusMenuStartAction] {
        guard state.activeSession == nil else { return [] }
        if let pause = state.pause,
           pauseCoversAllEnabledRests(pause, settings: settings) {
            return []
        }

        let scheduledKind = state.scheduled?.kind
        var actions: [StatusMenuStartAction] = []
        if let scheduledKind {
            actions.append(.nextScheduled(scheduledKind))
        }
        if settings.eyeGate.isEnabled,
           scheduledKind != .eyeGate,
           state.pause?.applies(to: .eyeGate) != true {
            actions.append(.eyeGate)
        }
        if settings.bodyBreak.isEnabled,
           scheduledKind != .bodyBreak,
           state.pause?.applies(to: .bodyBreak) != true {
            actions.append(.bodyBreak)
        }
        return actions
    }

    private static func pauseCoversAllEnabledRests(_ pause: PauseState, settings: RestSettings) -> Bool {
        let enabledKinds = RestKind.allCases.filter { settings.rule(for: $0).isEnabled }
        guard !enabledKinds.isEmpty else { return false }
        return enabledKinds.allSatisfy { pause.applies(to: $0) }
    }
}
