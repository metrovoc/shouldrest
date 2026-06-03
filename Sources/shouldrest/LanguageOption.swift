import Foundation

enum LanguageOption: CaseIterable, Equatable {
    case system
    case english
    case simplifiedChinese

    init(identifier: String?) {
        switch identifier?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "en":
            self = .english
        case "zh-Hans":
            self = .simplifiedChinese
        default:
            self = .system
        }
    }

    init(popupValue: String?) {
        self.init(identifier: popupValue)
    }

    var identifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    var popupValue: String {
        identifier ?? ""
    }

    var title: String {
        switch self {
        case .system:
            L10n.tr("prefs.language.system")
        case .english:
            L10n.tr("prefs.language.english")
        case .simplifiedChinese:
            L10n.tr("prefs.language.simplifiedChinese")
        }
    }
}
