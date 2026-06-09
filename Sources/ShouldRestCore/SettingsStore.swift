import Foundation

public struct SettingsStore: Sendable {
    private static let legacyEmergencyTimingKey = Data(#""minimumHoldDuration""#.utf8)
    private static let legacyBodyBreakAfterEyeGatesKey = Data(#""bodyBreakAfterEyeGates""#.utf8)
    private static let leakedIndependentBodyDefaultInterval: TimeInterval = 20 * 60
    private static let legacyInactivityResetTime: TimeInterval = 5 * 60

    public var fileURL: URL
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> RestSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }
        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode(RestSettings.self, from: data)
        let migrated = Self.migratingLegacyRhythmDefaultsIfNeeded(decoded, rawData: data)
        let normalized = migrated.normalizedForCurrentDesign()
        let normalizedData = try encoder.encode(normalized)
        if decoded != normalized ||
            data != normalizedData ||
            data.range(of: Self.legacyEmergencyTimingKey) != nil {
            try? write(normalizedData)
        }
        return normalized
    }

    public func save(_ settings: RestSettings) throws {
        let data = try encoder.encode(settings.normalizedForCurrentDesign())
        try write(data)
    }

    private func write(_ data: Data) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func migratingLegacyRhythmDefaultsIfNeeded(
        _ settings: RestSettings,
        rawData: Data
    ) -> RestSettings {
        let needsRhythmMigration = rawData.range(of: legacyBodyBreakAfterEyeGatesKey) != nil ||
            hasLeakedIndependentBodyDefault(in: settings) ||
            hasLegacyBodyBreakDefault(in: settings)

        var migrated = settings
        if migrated.naturalBreaks.inactivityResetTime == legacyInactivityResetTime {
            migrated.naturalBreaks.inactivityResetTime = NaturalBreakSettings.defaults.inactivityResetTime
        }

        guard needsRhythmMigration else {
            return migrated
        }

        if migrated.eyeGate.isEnabled,
           migrated.eyeGate.interval == 10 * 60,
           migrated.eyeGate.duration == RestRule.eyeGateDefault.duration {
            migrated.eyeGate.interval = RestRule.eyeGateDefault.interval
        }
        if migrated.bodyBreak.interval == leakedIndependentBodyDefaultInterval {
            migrated.bodyBreak.interval = RestRule.bodyBreakDefault.interval
        }
        if migrated.bodyBreak.duration == 5 * 60 {
            migrated.bodyBreak.duration = RestRule.bodyBreakDefault.duration
        }
        if migrated.bodyBreak.manualFinishEnabled {
            migrated.bodyBreak.manualFinishEnabled = RestRule.bodyBreakDefault.manualFinishEnabled
        }
        return migrated
    }

    private static func hasLeakedIndependentBodyDefault(in settings: RestSettings) -> Bool {
        settings.eyeGate.isEnabled &&
            settings.eyeGate.interval == RestRule.eyeGateDefault.interval &&
            settings.eyeGate.duration == RestRule.eyeGateDefault.duration &&
            settings.bodyBreak.interval == leakedIndependentBodyDefaultInterval &&
            settings.bodyBreak.duration == RestRule.bodyBreakDefault.duration &&
            settings.bodyBreak.manualFinishEnabled == RestRule.bodyBreakDefault.manualFinishEnabled &&
            (
                settings.naturalBreaks.inactivityResetTime == NaturalBreakSettings.defaults.inactivityResetTime ||
                    settings.naturalBreaks.inactivityResetTime == legacyInactivityResetTime
            )
    }

    private static func hasLegacyBodyBreakDefault(in settings: RestSettings) -> Bool {
        settings.bodyBreak.interval == leakedIndependentBodyDefaultInterval &&
            settings.bodyBreak.duration == 5 * 60 &&
            settings.bodyBreak.manualFinishEnabled
    }
}
