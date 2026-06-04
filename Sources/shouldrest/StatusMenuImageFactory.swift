import AppKit

@MainActor
enum StatusMenuImageFactory {
    static func cacheKey(for icon: MenuStatusPresenter.MenuBarIcon) -> String {
        switch icon {
        case .restGate:
            return "restGate:brand"
        case .systemSymbol(let symbolName):
            return "symbol:\(symbolName)"
        }
    }

    static func image(
        for icon: MenuStatusPresenter.MenuBarIcon,
        accessibilityDescription: String?
    ) -> NSImage? {
        switch icon {
        case .restGate:
            return RestGateIcon.menuBarImage(accessibilityDescription: accessibilityDescription)
        case .systemSymbol(let symbolName):
            return systemSymbolImage(symbolName, accessibilityDescription: accessibilityDescription)
        }
    }

    private static func systemSymbolImage(
        _ symbolName: String,
        accessibilityDescription: String?
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        return image
    }
}
