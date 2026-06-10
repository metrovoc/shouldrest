import Foundation

enum AppResourceLocator {
    static let resourceBundleName = "ShouldRest_shouldrest.bundle"
    private static let commonLanguageIdentifiers = ["en", "zh-Hans", "zh-hans"]

    static func resourceBundleURLs(bundle: Bundle = .main) -> [URL] {
        if bundle.bundleURL == Bundle.main.bundleURL {
            return cachedMainResourceBundleURLs
        }
        return resourceBundleURLsUncached(bundle: bundle)
    }

    static func localizedBundle(for identifier: String, bundle: Bundle = .main) -> Bundle? {
        if bundle.bundleURL == Bundle.main.bundleURL,
           let cached = cachedMainLocalizedBundles[identifier] ?? cachedMainLocalizedBundles[identifier.lowercased()] {
            return cached
        }
        return localizedBundleUncached(for: identifier, bundle: bundle)
    }

    static func defaultLocalizationBundle(bundle: Bundle = .main) -> Bundle {
        if bundle.bundleURL == Bundle.main.bundleURL {
            return cachedMainDefaultLocalizationBundle
        }
        return defaultLocalizationBundleUncached(bundle: bundle)
    }

    private static let cachedMainResourceBundleURLs = resourceBundleURLsUncached(bundle: .main)

    private static let cachedMainLocalizedBundles: [String: Bundle] = {
        var bundles: [String: Bundle] = [:]
        for identifier in commonLanguageIdentifiers {
            if let bundle = localizedBundleUncached(for: identifier, bundle: .main) {
                bundles[identifier] = bundle
                bundles[identifier.lowercased()] = bundle
            }
        }
        return bundles
    }()

    private static let cachedMainDefaultLocalizationBundle = defaultLocalizationBundleUncached(bundle: .main)

    private static func resourceBundleURLsUncached(bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        if let resourceURL = bundle.resourceURL {
            urls.append(resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true))
        }
        urls.append(bundle.bundleURL.deletingLastPathComponent().appendingPathComponent(resourceBundleName, isDirectory: true))
        urls.append(contentsOf: ancestorResourceBundleURLs(from: bundle.bundleURL))
        if let executableDirectory = bundle.executableURL?.deletingLastPathComponent() {
            urls.append(contentsOf: ancestorResourceBundleURLs(from: executableDirectory))
        }
        if bundle.bundleURL != Bundle.main.bundleURL,
           let mainExecutableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(contentsOf: ancestorResourceBundleURLs(from: mainExecutableDirectory))
        }
        for loadedBundle in Bundle.allBundles + Bundle.allFrameworks {
            urls.append(contentsOf: ancestorResourceBundleURLs(from: loadedBundle.bundleURL))
            if let resourceURL = loadedBundle.resourceURL {
                urls.append(resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true))
            }
        }
        if let sourceResourcesURL {
            urls.append(sourceResourcesURL)
        }
        return unique(urls)
    }

    private static func localizedBundleUncached(for identifier: String, bundle: Bundle) -> Bundle? {
        for containerURL in localizationContainerURLs(bundle: bundle) {
            for candidate in [identifier, identifier.lowercased()] {
                let lprojURL = containerURL.appendingPathComponent("\(candidate).lproj", isDirectory: true)
                if FileManager.default.fileExists(atPath: lprojURL.path),
                   let bundle = Bundle(url: lprojURL) {
                    return bundle
                }
            }
        }
        return nil
    }

    private static func defaultLocalizationBundleUncached(bundle: Bundle) -> Bundle {
        if hasLocalizations(in: bundle) {
            return bundle
        }
        for resourceBundleURL in resourceBundleURLs(bundle: bundle) {
            if let resourceBundle = Bundle(url: resourceBundleURL),
               hasLocalizations(in: resourceBundle) {
                return resourceBundle
            }
        }
        return localizedBundle(for: "en", bundle: bundle) ?? bundle
    }

    private static func localizationContainerURLs(bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        if let resourceURL = bundle.resourceURL {
            urls.append(resourceURL)
        }
        urls.append(contentsOf: resourceBundleURLs(bundle: bundle))
        return unique(urls)
    }

    private static func hasLocalizations(in bundle: Bundle) -> Bool {
        bundle.path(forResource: "en", ofType: "lproj") != nil ||
            bundle.path(forResource: "zh-hans", ofType: "lproj") != nil ||
            bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
    }

    private static func ancestorResourceBundleURLs(from url: URL) -> [URL] {
        var urls: [URL] = []
        var current = url
        for _ in 0..<5 {
            urls.append(current.appendingPathComponent(resourceBundleName, isDirectory: true))
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else { break }
            current = parent
        }
        return urls
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    #if DEBUG
    private static var sourceResourcesURL: URL? {
        let candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/shouldrest/Resources", isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
    #else
    private static var sourceResourcesURL: URL? {
        nil
    }
    #endif
}
