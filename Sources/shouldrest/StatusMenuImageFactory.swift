import AppKit

@MainActor
enum StatusMenuImageFactory {
    static func cacheKey(for icon: MenuStatusPresenter.MenuBarIcon) -> String {
        switch icon {
        case .restGate:
            return "restGate:brand"
        case .restGateWithHealthIndicator:
            return "restGate:brand:health"
        case .systemSymbol(let symbolName):
            return "symbol:\(symbolName)"
        case .systemSymbolWithHealthIndicator(let symbolName):
            return "symbol:\(symbolName):health"
        }
    }

    static func image(
        for icon: MenuStatusPresenter.MenuBarIcon,
        accessibilityDescription: String?
    ) -> NSImage? {
        switch icon {
        case .restGate:
            return RestGateIcon.menuBarImage(accessibilityDescription: accessibilityDescription)
        case .restGateWithHealthIndicator:
            return RestGateIcon.menuBarImage(
                accessibilityDescription: accessibilityDescription,
                showsHealthIndicator: true
            )
        case .systemSymbol(let symbolName):
            return systemSymbolImage(
                symbolName,
                accessibilityDescription: accessibilityDescription,
                showsHealthIndicator: false
            )
        case .systemSymbolWithHealthIndicator(let symbolName):
            return systemSymbolImage(
                symbolName,
                accessibilityDescription: accessibilityDescription,
                showsHealthIndicator: true
            )
        }
    }

    private static func systemSymbolImage(
        _ symbolName: String,
        accessibilityDescription: String?,
        showsHealthIndicator: Bool
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: accessibilityDescription)
        guard showsHealthIndicator, let image else {
            image?.isTemplate = true
            return image
        }

        let badgedImage = NSImage(size: NSSize(width: 18, height: 18))
        badgedImage.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: 18, height: 18),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        RestGateIcon.drawTemplateHealthIndicator(size: 18)
        badgedImage.unlockFocus()
        badgedImage.accessibilityDescription = accessibilityDescription
        badgedImage.isTemplate = true
        return badgedImage
    }
}
