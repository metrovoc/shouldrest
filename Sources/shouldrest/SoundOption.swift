import Foundation

enum SoundOption: Equatable {
    case silence
    case crystalGlass
    case windChime
    case ticToc
    case reverie
    case custom(String)

    static let builtIn: [SoundOption] = [
        .silence,
        .crystalGlass,
        .windChime,
        .ticToc,
        .reverie
    ]

    init(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "", "silence":
            self = .silence
        case "crystal-glass":
            self = .crystalGlass
        case "wind-chime":
            self = .windChime
        case "tic-toc":
            self = .ticToc
        case "reverie":
            self = .reverie
        default:
            self = .custom(trimmed)
        }
    }

    var name: String {
        switch self {
        case .silence:
            "silence"
        case .crystalGlass:
            "crystal-glass"
        case .windChime:
            "wind-chime"
        case .ticToc:
            "tic-toc"
        case .reverie:
            "reverie"
        case .custom(let name):
            name
        }
    }

    var bundledResourceName: String? {
        switch self {
        case .silence, .custom:
            nil
        case .crystalGlass, .windChime, .ticToc, .reverie:
            name
        }
    }

    var bundledResourceURL: URL? {
        guard let bundledResourceName else { return nil }
        return Bundle.module.url(forResource: bundledResourceName, withExtension: "wav", subdirectory: "audio")
            ?? Bundle.module.url(forResource: bundledResourceName, withExtension: "wav")
    }

    var title: String {
        switch self {
        case .silence:
            L10n.tr("prefs.sound.silence")
        case .crystalGlass:
            L10n.tr("prefs.sound.crystalGlass")
        case .windChime:
            L10n.tr("prefs.sound.windChime")
        case .ticToc:
            L10n.tr("prefs.sound.ticToc")
        case .reverie:
            L10n.tr("prefs.sound.reverie")
        case .custom(let name):
            L10n.format("prefs.sound.custom", name)
        }
    }
}
