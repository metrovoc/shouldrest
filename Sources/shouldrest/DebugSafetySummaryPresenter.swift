import Foundation
import ShouldRestCore

enum DebugSafetySummaryPresenter {
    static func summary(
        state: RestEngineState,
        settings _: RestSettings,
        now: Date = Date()
    ) -> DebugSafetySummary {
        if let active = state.activeSession {
            switch active.kind {
            case .eyeGate:
                if active.manualFinishEnabled && now.timeIntervalSince(active.startedAt) >= active.duration {
                    return DebugSafetySummary(
                        title: L10n.tr("debug.summaryEyeReadyTitle"),
                        body: L10n.tr("debug.summaryEyeReadyBody"),
                        symbolName: "checkmark.circle",
                        severity: .warning
                    )
                }
                return DebugSafetySummary(
                    title: L10n.tr("debug.summaryEyeActiveTitle"),
                    body: L10n.tr("debug.summaryEyeActiveBody"),
                    symbolName: "exclamationmark.shield",
                    severity: .active
                )
            case .bodyBreak:
                if active.manualFinishEnabled && now.timeIntervalSince(active.startedAt) >= active.duration {
                    return DebugSafetySummary(
                        title: L10n.tr("debug.summaryBodyReadyTitle"),
                        body: L10n.tr("debug.summaryBodyReadyBody"),
                        symbolName: "checkmark.circle",
                        severity: .warning
                    )
                }
                return DebugSafetySummary(
                    title: L10n.tr("debug.summaryBodyActiveTitle"),
                    body: L10n.tr("debug.summaryBodyActiveBody"),
                    symbolName: "figure.walk.circle",
                    severity: .warning
                )
            }
        }

        if state.pause != nil {
            return DebugSafetySummary(
                title: L10n.tr("debug.summaryPausedTitle"),
                body: L10n.tr("debug.summaryPausedBody"),
                symbolName: "pause.circle",
                severity: .warning
            )
        }

        if let deferral = state.activeDeferral {
            return DebugSafetySummary(
                title: L10n.format("debug.summaryDeferredTitle", MenuStatusPresenter.restKindName(deferral.kind)),
                body: L10n.format("debug.summaryDeferredBody", MenuStatusPresenter.deferralReasonText(deferral.reason)),
                symbolName: "clock.badge.exclamationmark",
                severity: .warning
            )
        }

        if let scheduled = state.scheduled {
            return DebugSafetySummary(
                title: L10n.tr("debug.summaryScheduledTitle"),
                body: L10n.format(
                    "debug.summaryScheduledBody",
                    MenuStatusPresenter.restKindName(scheduled.kind),
                    scheduled.dueAt.formatted(date: .omitted, time: .shortened)
                ),
                symbolName: "calendar.badge.clock",
                severity: .ready
            )
        }

        return .ready
    }
}
