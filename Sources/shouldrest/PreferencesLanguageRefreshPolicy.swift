import Foundation
import ShouldRestCore

enum PreferencesTabTarget {
    case schedule
    case context
    case appearance
    case shortcuts
    case advanced

    var localizedIdentifier: String {
        switch self {
        case .schedule:
            L10n.tr("prefs.tabSchedule")
        case .context:
            L10n.tr("prefs.tabContext")
        case .appearance:
            L10n.tr("prefs.tabAppearance")
        case .shortcuts:
            L10n.tr("prefs.tabShortcuts")
        case .advanced:
            L10n.tr("prefs.tabAdvanced")
        }
    }
}

enum PreferencesLanguageRefreshPolicy {
    static func shouldRefreshPreferences(
        previousSettings: RestSettings,
        nextSettings: RestSettings,
        isPreferencesWindowVisible: Bool
    ) -> Bool {
        guard isPreferencesWindowVisible else { return false }
        return normalizedLanguageIdentifier(previousSettings) != normalizedLanguageIdentifier(nextSettings)
    }

    private static func normalizedLanguageIdentifier(_ settings: RestSettings) -> String? {
        LanguageOption(identifier: settings.presentation.languageIdentifier).identifier
    }
}
