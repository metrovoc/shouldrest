import AppKit

/// The closed-eye brand mark. The geometry mirrors packaging/AppIcon.icon, which
/// scripts/generate_app_icon.swift writes from the same points.
@MainActor
enum RestGateIcon {
    static let menuBarSize: CGFloat = 18
    static let dimmedAlpha: CGFloat = 0.42

    static func menuBarImage(
        accessibilityDescription: String?,
        isDimmed: Bool = false,
        badge: MenuBarBadge? = nil
    ) -> NSImage {
        let size = NSSize(width: menuBarSize, height: menuBarSize)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.withAlphaComponent(isDimmed ? dimmedAlpha : 1).setStroke()
            strokeEye(in: rect, glyphWidth: 15.4, weight: 1.06)
            if let badge {
                drawTemplateBadge(badge, size: rect.width)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    /// Glyph-only artwork for in-window use, tinted like an SF Symbol.
    static func glyphImage(pointSize: CGFloat, accessibilityDescription: String?) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            strokeEye(in: rect, glyphWidth: rect.width * 0.86, weight: 1.12)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    /// Stand-in for the compiled app icon when no bundle icon is available.
    static func fallbackAppImage(size: CGFloat, accessibilityDescription: String?) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawAppMark(in: rect)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    /// The app icon as the system renders it, or the drawn mark outside an app bundle.
    static func appIcon(size: CGFloat, accessibilityDescription: String?) -> NSImage {
        guard bundleProvidesAppIcon,
              let icon = NSApp?.applicationIconImage?.copy() as? NSImage else {
            return fallbackAppImage(size: size, accessibilityDescription: accessibilityDescription)
        }
        icon.size = NSSize(width: size, height: size)
        icon.accessibilityDescription = accessibilityDescription
        return icon
    }

    private static var bundleProvidesAppIcon: Bool {
        Bundle.main.bundleURL.pathExtension == "app" &&
            Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") != nil
    }

    // MARK: - Drawing

    private static let lidStart = CGPoint(x: 236, y: 408)
    private static let lidControl1 = CGPoint(x: 340, y: 582)
    private static let lidControl2 = CGPoint(x: 684, y: 582)
    private static let lidEnd = CGPoint(x: 788, y: 408)
    private static let lashes: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 512, y: 546), CGPoint(x: 512, y: 644)),
        (CGPoint(x: 386, y: 523), CGPoint(x: 343, y: 611)),
        (CGPoint(x: 638, y: 523), CGPoint(x: 681, y: 611)),
        (CGPoint(x: 291, y: 470), CGPoint(x: 224, y: 535)),
        (CGPoint(x: 733, y: 470), CGPoint(x: 800, y: 535))
    ]
    private static let lidWidth: CGFloat = 78
    private static let lashWidth: CGFloat = 54
    /// Horizontal extent of the glyph in icon units, lash caps excluded.
    private static let glyphSpan: CGFloat = 576
    /// Vertical center of the glyph in icon units.
    private static let glyphCenterY: CGFloat = 520

    private static func strokeEye(in rect: NSRect, glyphWidth: CGFloat, weight: CGFloat) {
        let scale = glyphWidth / glyphSpan
        func point(_ iconPoint: CGPoint) -> NSPoint {
            NSPoint(
                x: rect.midX + (iconPoint.x - 512) * scale,
                y: rect.midY - (iconPoint.y - glyphCenterY) * scale
            )
        }

        let lid = NSBezierPath()
        lid.move(to: point(lidStart))
        lid.curve(to: point(lidEnd), controlPoint1: point(lidControl1), controlPoint2: point(lidControl2))
        lid.lineWidth = lidWidth * scale * weight
        lid.lineCapStyle = .round
        lid.stroke()

        let lashPath = NSBezierPath()
        for (start, end) in lashes {
            lashPath.move(to: point(start))
            lashPath.line(to: point(end))
        }
        lashPath.lineWidth = lashWidth * scale * weight
        lashPath.lineCapStyle = .round
        lashPath.stroke()
    }

    static func drawTemplateBadge(_ badge: MenuBarBadge, size: CGFloat) {
        let unit = size / menuBarSize
        let context = NSGraphicsContext.current
        switch badge {
        case .restDebt:
            let dot = NSRect(x: 13.3 * unit, y: 13.3 * unit, width: 4.3 * unit, height: 4.3 * unit)
            context?.compositingOperation = .clear
            NSBezierPath(ovalIn: dot.insetBy(dx: -1.1 * unit, dy: -1.1 * unit)).fill()
            context?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
        case .paused:
            let bars = [
                NSRect(x: 13.0 * unit, y: 12.6 * unit, width: 1.8 * unit, height: 5.0 * unit),
                NSRect(x: 15.8 * unit, y: 12.6 * unit, width: 1.8 * unit, height: 5.0 * unit)
            ]
            context?.compositingOperation = .clear
            NSBezierPath(
                roundedRect: NSRect(x: 11.9 * unit, y: 11.5 * unit, width: 6.8 * unit, height: 7.2 * unit),
                xRadius: 1.6 * unit,
                yRadius: 1.6 * unit
            ).fill()
            context?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            for bar in bars {
                NSBezierPath(roundedRect: bar, xRadius: 0.9 * unit, yRadius: 0.9 * unit).fill()
            }
        }
    }

    private static func drawAppMark(in rect: NSRect) {
        // Matches the macOS icon grid: an 824/1024 rounded square with a soft drop shadow.
        let side = rect.width * 824 / 1024
        let body = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2 + rect.height * 0.008, width: side, height: side)
        let radius = side * 0.225
        let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = rect.height * 0.02
        shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.01)
        shadow.set()
        BrandPalette.iconBottom.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(starting: BrandPalette.iconTop, ending: BrandPalette.iconBottom)?.draw(in: shape, angle: -90)

        NSColor.white.setStroke()
        strokeEye(in: body, glyphWidth: side * 0.62, weight: 1)
    }
}

/// Colors of the drawn brand mark; in-window accents use the app accent color.
enum BrandPalette {
    static let iconTop = NSColor(displayP3Red: 0.29, green: 0.80, blue: 0.72, alpha: 1)
    static let iconBottom = NSColor(displayP3Red: 0.055, green: 0.42, blue: 0.47, alpha: 1)
}
