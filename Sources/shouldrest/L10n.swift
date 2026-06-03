import Foundation

enum L10n {
    nonisolated(unsafe) static var languageOverride: String?

    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: languageBundle ?? .module, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: arguments)
    }

    private static var languageBundle: Bundle? {
        guard let languageOverride,
              !languageOverride.isEmpty else {
            return nil
        }
        for candidate in [languageOverride, languageOverride.lowercased()] {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }
}
