import Foundation

public struct SettingsStore: Sendable {
    private static let legacyEmergencyTimingKey = Data(#""minimumHoldDuration""#.utf8)

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
        let normalized = decoded.normalizedForCurrentDesign()
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
}
