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

        let scheduledKind = state.scheduled?.kind
        var actions: [StatusMenuStartAction] = []
        if let scheduledKind {
            actions.append(.nextScheduled(scheduledKind))
        }
        if settings.eyeGate.isEnabled && scheduledKind != .eyeGate {
            actions.append(.eyeGate)
        }
        if settings.bodyBreak.isEnabled && scheduledKind != .bodyBreak {
            actions.append(.bodyBreak)
        }
        return actions
    }
}
