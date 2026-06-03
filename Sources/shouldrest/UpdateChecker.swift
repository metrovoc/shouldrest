import Foundation

struct UpdateCheckResult: Equatable {
    enum Status: Equatable {
        case notConfigured
        case upToDate
        case newerVersion(String)
        case failed(String)
    }

    var status: Status
    var releaseURL: URL?
}

final class UpdateChecker: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(feedURL: String, currentVersion: String) async -> UpdateCheckResult {
        guard let url = URL(string: feedURL), !feedURL.isEmpty else {
            return UpdateCheckResult(status: .notConfigured, releaseURL: nil)
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return UpdateCheckResult(status: .failed("Invalid update response"), releaseURL: nil)
            }

            let tag = (object["tag_name"] as? String) ?? (object["version"] as? String) ?? ""
            let releaseURL = (object["html_url"] as? String).flatMap(URL.init(string:))
            guard !tag.isEmpty else {
                return UpdateCheckResult(status: .failed("No version in update response"), releaseURL: releaseURL)
            }

            if Self.isVersion(tag, newerThan: currentVersion) {
                return UpdateCheckResult(status: .newerVersion(tag), releaseURL: releaseURL)
            }
            return UpdateCheckResult(status: .upToDate, releaseURL: releaseURL)
        } catch {
            return UpdateCheckResult(status: .failed(error.localizedDescription), releaseURL: nil)
        }
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let left = components(candidate)
        let right = components(current)
        for index in 0..<max(left.count, right.count) {
            let lhs = index < left.count ? left[index] : 0
            let rhs = index < right.count ? right[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}
