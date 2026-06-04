import Foundation
import ShouldRestCore

enum RestRhythmPreset: Int, CaseIterable, Equatable {
    case recommended
    case frequentEye
    case movement

    static let firstRunDefault: RestRhythmPreset = .frequentEye

    var identifier: String {
        switch self {
        case .recommended:
            "recommended"
        case .frequentEye:
            "frequentEye"
        case .movement:
            "movement"
        }
    }

    var titleKey: String {
        "prefs.rhythmPreset.\(identifier)"
    }

    var helpKey: String {
        "prefs.rhythmPreset.\(identifier)Help"
    }

    var title: String {
        L10n.tr(titleKey)
    }

    var help: String {
        L10n.tr(helpKey)
    }

    var symbolName: String {
        switch self {
        case .recommended:
            "timer"
        case .frequentEye:
            "eye"
        case .movement:
            "figure.walk"
        }
    }

    var eyeIntervalMinutes: Int {
        switch self {
        case .recommended, .movement:
            20
        case .frequentEye:
            10
        }
    }

    var eyeDurationSeconds: Int {
        20
    }

    var bodyIntervalMinutes: Int {
        20
    }

    var bodyAfterEyeGateCount: Int {
        switch self {
        case .recommended, .movement:
            2
        case .frequentEye:
            4
        }
    }

    var bodyDurationMinutes: Int {
        switch self {
        case .recommended, .frequentEye:
            5
        case .movement:
            8
        }
    }

    func apply(to settings: inout RestSettings) {
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = true
        settings.eyeGate.interval = TimeInterval(eyeIntervalMinutes * 60)
        settings.eyeGate.duration = TimeInterval(eyeDurationSeconds)
        settings.bodyBreak.interval = TimeInterval(bodyIntervalMinutes * 60)
        settings.bodyBreakAfterEyeGates = bodyAfterEyeGateCount
        settings.bodyBreak.duration = TimeInterval(bodyDurationMinutes * 60)
    }
}
