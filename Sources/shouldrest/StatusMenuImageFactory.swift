import AppKit

@MainActor
enum StatusMenuImageFactory {
    static func cacheKey(for icon: MenuStatusPresenter.MenuBarIcon) -> String {
        let glyph: String
        switch icon.glyph {
        case .eye:
            glyph = "eye"
        case .bodyBreak:
            glyph = "bodyBreak"
        }
        let badge: String
        switch icon.badge {
        case nil:
            badge = "none"
        case .restDebt:
            badge = "restDebt"
        case .paused:
            badge = "paused"
        }
        return "\(glyph):\(icon.isDimmed ? "dimmed" : "full"):\(badge)"
    }

    static func image(
        for icon: MenuStatusPresenter.MenuBarIcon,
        accessibilityDescription: String?
    ) -> NSImage? {
        switch icon.glyph {
        case .eye:
            return RestGateIcon.menuBarImage(
                accessibilityDescription: accessibilityDescription,
                isDimmed: icon.isDimmed,
                badge: icon.badge
            )
        case .bodyBreak:
            return symbolImage(
                "figure.walk",
                accessibilityDescription: accessibilityDescription,
                isDimmed: icon.isDimmed,
                badge: icon.badge
            )
        }
    }

    private static func symbolImage(
        _ symbolName: String,
        accessibilityDescription: String?,
        isDimmed: Bool,
        badge: MenuBarBadge?
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration) else {
            return nil
        }

        let size = NSSize(width: RestGateIcon.menuBarSize, height: RestGateIcon.menuBarSize)
        let image = NSImage(size: size, flipped: false) { rect in
            let symbolRect = NSRect(
                x: rect.midX - symbol.size.width / 2,
                y: rect.midY - symbol.size.height / 2,
                width: symbol.size.width,
                height: symbol.size.height
            )
            symbol.draw(
                in: symbolRect,
                from: .zero,
                operation: .sourceOver,
                fraction: isDimmed ? RestGateIcon.dimmedAlpha : 1
            )
            if let badge {
                RestGateIcon.drawTemplateBadge(badge, size: rect.width)
            }
            return true
        }
        image.accessibilityDescription = accessibilityDescription
        image.isTemplate = true
        return image
    }
}
