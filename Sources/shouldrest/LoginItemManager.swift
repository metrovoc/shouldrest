import Foundation
import ServiceManagement

enum LoginItemManager {
    enum LoginItemError: LocalizedError {
        case missingBundleIdentifier

        var errorDescription: String? {
            switch self {
            case .missingBundleIdentifier:
                "Open-at-login requires a bundled app with a bundle identifier."
            }
        }
    }

    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func apply(enabled: Bool) throws {
        guard isAvailable else {
            throw LoginItemError.missingBundleIdentifier
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

