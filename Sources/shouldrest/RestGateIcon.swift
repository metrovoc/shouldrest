import AppKit

@MainActor
enum RestGateIcon {
    static func menuBarImage(accessibilityDescription: String?) -> NSImage {
        let image = image(
            size: 18,
            template: true,
            accessibilityDescription: accessibilityDescription
        )
        image.isTemplate = true
        return image
    }

    static func fallbackAppImage(size: CGFloat, accessibilityDescription: String?) -> NSImage {
        image(
            size: size,
            template: false,
            accessibilityDescription: accessibilityDescription
        )
    }

    private static func image(
        size: CGFloat,
        template: Bool,
        accessibilityDescription: String?
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        if template {
            drawTemplateMark(size: size)
        } else {
            drawAppMark(size: size)
        }
        image.unlockFocus()
        image.accessibilityDescription = accessibilityDescription
        image.isTemplate = template
        return image
    }

    private static func drawTemplateMark(size: CGFloat) {
        NSColor.black.setFill()
        NSColor.black.setStroke()

        let ringRect = NSRect(
            x: size * 0.16,
            y: size * 0.16,
            width: size * 0.68,
            height: size * 0.68
        )
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = max(1.45, size * 0.088)
        ring.stroke()

        let barWidth = size * 0.105
        let barHeight = size * 0.38
        let barY = size * 0.32
        let corner = barWidth * 0.48
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.39, y: barY, width: barWidth, height: barHeight),
            xRadius: corner,
            yRadius: corner
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.505, y: barY, width: barWidth, height: barHeight),
            xRadius: corner,
            yRadius: corner
        ).fill()

        NSBezierPath(
            ovalIn: NSRect(
                x: size * 0.66,
                y: size * 0.64,
                width: size * 0.12,
                height: size * 0.12
            )
        ).fill()
    }

    private static func drawAppMark(size: CGFloat) {
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()

        let corner = size * 0.21
        NSColor(red: 0.05, green: 0.09, blue: 0.11, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
            xRadius: corner,
            yRadius: corner
        ).fill()

        let inset = size * 0.12
        NSColor(red: 0.03, green: 0.19, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
            xRadius: corner * 0.72,
            yRadius: corner * 0.72
        ).fill()

        let ringRect = NSRect(x: size * 0.22, y: size * 0.24, width: size * 0.56, height: size * 0.56)
        NSColor(red: 0.70, green: 0.96, blue: 0.92, alpha: 1).setFill()
        NSBezierPath(ovalIn: ringRect).fill()

        NSColor(red: 0.03, green: 0.19, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(ovalIn: ringRect.insetBy(dx: size * 0.075, dy: size * 0.075)).fill()

        let barColor = NSColor(red: 0.70, green: 0.96, blue: 0.92, alpha: 1)
        barColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.405, y: size * 0.37, width: size * 0.07, height: size * 0.28),
            xRadius: size * 0.032,
            yRadius: size * 0.032
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.525, y: size * 0.37, width: size * 0.07, height: size * 0.28),
            xRadius: size * 0.032,
            yRadius: size * 0.032
        ).fill()

        NSColor(red: 0.44, green: 0.88, blue: 0.72, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.65, y: size * 0.64, width: size * 0.12, height: size * 0.12)).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.30, y: size * 0.20, width: size * 0.40, height: size * 0.065),
            xRadius: size * 0.032,
            yRadius: size * 0.032
        ).fill()
    }
}
