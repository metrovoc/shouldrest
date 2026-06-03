import Foundation

enum L10n {
    nonisolated(unsafe) static var languageOverride: String?

    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: languageBundle ?? defaultBundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: arguments)
    }

    private static var languageBundle: Bundle? {
        guard let languageOverride,
              !languageOverride.isEmpty else {
            return nil
        }
        if let bundle = localizedBundle(for: languageOverride, in: .main) {
            return bundle
        }
        return localizedBundle(for: languageOverride, in: .module)
    }

    private static var defaultBundle: Bundle {
        hasLocalizations(in: .main) ? .main : .module
    }

    private static func localizedBundle(for identifier: String, in bundle: Bundle) -> Bundle? {
        for candidate in [identifier, identifier.lowercased()] {
            if let path = bundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    private static func hasLocalizations(in bundle: Bundle) -> Bool {
        bundle.path(forResource: "en", ofType: "lproj") != nil ||
            bundle.path(forResource: "zh-hans", ofType: "lproj") != nil ||
            bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
    }
}
