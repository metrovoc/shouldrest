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

        let frameRect = NSRect(
            x: size * 0.18,
            y: size * 0.18,
            width: size * 0.64,
            height: size * 0.64
        )
        let frame = NSBezierPath(
            roundedRect: frameRect,
            xRadius: size * 0.09,
            yRadius: size * 0.09
        )
        frame.lineWidth = max(1.35, size * 0.078)
        frame.stroke()

        let barWidth = size * 0.115
        let barHeight = size * 0.42
        let barY = size * 0.29
        let corner = barWidth * 0.48
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.37, y: barY, width: barWidth, height: barHeight),
            xRadius: corner,
            yRadius: corner
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.515, y: barY, width: barWidth, height: barHeight),
            xRadius: corner,
            yRadius: corner
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

        let markColor = NSColor(red: 0.70, green: 0.96, blue: 0.92, alpha: 1)
        markColor.setStroke()
        let frameRect = NSRect(x: size * 0.23, y: size * 0.24, width: size * 0.54, height: size * 0.54)
        let frame = NSBezierPath(
            roundedRect: frameRect,
            xRadius: size * 0.14,
            yRadius: size * 0.14
        )
        frame.lineWidth = max(2, size * 0.07)
        frame.stroke()

        markColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.38, y: size * 0.36, width: size * 0.095, height: size * 0.32),
            xRadius: size * 0.045,
            yRadius: size * 0.045
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.525, y: size * 0.36, width: size * 0.095, height: size * 0.32),
            xRadius: size * 0.045,
            yRadius: size * 0.045
        ).fill()
    }
}
