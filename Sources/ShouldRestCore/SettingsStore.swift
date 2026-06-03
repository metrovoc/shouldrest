import Foundation

public struct SettingsStore: Sendable {
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
        return try decoder.decode(RestSettings.self, from: data).enforcingAtLeastOneEnabledRest()
    }

    public func save(_ settings: RestSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(settings.enforcingAtLeastOneEnabledRest())
        try data.write(to: fileURL, options: [.atomic])
    }
}
