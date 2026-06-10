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
        return SoundResourceLocator.url(named: bundledResourceName)
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

enum SoundResourceLocator {
    static let resourceBundleName = AppResourceLocator.resourceBundleName

    static func url(named name: String, bundle: Bundle = .main) -> URL? {
        for candidate in candidateURLs(named: name, bundle: bundle) where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    static func candidateURLs(named name: String, bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        if let rootAudio = bundle.url(forResource: name, withExtension: "wav", subdirectory: "audio") {
            urls.append(rootAudio)
        }
        if let root = bundle.url(forResource: name, withExtension: "wav") {
            urls.append(root)
        }
        for resourceBundleURL in AppResourceLocator.resourceBundleURLs(bundle: bundle) {
            if let resourceBundle = Bundle(url: resourceBundleURL) {
                if let bundleAudio = resourceBundle.url(forResource: name, withExtension: "wav", subdirectory: "audio") {
                    urls.append(bundleAudio)
                }
                if let bundleRoot = resourceBundle.url(forResource: name, withExtension: "wav") {
                    urls.append(bundleRoot)
                }
            } else {
                urls.append(resourceBundleURL.appendingPathComponent("audio/\(name).wav"))
                urls.append(resourceBundleURL.appendingPathComponent("\(name).wav"))
            }
        }
        return urls
    }
}
